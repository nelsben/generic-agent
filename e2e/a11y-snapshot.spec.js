// @ts-check
/**
 * What a screen reader is given by the compact window (FE-16, FR2 row F62): a Playwright accessibility
 * snapshot of the stage (the launcher and the window) closed, open, pending, answered and in error.
 * Each state asserts the window's accessible name, the composer's label, the live region's text and the
 * focus target after Esc. Automated Chromium cannot hear a screen reader: the by-hand VoiceOver
 * script is in docs/research/fr2-panel-proof.md.
 *
 * No model call. The requests are '/brief' of a name that matches no account (the resolver answers
 * from SOQL alone). The pending state holds that one Aura request in the browser for a moment, and the
 * error state fails it in the browser; nothing about the org is changed. Each request that reaches
 * the org writes the product's own session rows, as any use of the panel does.
 *
 * The snapshot is of the stage element (page.locator('[data-cs-stage]'), through the Panel helper), not
 * of the page: the page has many other regions. Each snapshot is attached to the report as text.
 */
// axe-core, a direct devDependency, run on the stage element itself (see spec 8 in panel.spec.js).
const AXE_SOURCE = require('axe-core').source;
const { test, expect } = require('./support/panel');
const { ACCOUNT_NAME } = require('./support/env');

const AGENT_NAME = 'Customer Summary';
const COMPOSER = 'Ask or /brief an account';
const NOT_FOUND_NAME = 'Qzxv Nonexistent E2E';
const NOT_FOUND_ASK = '/brief ' + NOT_FOUND_NAME;
const FAILED_NAME = 'Qzxv Failing E2E';
const FAILED_ASK = '/brief ' + FAILED_NAME;
const FALLBACK_LAUNCHER = 'Ask the assistant';

/** The Aura request of one CustomerSummaryPanelController method (only the method name is read). */
function isApexCall(request, method) {
    const body = request.postData();
    if (!body || !request.url().includes('/aura')) {
        return false;
    }
    try {
        return decodeURIComponent(body.replace(/\+/g, ' ')).includes(
            '"classname":"CustomerSummaryPanelController","method":"' + method + '"'
        );
    } catch (e) {
        return false;
    }
}

/** The stage's accessibility tree as text, attached to the report and returned. */
async function snapshot(panel, testInfo, name) {
    const text = await panel.host.ariaSnapshot();
    await testInfo.attach('aria-' + name + '.txt', { body: text, contentType: 'text/plain' });
    return text;
}

