// @ts-check
/**
 * The Customer Summary panel in a real org, one journey per test. Each test loads the record page of
 * Edge Communications fresh inside the Customer Summary app (see support/panel.js). The panel is the
 * compact window (FE-13): a launcher at the bottom right and a 420x560 window above it.
 *
 * Model calls per full run (briefs and questions): (3) 1, (4) 2, (5) 1, (6) 0, (7) 1,
 * (8) 1-2, (9) 0, (10) 0, so 6 to 7. Spec 8 asks one question only when no brief section line
 * is drillable; spec 7 fails instead.
 * Spec 5's second request and the sends of specs 6 and 9 are '/brief' of a name that does not
 * exist: the resolver answers NOT_FOUND from SOQL alone, with no model call.
 */
const fs = require('fs');
// axe-core, a direct devDependency (spec 8).
const AXE_SOURCE = require('axe-core').source;
const { test, expect, ANSWER_TIMEOUT } = require('./support/panel');
const { ACCOUNT_NAME } = require('./support/env');

// Matches no Account: the resolver answers NOT_FOUND without a model call.
const NO_SUCH_ACCOUNT = '/brief Qzxv Nonexistent E2E';
// Asked only when no brief section line is drillable; its answer is a table of Contact rows.
const DRILL_QUESTION = 'List the contacts at this account with their titles';
const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];
// The window's corner (fr2-surfaces-spike.md): 16 px from the right edge, 48 px above the bottom.
const VIEWPORT = { width: 1440, height: 900 };
const WINDOW = { width: 420, height: 560, right: 16, bottom: 48 };
// Opening, keydown to the first frame painted with the window open, warm cache (FE-13).
const FIRST_PAINT_BUDGET_MS = 300;

/** A focusable element on the page outside the panel: the global header's Search button. */
function pageAnchor(page) {
    return page.getByRole('button', { name: 'Search', exact: true }).first();
}

/**
 * Something to drill from, after a brief of the account: a section line that carries a record Id
 * (the panel's section drill). Spec 7 requires one. Otherwise, when no section line carries one,
 * a result row of one question is used instead, so the drill view is still reached. That
 * fallback costs one model call.
 */
