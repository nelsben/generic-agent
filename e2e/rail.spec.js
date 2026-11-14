// @ts-check
/**
 * The right rail (FE-15, FR2) in a real org: a full-height side panel on the right of the record page of
 * Edge Communications, opened by Cmd/Ctrl-Shift-K, by the compact window's Expand and by the launcher's
 * expand button. One conversation moves between the window and the rail, so the thread is the same.
 *
 * Model calls per full run: (3) 1, every other spec 0. Spec 2 sends '/brief' of a name that does not
 * exist: the resolver answers NOT_FOUND from SOQL alone.
 *
 * The context column shows what the org holds for the account: no spec inserts or changes a record,
 * so a section with nothing in it shows its empty line and passes.
 */
const { test, expect, ANSWER_TIMEOUT } = require('./support/panel');

const NO_SUCH_ACCOUNT = '/brief Qzxv Nonexistent E2E';
const RAIL_QUESTION = 'How many open opportunities does this account have?';
const VIEWPORT = { width: 1440, height: 900 };
// fr2-design.md and the card: 480 to 640 px; clamp(480px, 46vw, 640px) is 640 at 1440.
const RAIL_WIDTH = { min: 480, max: 640, at1440: 640 };
const FIRST_PAINT_BUDGET_MS = 300;
const CONTEXT_BUDGET_MS = 1_500;
const SECTIONS = ['deals', 'activity', 'cases', 'summary'];
const EMPTY = {
    deals: 'No open deals.',
    activity: 'No recent activity.',
    cases: 'No open cases.',
    summary: 'No summary of this account yet. Ask for one.'
};
const KINDS = ['Call', 'Email', 'Task', 'Event', 'Case comment'];

/** A focusable element on the page outside the panel: the global header's Search button. */
function pageAnchor(page) {
    return page.getByRole('button', { name: 'Search', exact: true }).first();
}

/** The rail, once its slide (280 ms) is over. */
async function railBox(panel) {
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const box = await panel.rail.boundingBox();
    expect(box, 'the rail is rendered').not.toBeNull();
    return /** @type {{x: number, y: number, width: number, height: number}} */ (box);
}

/** Every context section has left its skeleton rows (aria-busy false). */
async function expectContextFilled(panel) {
    for (const name of SECTIONS) {
        await expect(panel.railSection(name)).toHaveAttribute('aria-busy', 'false', { timeout: 20_000 });
    }
}