test('11. accessibility snapshot: closed, open, pending, answered and in error', async ({ page, panel }, testInfo) => {
    const anchor = page.getByRole('button', { name: 'Search', exact: true }).first();

    /** Esc from the open window returns focus to where the hotkey was pressed; then reopens it. */
    async function escThenReopen(what) {
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await panel.expectFocusStays(anchor, what + ': after Esc focus is back on the Search button');
        await anchor.focus();
        await panel.open();
    }

    const closed = await test.step('closed', async () => {
        await expect(panel.dialog).toBeHidden();
        const tree = await snapshot(panel, testInfo, '1-closed');
        // The launcher alone: named with the brand's agent name (brand settings have loaded), and the key.
        await expect(panel.launcher).toHaveAccessibleName(new RegExp('^Ask ' + AGENT_NAME + '\\s*(⌘K|Ctrl K)$'));
        expect(tree).toMatch(/button "Ask Customer Summary (⌘K|Ctrl K)"/);
        expect(tree, 'a closed window gives a screen reader no dialog').not.toContain('dialog');
        expect(tree, 'a closed window gives a screen reader no composer').not.toContain(COMPOSER);
        expect(tree).not.toContain(FALLBACK_LAUNCHER);
        return tree;
    });
    expect(closed.length).toBeGreaterThan(0);

    await test.step('open', async () => {
        await anchor.focus();
        await panel.open();
        const tree = await snapshot(panel, testInfo, '2-open');
        await expect(panel.dialog).toHaveAccessibleName(AGENT_NAME);
        expect(tree).toContain('dialog "' + AGENT_NAME + '"');
        await expect(panel.composer).toHaveAccessibleName(COMPOSER);
        expect(tree).toContain('textbox "' + COMPOSER + '"');
        expect(tree).toContain('button "Summarize ' + ACCOUNT_NAME + '"');
        expect(tree).toContain('button "Minimize"');
        expect(tree).toContain('region "Conversation"');
        // Nothing announced yet.
        await expect(panel.liveRegion).toHaveText('');
        await expect(panel.liveRegion).toHaveAttribute('role', 'status');
        await expect(panel.liveRegion).toHaveAttribute('aria-live', 'polite');
        await panel.expectFocused(panel.composer, 'open: focus is in the composer');
        await escThenReopen('open');
    });

    // Pending: the resolver call is held in the browser until released.
    let release = () => {};
    const gate = new Promise((resolve) => {
        release = resolve;
    });
    await page.route('**/aura*', async (route) => {
        if (isApexCall(route.request(), 'resolve')) {
            await gate;
        }
        await route.continue();
    });

    await test.step('pending', async () => {
        await panel.ask(NOT_FOUND_ASK);
        await expect(panel.spinner).toBeVisible();
        await expect(panel.liveRegion).toHaveText('Loading summary for ' + NOT_FOUND_NAME);
        const tree = await snapshot(panel, testInfo, '3-pending');
        await expect(panel.dialog).toHaveAccessibleName(AGENT_NAME);
        await expect(panel.composer).toHaveAccessibleName(COMPOSER);
        expect(tree).toContain('dialog "' + AGENT_NAME + '"');
        expect(tree).toContain('textbox "' + COMPOSER + '"');
        expect(tree, 'the question is in the tree while it waits').toContain(NOT_FOUND_ASK);
        // Esc closes the window while the request runs; the request is not cancelled.
        await escThenReopen('pending');
        await expect(panel.spinner).toBeVisible();
        await expect(panel.liveRegion).toHaveText('Loading summary for ' + NOT_FOUND_NAME);
    });

    await test.step('answered', async () => {
        release();
        await expect(panel.spinner).toBeHidden();
        await expect(panel.turns).toHaveCount(1);
        // The live region says the resolver's own line, which is also the answer on screen.
        const said = ((await panel.liveRegion.textContent()) || '').trim();
        expect(said.length, 'the live region carries the answer').toBeGreaterThan(0);
        expect(said).not.toMatch(/^Loading/);
        await expect(panel.turns.first()).toContainText(said);
        const tree = await snapshot(panel, testInfo, '4-answered');
        await expect(panel.dialog).toHaveAccessibleName(AGENT_NAME);
        await expect(panel.composer).toHaveAccessibleName(COMPOSER);
        expect(tree).toContain('dialog "' + AGENT_NAME + '"');
        expect(tree).toContain(said.split('\n')[0].slice(0, 40));
        await escThenReopen('answered');
        await expect(panel.liveRegion).toHaveText(said);
    });

    await test.step('in error', async () => {
        await page.unroute('**/aura*');
        // The browser fails the next resolver call: the panel shows its error line and says it.
        await page.route('**/aura*', async (route) => {
            if (isApexCall(route.request(), 'resolve')) {
                await route.abort('failed');
                return;
            }
            await route.continue();
        });
        await panel.ask(FAILED_ASK);
        await expect(panel.turns).toHaveCount(2, { timeout: 60_000 });
        await expect(panel.spinner).toBeHidden();
        const errorTurn = panel.host.locator('.abp-reply-error');
        await expect(errorTurn).toHaveCount(1);
        const shown = ((await errorTurn.textContent()) || '').trim();
        expect(shown.length).toBeGreaterThan(0);
        // The error turn is labelled "Error" on screen; the live region says the text after the label.
        const said = ((await panel.liveRegion.textContent()) || '').trim();
        expect(said.length, 'the live region carries the error').toBeGreaterThan(0);
        expect(said).not.toMatch(/^Loading/);
        expect(shown).toContain(said);
        const tree = await snapshot(panel, testInfo, '5-error');
        await expect(panel.dialog).toHaveAccessibleName(AGENT_NAME);
        await expect(panel.composer).toHaveAccessibleName(COMPOSER);
        expect(tree).toContain('dialog "' + AGENT_NAME + '"');
        expect(tree).toContain(said.slice(0, 30));
        await escThenReopen('in error');
        await page.unroute('**/aura*');
    });
});

