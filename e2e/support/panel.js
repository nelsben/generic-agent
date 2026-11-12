// @ts-check
/**
 * The Account Brief panel as a front-end user meets it: the Account Brief app, the record page of
 * Edge Communications, the utility bar item "Account Brief" (340x480, eager).
 *
 * Locators pierce the panel's native shadow DOM with Playwright's built-in engine: roles, labels,
 * the panel's test hooks (data-testid: abp-live-region, abp-spinner, abp-summary-headline) and the
 * data attributes it renders (data-turn, data-id, data-focus). The few tags the panel offers no
 * hook for are named in e2e/README.md.
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
        this.host = page.locator('c-account-brief-panel');
        this.utilityButton = page.getByRole('button', { name: 'Account Brief', exact: true });
        this.dialog = page.getByRole('dialog').filter({ has: this.host });
        this.composer = this.host.getByRole('textbox', { name: COMPOSER_LABEL });
        this.send = this.host.getByRole('button', { name: 'Send', exact: true });
        this.briefButton = this.host.getByRole('button', { name: 'Brief ' + ACCOUNT_NAME, exact: true });
        this.agentButton = this.host.getByRole('button', { name: 'Ask the agent', exact: true });
        // The panel's own live region; lightning-textarea renders a second, empty role=status.
        this.liveRegion = this.host.getByTestId('abp-live-region');
        this.spinner = this.host.getByTestId('abp-spinner');
        this.turns = this.host.locator('[data-turn]');
        // The scroll box: the conversation and the drill view.
        this.body = this.host.getByRole('region', { name: 'Conversation', exact: true });
        this.breadcrumbs = this.host.locator('lightning-breadcrumbs');
        // The utility panel's own header (title, Minimize, Pop-out), above the panel component.
        this.panelHeader = this.dialog.locator('.slds-utility-panel__header').first();
        // The header of the account's "Earlier briefs" list.
        this.historyHeader = this.host.getByRole('button', { name: /^Earlier briefs/ });
    }

    get recordUrl() {
        return this.run.origin + '/lightning/r/Account/' + this.run.accountId + '/view';
    }

    /**
     * A fresh load of the account's record page inside the Account Brief app, with the utility
     * never opened. The app URL first makes Account Brief the current app; the record page is a
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
        await this.page.goto(this.run.origin + APP_PATH);
        await expect(this.host).toBeAttached({ timeout: 90_000 });
        await this.page.goto(this.recordUrl);
        await expect(this.utilityButton).toBeVisible({ timeout: 90_000 });
        await expect(this.host).toBeAttached();
        // Ready: the panel is connected (its key listener is up) and has resolved the page's account.
        await expect(this.host.getByRole('button', { name: 'Brief ' + ACCOUNT_NAME, exact: true, includeHidden: true })).toBeAttached({
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
        await expect(this.composer).toBeFocused();
    }

    /** True when focus is anywhere inside the panel's shadow tree. */
    focusInPanel() {
        return this.host.evaluate((el) => el.matches(':focus-within'));
    }

    /** Sends text from the composer with Enter. */
    async ask(text) {
        await this.composer.fill(text);
        await expect(this.send).toBeEnabled();
        await this.composer.press('Enter');
    }

    /** Clicks the brief button and waits for "Brief ready: ...". Returns the brief's turn. */
    async briefThisAccount() {
        await this.briefButton.click();
        await expect(this.liveRegion).toHaveText('Loading brief for ' + ACCOUNT_NAME);
        await expect(this.liveRegion).toHaveText(/^Brief ready: /, { timeout: ANSWER_TIMEOUT });
        await expect(this.spinner).toBeHidden();
        return this.turns.last();
    }

    /** The brief's summary headline: one per brief turn, apart from the section headers. */
    headline(turn) {
        return turn.getByTestId('abp-summary-headline');
    }

    /**
     * Focus is on locator now and still there after the platform's late focus moves (up to about a
     * second after a minimize) are over.
     */
    async expectFocusStays(locator, message) {
        await expect(locator, message).toBeFocused();
        await this.page.waitForTimeout(2_500);
        await expect(locator, message + ', and stayed there').toBeFocused();
    }

    /** The brief's section headers (lightning-accordion-section buttons). */
    sectionHeaders(turn) {
        return turn.locator('lightning-accordion-section').getByRole('button');
    }

    /**
     * Expands sections one at a time until one shows a drillable line (a button with data-id).
     * Returns that line's button, or null when no section of the brief has one.
     */
    async firstDrillLine(turn) {
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
     * A promise for the network response of one AccountBriefPanelController method. Only the
     * method name is matched; request bodies are never logged.
     */
    apexResponse(method, timeout = ANSWER_TIMEOUT) {
        const needle = '"classname":"AccountBriefPanelController","method":"' + method + '"';
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