async function drillOrigin(panel, { briefed = false, requireSectionDrill = true } = {}) {
    const brief = briefed ? panel.turns.last() : await panel.briefThisAccount();
    const line = await panel.firstDrillLine(brief);
    if (requireSectionDrill) {
        expect(line, 'a brief section line is drillable (it needs a record Id in the line)').not.toBeNull();
    }
    if (line) {
        return line;
    }
    await panel.ask(DRILL_QUESTION);
    await expect(panel.turns).toHaveCount(2, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
    // A result row: a record link of an answer card (FE-22), or a button with data-id without cards.
    const last = panel.turns.last();
    const row = last.locator('c-customer-summary-card button.cs-link[data-ref]').or(last.locator('button[data-id]')).first();
    await expect(row, 'the answer has a drillable result row').toBeVisible();
    return row;
}

/** The window sits in the bottom right corner at its size, once its slide (280 ms) is over. */
async function expectInCorner(panel) {
    await panel.sheet.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const box = await panel.dialog.boundingBox();
    expect(box, 'the window is rendered').not.toBeNull();
    if (!box) return null;
    expect(Math.round(box.width)).toBe(WINDOW.width);
    expect(Math.round(box.height)).toBe(WINDOW.height);
    expect(Math.round(VIEWPORT.width - (box.x + box.width)), 'CSS px from the right edge').toBe(WINDOW.right);
    expect(Math.round(VIEWPORT.height - (box.y + box.height)), 'CSS px above the bottom').toBe(WINDOW.bottom);
    return box;
}

// axe is given the stage element itself, not a selector: the page's synthetic shadow DOM hides
// the stage from document.querySelectorAll, which is how axe resolves an include selector
// ("No elements found for include"). AxeBuilder takes selectors only, so the direct
// devDependency axe-core is injected here and run on the element, with the same WCAG tags.
async function axeScan(panel, testInfo, state) {
    await panel.page.evaluate(AXE_SOURCE);
    const results = await panel.host.evaluate(
        (el, tags) => /** @type {any} */ (window).axe.run(el, { runOnly: { type: 'tag', values: tags } }),
        WCAG_TAGS
    );
    const violations = results.violations.map((v) => ({
        id: v.id,
        impact: v.impact,
        help: v.help,
        nodes: v.nodes.map((n) => ({ target: n.target, summary: n.failureSummary }))
    }));
    // Saved under test-results/ and attached to the report. Rule ids, targets and summaries only.
    const file = testInfo.outputPath('axe-' + state + '.json');
    fs.writeFileSync(file, JSON.stringify({ state, passes: results.passes.length, violations }, null, 2));
    await testInfo.attach('axe-' + state + '.json', { path: file, contentType: 'application/json' });
    // Proof the scan reached the panel's shadow tree rather than matching nothing.
    expect(results.passes.length, 'axe evaluated rules inside the panel').toBeGreaterThan(0);
    return violations;
}

test('1. @smoke @hotkey Cmd/Ctrl-K before the window was ever opened opens it in the bottom right corner and focuses the composer', async ({ page, panel }) => {
    await expect(panel.dialog).toBeHidden();
    await test.step('the launcher sits in the corner with the agent name and the key hint', async () => {
        const box = await panel.launcher.boundingBox();
        expect(box).not.toBeNull();
        if (!box) return;
        expect(Math.round(VIEWPORT.width - (box.x + box.width))).toBe(WINDOW.right);
        expect(Math.round(VIEWPORT.height - (box.y + box.height))).toBe(WINDOW.bottom);
        const mac = (await panel.hotkey()) === 'Meta+k';
        await expect(panel.launcher.locator('kbd')).toHaveText(mac ? '⌘K' : 'Ctrl K');
        await expect(panel.launcher).toHaveAttribute('aria-keyshortcuts', mac ? 'Meta+K' : 'Control+K');
    });
    // Pressed once: a retry would hide the defect this test exists to catch.
    await page.keyboard.press(await panel.hotkey());
    await expect(panel.dialog).toBeVisible();
    await panel.expectFocused(panel.composer, 'the composer has focus');
    await expectInCorner(panel);
    // The launcher scales away while the window is open; the utility panel itself stays closed.
    await expect(panel.launcher).toBeHidden();
    await expect(panel.element.getByText('Opens at the bottom right of the page.', { exact: false })).toBeHidden();
});

test('2. Esc closes the window and returns focus where it came from, or to the launcher; Tab can leave', async ({ page, panel }) => {
    const anchor = pageAnchor(page);

    await test.step('from the global Search button: Esc from the composer', async () => {
        await anchor.focus();
        await panel.expectFocused(anchor, 'the Search button has focus');
        await panel.open();
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await panel.expectFocusStays(anchor, 'focus returned to the Search button');
    });

    await test.step('from the global Search button: Esc from a button in the window', async () => {
        await anchor.focus();
        await panel.open();
        await panel.briefButton.focus();
        await panel.expectFocused(panel.briefButton, 'the Summarize button has focus');
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await panel.expectFocusStays(anchor, 'focus returned to the Search button');
    });

    await test.step('from a field inside another component on the record page (inline edit of Phone)', async () => {
        await page.getByRole('tab', { name: 'Details', exact: true }).click();
        await page.getByRole('button', { name: 'Edit Phone', exact: true }).click();
        const field = page.getByRole('textbox', { name: 'Phone', exact: true });
        await expect(field).toBeVisible();
        await field.focus();
        await panel.expectFocused(field, 'the Phone field has focus');
        await panel.open();
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await panel.expectFocusStays(field, 'focus returned to the Phone field');
        // Leave the record as it was: cancel the inline edit, nothing is saved.
        await page.getByRole('button', { name: 'Cancel', exact: true }).click();
        await expect(field).toBeHidden();
    });

    await test.step('from the launcher', async () => {
        await panel.launcher.focus();
        await panel.expectFocused(panel.launcher, 'the launcher has focus');
        await page.keyboard.press('Enter');
        await expect(panel.dialog).toBeVisible();
        await panel.expectFocused(panel.composer, 'the composer has focus');
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await panel.expectFocusStays(panel.launcher, 'focus returned to the launcher');
    });

    await test.step('the element it came from is gone: the launcher, never the page body', async () => {
        // A stand-in field the test adds to the page and removes while the window is open.
        await page.evaluate(() => {
            const input = document.createElement('input');
            input.setAttribute('aria-label', 'Temporary e2e field');
            input.style.cssText = 'position:fixed;top:4px;left:4px';
            document.body.appendChild(input);
        });
        const temporary = page.getByRole('textbox', { name: 'Temporary e2e field', exact: true });
        await temporary.focus();
        await panel.expectFocused(temporary, 'the temporary field has focus');
        await panel.open();
        await temporary.evaluate((el) => el.remove());
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await panel.expectFocusStays(panel.launcher, 'focus fell back to the launcher');
    });

    await test.step('a key right after the fall back ends it: Tab moves on from the launcher', async () => {
        await page.evaluate(() => {
            const input = document.createElement('input');
            input.setAttribute('aria-label', 'Temporary e2e field');
            input.style.cssText = 'position:fixed;top:4px;left:4px';
            document.body.appendChild(input);
        });
        const temporary = page.getByRole('textbox', { name: 'Temporary e2e field', exact: true });
        await temporary.focus();
        await panel.open();
        await temporary.evaluate((el) => el.remove());
        await page.keyboard.press('Escape');
        await panel.expectFocused(panel.launcher, 'focus fell back to the launcher');
        await page.keyboard.press('Tab');
        await page.waitForTimeout(300);
        expect(await panel.focused(panel.launcher), 'the launcher let focus go').toBe(false);
    });

    await test.step('Tab leaves the window (no trap)', async () => {
        await anchor.focus();
        await panel.open();
        let left = false;
        for (let i = 0; i < 30 && !left; i += 1) {
            await page.keyboard.press('Tab');
            left = !(await panel.focusInPanel());
        }
        expect(left, 'focus left the window within 30 Tabs').toBe(true);
    });
});

test('3. a brief renders with its headline and collapsed accordions, announced by the live region; the pinned bar leaves the conversation the room', async ({ panel }) => {
    await panel.open();
    await expect(panel.briefButton).toBeVisible();
    await panel.briefButton.click();
    await expect(panel.liveRegion).toHaveText('Loading summary for ' + ACCOUNT_NAME);
    await expect(panel.liveRegion).toHaveText(/^Summary ready: \S/, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();

    const turn = panel.turns.last();
    // The summary's headline, told apart from the section headers: the summary card's title (FE-22).
    const headline = panel.headline(turn);
    await expect(headline).toHaveCount(1);
    await expect(headline).toBeVisible();
    const headlineText = ((await headline.textContent()) || '').trim();
    expect(headlineText.length).toBeGreaterThan(0);
    await expect(panel.liveRegion).toHaveText('Summary ready: ' + headlineText);

    const headers = panel.sectionHeaders(turn);
    expect(await headers.count()).toBeGreaterThan(0);
    for (const header of await headers.all()) {
        await expect(header).toHaveAttribute('aria-expanded', 'false');
    }

    await test.step('the pinned bar is at most 80 CSS px and the scroll box at least 240 CSS px', async () => {
        // The brief reloads the account's earlier briefs: measure with that list rendered.
        await expect(panel.historyHeader).toBeAttached();
        await panel.settle();
        const box = await panel.dialog.boundingBox();
        const header = await panel.panelHeader.boundingBox();
        const body = await panel.body.boundingBox();
        expect(box && header && body, 'the panel, its header and the scroll box are rendered').toBeTruthy();
        if (!box || !header || !body) return;
        await expectInCorner(panel);
        const bar = body.y - (header.y + header.height);
        expect(Math.round(bar), 'CSS px from the window controls to the top of the scroll box').toBeLessThanOrEqual(80);
        expect(Math.round(body.height), 'the scroll box height in CSS px').toBeGreaterThanOrEqual(240);
        // The bar holds the Summarize button alone: "Ask the agent" is gone (FR2).
        await expect(panel.briefButton).toBeVisible();
        await expect(panel.host.getByRole('button', { name: 'Ask the agent', exact: true })).toHaveCount(0);
    });
});

test('4. after two answers the composer stays pinned in the 420x560 window and the newest answer is in view', async ({ panel }) => {
    await panel.open();
    await panel.briefThisAccount();
    await panel.ask('How many contacts does this account have?');
    await expect(panel.turns).toHaveCount(2, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });

    const box = await expectInCorner(panel);
    if (!box) return;

    for (const control of [panel.composer, panel.send]) {
        await expect(control).toBeVisible();
        const c = await control.boundingBox();
        expect(c).not.toBeNull();
        if (!c) return;
        expect(c.y).toBeGreaterThanOrEqual(box.y);
        expect(c.y + c.height).toBeLessThanOrEqual(box.y + box.height + 1);
    }

    const scroll = await panel.body.evaluate((el) => ({ sh: el.scrollHeight, ch: el.clientHeight, top: el.scrollTop }));
    expect(scroll.sh, 'the body overflows, so it is the scroll box').toBeGreaterThan(scroll.ch);
    expect(scroll.top, 'the body scrolled to the newest answer').toBeGreaterThan(0);
    await expect(panel.turns.last()).toBeInViewport();
});

test('5. a second request sent before the first answers: only the second answer renders', async ({ panel }) => {
    const first = 'Which open opportunities does this account have?';
    await panel.open();

    let firstLanded = false;
    const firstReply = panel.apexResponse('explore').then((r) => {
        firstLanded = true;
        return r;
    });
    await panel.ask(first);
    await expect(panel.spinner).toBeVisible();
    await expect(panel.liveRegion).toHaveText('Loading answer');

    const secondReply = panel.apexResponse('resolve');
    await panel.ask(NO_SUCH_ACCOUNT);
    await secondReply;
    // Otherwise this run did not exercise a late reply (a test problem, not a panel defect).
    expect(firstLanded, 'the first reply was still in flight when the second landed').toBe(false);
    await expect(panel.turns).toHaveCount(1);
    await expect(panel.turns.first()).toContainText(NO_SUCH_ACCOUNT);
    await expect(panel.spinner).toBeHidden();

    // The first reply lands later and must be dropped: never rendered, spinner stays off.
    // The response's body must reach the page before the page can process (and drop) it.
    await (await firstReply).finished();
    await panel.settle();
    await expect(panel.turns).toHaveCount(1);
    await expect(panel.host).not.toContainText(first);
    await expect(panel.spinner).toBeHidden();
    await expect(panel.liveRegion).not.toHaveText('Answer ready');
});

test('6. @smoke typing enables Send without blur, and Enter sends', async ({ page, panel }) => {
    await panel.open();
    await expect(panel.send).toBeDisabled();
    await page.keyboard.type(NO_SUCH_ACCOUNT);
    await panel.expectFocused(panel.composer, 'the composer kept focus');
    await expect(panel.send).toBeEnabled();

    await page.keyboard.press('Enter');
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.turns.first()).toContainText(NO_SUCH_ACCOUNT);
    await expect(panel.composer).toHaveValue('');
    await expect(panel.spinner).toBeHidden();
});