test.describe('right rail', () => {
    test('1. @smoke @hotkey Cmd/Ctrl-Shift-K opens the rail over the right of the page, full height, with the composer focused; Esc returns focus', async ({
        page,
        panel
    }) => {
        const anchor = pageAnchor(page);
        await anchor.focus();
        await panel.expectFocused(anchor, 'the key is pressed on the page');
        const before = await anchor.boundingBox();

        await panel.openRail();
        await expect(panel.dialog).toBeHidden();
        const box = await railBox(panel);
        expect(Math.round(box.width)).toBe(RAIL_WIDTH.at1440);
        expect(box.width).toBeGreaterThanOrEqual(RAIL_WIDTH.min);
        expect(box.width).toBeLessThanOrEqual(RAIL_WIDTH.max);
        expect(Math.round(box.x + box.width), 'flush with the right edge').toBe(VIEWPORT.width);
        expect(Math.round(box.y)).toBe(0);
        expect(Math.round(box.height), 'full height').toBe(VIEWPORT.height);
        // Overlay: the page underneath keeps its layout (nothing is pushed left).
        expect(await anchor.boundingBox(), 'the page did not move').toEqual(before);
        await expect(panel.rail).toHaveClass(/cs-rail_overlay/);

        // The header: the agent name and the rail's key hint.
        await expect(panel.rail.locator('h2.cs-rail-name')).not.toHaveText('');
        await expect(panel.rail.locator('kbd.cs-rail-key')).toHaveText(/^(⌘⇧K|Ctrl Shift K)$/);

        await page.keyboard.press('Escape');
        await expect(panel.rail).toBeHidden();
        await panel.expectFocused(anchor, 'focus went back to where the key was pressed');
    });

    test('2. Expand from the compact window opens the rail on the same session with the thread intact', async ({ panel }) => {
        await panel.open();
        await panel.ask(NO_SUCH_ACCOUNT);
        await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
        await expect(panel.spinner).toBeHidden();
        const answer = (await panel.turns.first().innerText()).trim();

        await panel.expandButton.click();
        await expect(panel.rail).toBeVisible();
        await expect(panel.dialog).toBeHidden();
        await expect(panel.turns).toHaveCount(1);
        await expect(panel.turns.first()).toContainText(NO_SUCH_ACCOUNT);
        expect((await panel.turns.first().innerText()).trim(), 'the same turn, word for word').toBe(answer);
        await panel.expectFocused(panel.composer, 'the composer has focus in the rail');
        // The sessions list (FE-22's control) is shown open in the rail.
        await expect(panel.host.getByRole('button', { name: 'History', exact: true })).toHaveAttribute('aria-expanded', 'true');

        // Back to the window with the rail's close: the thread comes home too.
        await panel.railClose.click();
        await expect(panel.rail).toBeHidden();
        await panel.launcher.click();
        await expect(panel.dialog).toBeVisible();
        await expect(panel.turns).toHaveCount(1);
    });

    test('3. one question asked in the rail is answered in the rail', async ({ panel }) => {
        await panel.openRail();
        const before = await panel.turns.count();
        await panel.ask(RAIL_QUESTION);
        await expect(panel.turns).toHaveCount(before + 1, { timeout: ANSWER_TIMEOUT });
        await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
        const turn = panel.turns.last();
        await expect(turn).toContainText(RAIL_QUESTION);
        await expect(turn).not.toContainText("I couldn't finish that right now");
        await expect(panel.rail).toBeVisible();
        await expect(panel.dialog).toBeHidden();
    });

    test('4. each context section renders its rows or its empty line, and a row opens its record', async ({ page, panel }) => {
        await panel.openRail();
        await expect(panel.railContext).toBeVisible();
        await expectContextFilled(panel);
        await expect(panel.rail.locator('.cs-ctx-error')).toHaveCount(0);
        for (const name of SECTIONS) {
            const body = panel.railSection(name);
            const rows = body.locator('.cs-ctx-item, .cs-ctx-summary-line');
            const empty = body.getByText(EMPTY[name], { exact: true });
            await expect(rows.first().or(empty), name + ' shows rows or its empty line').toBeVisible();
        }
        // Each activity row names its kind.
        const kinds = panel.railSection('activity').locator('.cs-ctx-kind');
        for (const kind of await kinds.allInnerTexts()) {
            expect(KINDS.map((k) => k.toUpperCase())).toContain(kind.trim().toUpperCase());
        }

        // A deal, else a case, else an activity, opens its record page; the rail stays on the account.
        const row = panel
            .railSection('deals')
            .locator('button.cs-ctx-item')
            .or(panel.railSection('cases').locator('button.cs-ctx-item'))
            .or(panel.railSection('activity').locator('button.cs-ctx-item'))
            .first();
        if ((await row.count()) === 0) {
            test.info().annotations.push({ type: 'note', description: 'no deal, case or activity rows for this account' });
            return;
        }
        const recordUrl = panel.recordUrl;
        await row.click();
        await expect.poll(() => page.url() !== recordUrl && /\/lightning\/r\//.test(page.url()), { timeout: 30_000 }).toBe(true);
        await expect(panel.rail).toBeVisible();
        await expect(panel.rail.locator('.cs-ctx-heading')).toContainText('Edge Communications');
    });

    test('5. Minimize leaves a slim edge tab; resting the pointer on it opens the rail as a peek; the launcher expand opens it too', async ({ page, panel }) => {
        await panel.launcherExpand.click();
        await expect(panel.rail).toBeVisible();
        await panel.railMinimize.click();
        await expect(panel.rail).toBeHidden();
        await expect(panel.railTab).toBeVisible();
        const tab = await panel.railTab.boundingBox();
        expect(tab && Math.round(tab.width), 'a slim tab').toBeLessThanOrEqual(32);
        expect(tab && Math.round(tab.x + tab.width), 'on the right edge').toBe(VIEWPORT.width);
        await expect(panel.launcher).toBeVisible();

        // A short pass over the tab does nothing; resting on it opens the rail.
        await panel.railTab.hover();
        await expect(panel.rail).toBeVisible({ timeout: 2_000 });
        // A peek: moving the pointer away slides it back to the tab.
        await page.mouse.move(200, 450);
        await expect(panel.rail).toBeHidden({ timeout: 3_000 });
        await expect(panel.railTab).toBeVisible();

        await panel.railTab.click();
        await expect(panel.rail).toBeVisible();
        await panel.expectFocused(panel.composer, 'a click on the tab moves focus in');
    });

    test('6. @hotkey first paint under 300 ms after Cmd/Ctrl-Shift-K, and the context filled within 1.5 s (warm cache)', async ({ page, panel }, testInfo) => {
        const key = await panel.railHotkey();
        const anchor = pageAnchor(page);

        // Warm: one open and close, so the code and the account's context are cached.
        await anchor.focus();
        await panel.openRail();
        await expectContextFilled(panel);
        await page.keyboard.press('Escape');
        await expect(panel.rail).toBeHidden();

        /** Times one key press on a freshly loaded page: first paint, and the context filled. */
        const measureOnce = async () => {
            await anchor.focus();
            await panel.expectFocused(anchor, 'the key is pressed on the page');
            // From the keydown of K: to the frame painted with the rail marked open (data-open, then one
            // animation frame and one task, as spec 10 of panel.spec.js), and to every context section
            // having left its skeleton rows (aria-busy false), polled every 10 ms.
            const measured = panel.rail.evaluate(
                (rail) =>
                    new Promise((resolve) => {
                        let start = 0;
                        let paint = -1;
                        const onKey = (e) => {
                            if (!start && (e.key === 'k' || e.key === 'K')) start = performance.now();
                        };
                        window.addEventListener('keydown', onKey, true);
                        const observer = new MutationObserver(() => {
                            if (rail.getAttribute('data-open') !== 'true') return;
                            observer.disconnect();
                            requestAnimationFrame(() => setTimeout(() => (paint = start ? performance.now() - start : -1), 0));
                        });
                        observer.observe(rail, { attributes: true, attributeFilter: ['data-open'] });
                        const filled = () => {
                            const bodies = Array.from(rail.querySelectorAll('[data-section-body]'));
                            return bodies.length === 4 && bodies.every((b) => b.getAttribute('aria-busy') === 'false');
                        };
                        const began = performance.now();
                        const poll = setInterval(() => {
                            const ready = paint >= 0 && filled();
                            if (ready || performance.now() - began > 15_000) {
                                clearInterval(poll);
                                window.removeEventListener('keydown', onKey, true);
                                resolve({ paint, context: ready && start ? performance.now() - start : -1 });
                            }
                        }, 10);
                    })
            );
            await page.waitForTimeout(100);
            await page.keyboard.press(key);
            const result = /** @type {{paint: number, context: number}} */ (await measured);
            await expect(panel.rail).toBeVisible();
            await page.keyboard.press('Escape');
            await expect(panel.rail).toBeHidden();
            return result;
        };

        const paints = [];
        const fills = [];
        for (let i = 0; i < 3; i += 1) {
            // A fresh page each time, so the rail has nothing of its own yet: only the platform's cache is warm.
            await panel.gotoAccount();
            const r = await measureOnce();
            expect(r.paint, 'the keydown was seen before the rail opened').toBeGreaterThan(0);
            paints.push(Math.round(r.paint));
            expect(r.context, 'the context filled').toBeGreaterThan(0);
            fills.push(Math.round(r.context));
        }
        const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];
        const line =
            'rail first paint after Cmd/Ctrl-Shift-K, ms: ' +
            paints.join(', ') +
            ' (median ' +
            median(paints) +
            '); context filled, ms: ' +
            fills.join(', ') +
            ' (median ' +
            median(fills) +
            ')';
        console.log(line);
        testInfo.annotations.push({ type: 'rail-timing', description: line });
        for (const ms of paints) expect(ms, line).toBeLessThan(FIRST_PAINT_BUDGET_MS);
        for (const ms of fills) expect(ms, line).toBeLessThan(CONTEXT_BUDGET_MS);
    });
});
