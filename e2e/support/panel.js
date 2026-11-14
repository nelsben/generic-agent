// @ts-check
/**
 * The Customer Summary panel as a front-end user meets it: the Customer Summary app, the record page of
 * Edge Communications, and the compact window (FE-13): a launcher at the bottom right of the page and
 * a 420x560 window above it, opened by Cmd/Ctrl-K or the launcher. The eager utility bar item
 * "Customer Summary" mounts them on the page body (its stage, data-cs-stage); its own utility panel
 * holds only a note.
 *
 * Locators reach into the components with Playwright's built-in engine: roles, labels, the panel's
 * test hooks (data-testid: abp-live-region, abp-spinner, abp-summary-headline) and the data
 * attributes it renders (data-cs-stage, data-turn, data-id, data-focus). Answer cards (FE-22) are
 * found by their tag, c-customer-summary-card, and the card's own data-type and classes. The few tags the panel
 * offers no hook for are named in e2e/README.md.
 *
 * Focus: Lightning runs the components in synthetic shadow, where document.activeElement reads the
 * page body while focus is inside the stage (a node moved out of its component's tree). So focus is
 * checked with :focus on the element itself (focused, expectFocused), not toBeFocused.
 */
const fs = require('fs');
const { test: base, expect } = require('@playwright/test');
const { ACCOUNT_NAME, APP_PATH, RUN_FILE } = require('./env');

const COMPOSER_LABEL = 'Ask or /brief an account';
// A brief needs a model call (15-30 s); a question runs a short agentic loop. Generous on purpose.
const ANSWER_TIMEOUT = 150_000;

function runInfo() {
    if (!fs.existsSync(RUN_FILE)) {
        throw new Error('e2e/.auth/run.json is missing: run the suite with npm run test:e2e (its global setup signs in).');
    }
    return JSON.parse(fs.readFileSync(RUN_FILE, 'utf8'));
}

class Panel {
    /** @param {import('@playwright/test').Page} page */
    constructor(page) {
        this.page = page;
        this.run = runInfo();
        // The utility bar item itself; the window and the launcher are on its stage.
        this.element = page.locator('c-customer-summary-panel');
        this.utilityButton = page.getByRole('button', { name: 'Customer Summary', exact: true });
        this.host = page.locator('[data-cs-stage]');
        // "Ask <agent name>" and the key hint: ⌘K on a Mac, Ctrl K elsewhere.
        this.launcher = this.host.getByRole('button', { name: /^Ask .+(⌘K|Ctrl K)$/ });
        this.dialog = this.host.getByRole('dialog');
        // The window whether it is shown or not (getByRole leaves hidden elements out).
        this.sheet = this.host.locator('dialog');
        this.minimizeButton = this.host.getByRole('button', { name: 'Minimize', exact: true });
        this.expandButton = this.host.getByRole('button', { name: 'Expand to the side panel', exact: true });
        this.composer = this.host.getByRole('textbox', { name: COMPOSER_LABEL });
        this.send = this.host.getByRole('button', { name: 'Send', exact: true });
        this.briefButton = this.host.getByRole('button', { name: 'Summarize ' + ACCOUNT_NAME, exact: true });
        // The conversation's own live region, by test id: the page has other role=status regions.
        this.liveRegion = this.host.getByTestId('abp-live-region');
        this.spinner = this.host.getByTestId('abp-spinner');
        this.turns = this.host.locator('[data-turn]');
        // The scroll box: the thread and the drill view.
        this.body = this.host.getByRole('region', { name: 'Conversation', exact: true });
        this.breadcrumbs = this.host.locator('lightning-breadcrumbs');
        // The window's controls row (Minimize, and Expand when it is on), above the conversation.
        this.panelHeader = this.host.locator('.cs-sheet-controls');
        // The header of the account's "Earlier summaries" list.
        this.historyHeader = this.host.getByRole('button', { name: /^Earlier summaries/ });
    }

    get recordUrl() {
        return this.run.origin + '/lightning/r/Account/' + this.run.accountId + '/view';
    }

    /**
     * A fresh load of the account's record page inside the Customer Summary app, with the window
     * never opened. The app URL first makes Customer Summary the current app; the record page is a
     * second full load, so the panel is constructed anew and has not been opened.
     */
    async gotoAccount() {
        // A fresh org shows the admin onboarding walkthrough "Meet the new Guidance Center", at load or
        // some seconds later, and it covers the page and takes focus. Dismiss it whenever it appears;
        // when it is not shown the handler never runs and adds no wait.
        const walkthrough = this.page.getByRole('dialog').filter({ hasText: 'Meet the new Guidance Center' });
        await this.page.addLocatorHandler(walkthrough, async (shown) => {
            await shown.getByRole('button', { name: 'Dismiss', exact: true }).click();
        });
        // The same first-run org can dock "Welcome to Data Cloud!" over the bottom right corner, with
        // Minimize, Pop-out and Close buttons, over the utility panel. Close it the same way: the trigger
        // is its title; the Close button is the one in the smallest element that holds both.
        const dataCloud = this.page.getByText('Welcome to Data Cloud!', { exact: false });
        await this.page.addLocatorHandler(dataCloud.first(), async () => {
            const close = this.page.getByRole('button', { name: 'Close', exact: true });
            const popUp = this.page.locator('*').filter({ has: dataCloud.first() }).filter({ has: close }).last();
            await popUp.getByRole('button', { name: 'Close', exact: true }).first().click();
        });
        await this.page.goto(this.run.origin + APP_PATH);
        await expect(this.host).toBeAttached({ timeout: 90_000 });
        await this.page.goto(this.recordUrl);
        await expect(this.utilityButton).toBeVisible({ timeout: 90_000 });
        await expect(this.launcher).toBeVisible({ timeout: 90_000 });
        // Ready: the panel is connected (its key listener is up) and has resolved the page's account.
        await expect(this.host.getByRole('button', { name: 'Summarize ' + ACCOUNT_NAME, exact: true, includeHidden: true })).toBeAttached({
            timeout: 60_000
        });
        await expect(this.composer).toBeHidden();
    }