test('7. a drill opens the record view and a breadcrumb returns without navigating to #', async ({ page, panel }) => {
    await panel.open();
    const origin = await drillOrigin(panel);

    const urlBefore = page.url();
    const navigations = [];
    page.on('framenavigated', (f) => {
        if (f === page.mainFrame()) navigations.push(f.url());
    });

    await origin.click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    const heading = panel.host.locator('article').getByRole('heading', { level: 2 });
    await expect(heading).toBeVisible();
    await expect(heading).not.toHaveText('');
    await panel.expectFocused(heading, 'the record heading has focus');
    await expect(panel.host.getByRole('button', { name: 'View record' })).toBeVisible();
    await expect(origin).toBeHidden();

    await panel.breadcrumbs.getByRole('link', { name: 'Conversation', exact: true }).click();
    await expect(panel.breadcrumbs).toBeHidden();
    await expect(origin).toBeVisible();
    await panel.expectFocused(origin, 'focus is back on the line drilled from');
    expect(page.url()).toBe(urlBefore);
    expect(navigations.filter((u) => u.endsWith('#'))).toEqual([]);
});

test('8. axe finds no WCAG A/AA violations in the open panel: brief state and drill state', async ({ panel }, testInfo) => {
    await panel.open();
    await panel.briefThisAccount();
    const briefViolations = await axeScan(panel, testInfo, 'brief');

    // Spec 7 owns the section-drill check; here any drill reaches the state to scan.
    const origin = await drillOrigin(panel, { briefed: true, requireSectionDrill: false });
    await origin.click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    const drillViolations = await axeScan(panel, testInfo, 'drill');

    expect.soft(briefViolations, 'axe violations in the brief state').toEqual([]);
    expect.soft(drillViolations, 'axe violations in the drill state').toEqual([]);
});