test('12. @smoke the fallback names ("Assistant", "Ask the assistant") are not in a live region and not heard once brand settings load', async ({ page }) => {
    // Watch the launcher's text from the first document on, in every frame: the page itself loads before
    // the panel does, so the observer starts at document start and records each text the launcher shows.
    await page.addInitScript(() => {
        const seen = [];
        /** @type {any} */ (window).__launcherTexts = seen;
        const t0 = performance.now();
        const watch = (stage) => {
            const look = () => {
                const name = stage.querySelector('.cs-launcher-name');
                const value = name ? (name.textContent || '').trim() : '';
                if (value && (!seen.length || seen[seen.length - 1].text !== value)) {
                    seen.push({ text: value, ms: Math.round(performance.now() - t0) });
                }
            };
            look();
            new MutationObserver(look).observe(stage, { childList: true, subtree: true, characterData: true });
        };
        // The stage is moved onto document.body after the panel's first render.
        const find = () => {
            for (const node of Array.from(document.body ? document.body.children : [])) {
                if (node.hasAttribute('data-cs-stage') && !node.__watched) {
                    node.__watched = true;
                    watch(node);
                }
            }
        };
        const start = () => {
            find();
            new MutationObserver(find).observe(document.body, { childList: true });
        };
        if (document.body) {
            start();
        } else {
            document.addEventListener('DOMContentLoaded', start);
        }
    });
    const { Panel } = require('./support/panel');
    const panel = new Panel(page);
    await panel.gotoAccount();
    await expect(panel.launcher).toHaveAccessibleName(new RegExp('^Ask ' + AGENT_NAME));
    const seen = await page.evaluate(() => /** @type {any} */ (window).__launcherTexts);
    console.log('launcher name over time: ' + JSON.stringify(seen));
    expect(seen.length, 'the launcher name was observed').toBeGreaterThan(0);
    // The last name is the branded one; the fallback, if it was ever shown, was never in a live region.
    expect(seen[seen.length - 1].text).toBe('Ask ' + AGENT_NAME);
    // The launcher sits outside the conversation's live region by construction.
    await expect(panel.host.getByTestId('abp-live-region').getByText(FALLBACK_LAUNCHER, { exact: false })).toHaveCount(0);
});

test('13. colour contrast on the light theme: axe color-contrast on the open window with an answer showing finds nothing', async ({ page, panel }) => {
    // agent-probe offers no dark theme (docs/research/fr2-panel-proof.md), so the brand colours are
    // checked on the light theme. An answer from the resolver (no model call) puts text, the error-free
    // reply style, the Summarize button and the composer on screen.
    await panel.open();
    await panel.ask(NOT_FOUND_ASK);
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden();
    await panel.sheet.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    await page.evaluate(AXE_SOURCE);
    const results = await panel.host.evaluate(
        (el) => /** @type {any} */ (window).axe.run(el, { runOnly: { type: 'rule', values: ['color-contrast'] } })
    );
    const found = results.violations.flatMap((v) => v.nodes.map((n) => ({ id: v.id, target: n.target, summary: n.failureSummary })));
    console.log('color-contrast: ' + results.passes.reduce((n, r) => n + r.nodes.length, 0) + ' elements pass, ' + results.incomplete.reduce((n, r) => n + r.nodes.length, 0) + ' incomplete, ' + found.length + ' violations');
    expect(results.passes.reduce((n, r) => n + r.nodes.length, 0), 'axe checked the contrast of elements in the window').toBeGreaterThan(0);
    expect(found).toEqual([]);
});