    /** Cmd-K on a Mac, Ctrl-K elsewhere: what the panel's isMac() will see in this browser. */
    async hotkey() {
        const mac = await this.page.evaluate(() => {
            const nav = /** @type {any} */ (window.navigator);
            const platform = (nav.userAgentData && nav.userAgentData.platform) || nav.platform || '';
            return /mac|iphone|ipad/i.test(platform);
        });
        return mac ? 'Meta+k' : 'Control+k';
    }

    async open() {
        await this.page.keyboard.press(await this.hotkey());
        await expect(this.dialog).toBeVisible();
        await this.expectFocused(this.composer, 'the composer has focus');
    }

    /** True when focus is anywhere inside the window or on the launcher. */
    focusInPanel() {
        return this.host.evaluate((el) => el.matches(':focus-within'));
    }

    /** True when focus is on the element now (see "Focus" above). */
    focused(locator) {
        return locator.evaluate((el) => el.matches(':focus'));
    }

    /** Waits until focus is on the element. */
    async expectFocused(locator, message) {
        await expect.poll(() => this.focused(locator), { message }).toBe(true);
    }

    /** Sends text from the composer with Enter. */
    async ask(text) {
        await this.composer.fill(text);
        await expect(this.send).toBeEnabled();
        await this.composer.press('Enter');
    }

    /** Clicks the Summarize button and waits for "Summary ready: ...". Returns the brief's turn. */
    async briefThisAccount() {
        await this.briefButton.click();
        await expect(this.liveRegion).toHaveText('Loading summary for ' + ACCOUNT_NAME);
        await expect(this.liveRegion).toHaveText(/^Summary ready: /, { timeout: ANSWER_TIMEOUT });
        await expect(this.spinner).toBeHidden();
        return this.turns.last();
    }

    /**
     * The brief's summary headline: one per brief turn, apart from the section headers. With answer
     * cards (FE-22) it is the summary card's title; without them, the panel's own headline.
     */
    headline(turn) {
        return turn.getByTestId('abp-summary-headline').or(turn.locator('c-customer-summary-card article[data-type="summary"] .cs-title-text'));
    }

    /** The answer cards of a turn (c-customer-summary-card, FE-22). */
    cards(turn) {
        return turn.locator('c-customer-summary-card');
    }

    /**
     * Focus is on locator now and still there after any late focus moves of the page (up to about
     * a second after a close) are over.
     */
    async expectFocusStays(locator, message) {
        await this.expectFocused(locator, message);
        await this.page.waitForTimeout(2_500);
        expect(await this.focused(locator), message + ', and stayed there').toBe(true);
    }

    /**
     * The brief's section headers: each section card's fold button (FE-22), or the
     * lightning-accordion-section buttons of a brief drawn without cards.
     */
    sectionHeaders(turn) {
        return turn
            .locator('c-customer-summary-card article[data-type="section"] .cs-toggle')
            .or(turn.locator('lightning-accordion-section').getByRole('button'));
    }

    /**
     * Expands sections one at a time until one shows a drillable line: a record link of a section
     * card (FE-22), or a button with data-id in a brief drawn without cards. Returns that line's
     * button, or null when no section of the brief has one.
     */
    async firstDrillLine(turn) {
        const cards = turn.locator('c-customer-summary-card article[data-type="section"]');
        const c = await cards.count();
        for (let i = 0; i < c; i += 1) {
            const card = cards.nth(i);
            const toggle = card.locator('.cs-toggle');
            if ((await toggle.count()) && (await toggle.getAttribute('aria-expanded')) === 'false') {
                await toggle.click();
                await expect(toggle).toHaveAttribute('aria-expanded', 'true');
            }
            const links = card.locator('button.cs-link[data-ref]');
            if ((await links.count()) > 0) {
                await expect(links.first()).toBeVisible();
                return links.first();
            }
        }
        const sections = turn.locator('lightning-accordion-section');
        const n = await sections.count();
        for (let i = 0; i < n; i += 1) {
            const section = sections.nth(i);
            const lines = section.locator('button[data-id]');
            if ((await lines.count()) === 0) {
                continue;
            }
            await section.getByRole('button').first().click();
            await expect(lines.first()).toBeVisible();
            return lines.first();
        }
        return null;
    }

    /**
     * A promise for the network response of one CustomerSummaryPanelController method. Only the
     * method name is matched; request bodies are never logged.
     */
    apexResponse(method, timeout = ANSWER_TIMEOUT) {
        const needle = '"classname":"CustomerSummaryPanelController","method":"' + method + '"';
        return this.page.waitForResponse(
            (r) => {
                const body = r.request().postData();
                if (!body || !r.url().includes('/aura')) {
                    return false;
                }
                try {
                    return decodeURIComponent(body.replace(/\+/g, ' ')).includes(needle);
                } catch (e) {
                    return false;
                }
            },
            { timeout }
        );
    }

    /** Lets the page run the callbacks of a response that just arrived, and render: two frames. */
    async settle() {
        for (let i = 0; i < 2; i += 1) {
            await this.page.evaluate(() => new Promise((r) => requestAnimationFrame(() => setTimeout(r, 0))));
        }
    }
}

const test = base.extend({
    panel: async ({ page }, use) => {
        const panel = new Panel(page);
        await panel.gotoAccount();
        await use(panel);
    }
});

module.exports = { test, expect, Panel, ANSWER_TIMEOUT, COMPOSER_LABEL };