test('9. Minimize collapses to the launcher and keeps the conversation; Expand is off by default', async ({ page, panel }) => {
    const anchor = pageAnchor(page);
    await anchor.focus();
    await panel.open();
    await expect(panel.expandButton).toHaveCount(0);
    await panel.ask(NO_SUCH_ACCOUNT);
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden();

    await panel.minimizeButton.click();
    await expect(panel.dialog).toBeHidden();
    await expect(panel.launcher).toBeVisible();
    await panel.expectFocused(anchor, 'focus returned to where the hotkey was pressed');

    await panel.launcher.click();
    await expect(panel.dialog).toBeVisible();
    await expect(panel.turns).toHaveCount(1);
    await expect(panel.turns.first()).toContainText(NO_SUCH_ACCOUNT);
});

test('10. @hotkey opening takes under 300 ms from the key to the first frame painted with the window open (warm cache)', async ({ page, panel }, testInfo) => {
    const key = await panel.hotkey();
    const anchor = pageAnchor(page);
    // Warm: one open and close first, so the code and the conversation are loaded. From the Search
    // button, so focus goes back there and each key below is pressed on the page.
    await anchor.focus();
    await panel.open();
    await page.keyboard.press('Escape');
    await expect(panel.dialog).toBeHidden();

    const samples = [];
    for (let i = 0; i < 5; i += 1) {
        await anchor.focus();
        await panel.expectFocused(anchor, 'the key is pressed on the page');
        // From the keydown of K to the end of the first animation frame after the window
        // is marked open (data-open), and one task after it: the frame that paints the opened window.
        const measured = panel.sheet.evaluate(
            (sheet) =>
                new Promise((resolve) => {
                    let start = 0;
                    const onKey = (e) => {
                        if (!start && (e.key === 'k' || e.key === 'K')) start = performance.now();
                    };
                    window.addEventListener('keydown', onKey, true);
                    const observer = new MutationObserver(() => {
                        if (sheet.getAttribute('data-open') !== 'true') return;
                        observer.disconnect();
                        requestAnimationFrame(() => {
                            setTimeout(() => {
                                window.removeEventListener('keydown', onKey, true);
                                resolve(start ? performance.now() - start : -1);
                            }, 0);
                        });
                    });
                    observer.observe(sheet, { attributes: true, attributeFilter: ['data-open'] });
                })
        );
        // Let the listener and the observer be in place before the key.
        await page.waitForTimeout(100);
        await page.keyboard.press(key);
        const ms = await measured;
        expect(ms, 'the keydown was seen before the window opened').toBeGreaterThan(0);
        samples.push(Math.round(ms));
        await expect(panel.dialog).toBeVisible();
        await page.keyboard.press('Escape');
        await expect(panel.dialog).toBeHidden();
        await page.waitForTimeout(400);
    }
    const sorted = [...samples].sort((x, y) => x - y);
    const median = sorted[Math.floor(sorted.length / 2)];
    const line = 'first paint after Cmd/Ctrl-K, ms: ' + samples.join(', ') + ' (median ' + median + ', max ' + sorted[sorted.length - 1] + ')';
    console.log(line);
    testInfo.annotations.push({ type: 'first-paint', description: line });
    for (const ms of samples) {
        expect(ms, line).toBeLessThan(FIRST_PAINT_BUDGET_MS);
    }
});
