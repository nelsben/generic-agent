// @ts-check
/**
 * FR2 build review (OPS-35): the front-end checks of every surface, on the Edge Communications record page, at
 * 1440x900 and 1280x720. Run: npx playwright test -c e2e/review/playwright.review.config.js
 *
 * What it checks, and what it records (one JSON line per measure, to REVIEW_OUT or test-results/review/):
 *   - the compact window opens by the hotkey and by a click on the launcher; Esc closes it
 *   - the quick actions (names, and whether the row scrolls sideways), the voice button and its label
 *   - a draft card from "Create a follow-up", stopped at Cancel; no commitAction request is ever sent
 *   - Expand keeps the thread: the same turns in the rail
 *   - the rail's four context sections, the outcomes timeline and the sentiment chart (entries and points)
 *   - history reopen (the History list, then the newest conversation)
 *   - a --cs-* variable overridden on the stage from the test changes what the page paints (no org record changes)
 *   - axe (WCAG 2.0/2.1/2.2 A and AA) on each surface open on the record page
 *   - prefers-reduced-motion: the sheets' transitions are off
 *   - the mic is hidden, with its note, when the speech API is stubbed out
 *   - open speed: key to first painted frame, compact window and rail, three warm samples each
 * Model calls: 0. Writes: none (the draft is cancelled). Stills: docs/assets/fr2-review-*.png through kit.js.
 */
const fs = require('fs');
const path = require('path');
const { test, expect, still, settle } = require('../capture/kit');
const { Panel } = require('../support/panel');

const AXE_SOURCE = require('axe-core').source;
const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];
const CSS = { scale: /** @type {'css'} */ ('css') };
const OUT = process.env.REVIEW_OUT || path.join(__dirname, '..', '..', 'test-results', 'review', 'results.jsonl');
const SECTIONS = ['deals', 'activity', 'cases', 'summary'];

function record(entry) {
    fs.mkdirSync(path.dirname(OUT), { recursive: true });
    fs.appendFileSync(OUT, JSON.stringify(entry) + '\n');
    console.log(JSON.stringify(entry));
}

/** axe on one element (the stage): rule ids, impact and node count only. */
async function axeOn(locator) {
    await locator.page().evaluate(AXE_SOURCE);
    const r = await locator.evaluate(
        (el, tags) => /** @type {any} */ (window).axe.run(el, { runOnly: { type: 'tag', values: tags } }),
        WCAG_TAGS
    );
    return {
        passes: r.passes.length,
        violations: r.violations.map((v) => ({ id: v.id, impact: v.impact, nodes: v.nodes.length, where: v.nodes.map((n) => String(n.target).slice(-80)) }))
    };
}

/** Counts Aura requests for one controller method; bodies are never kept. */
function countRequests(page, method) {
    const counter = { count: 0 };
    page.on('request', (r) => {
        const body = r.postData();
        if (body && r.url().includes('/aura')) {
            try {
                if (decodeURIComponent(body.replace(/\+/g, ' ')).includes('"method":"' + method + '"')) counter.count += 1;
            } catch (e) {
                // not an Aura body
            }
        }
    });
    return counter;
}

function anchorOf(page) {
    return page.getByRole('button', { name: 'Search', exact: true }).first();
}

/** ms from the K keydown to the frame painted after the element is marked open (data-open="true"). */
async function timeOpen(page, panel, element, key) {
    const anchor = anchorOf(page);
    await expect
        .poll(async () => {
            await anchor.focus();
            await page.waitForTimeout(150);
            return panel.focused(anchor);
        }, { message: 'the key is pressed on the page' })
        .toBe(true);
    const measured = element.evaluate(
        (el) =>
            new Promise((resolve) => {
                let start = 0;
                const onKey = (e) => {
                    if (!start && (e.key === 'k' || e.key === 'K')) start = performance.now();
                };
                window.addEventListener('keydown', onKey, true);
                const observer = new MutationObserver(() => {
                    if (el.getAttribute('data-open') !== 'true') return;
                    observer.disconnect();
                    requestAnimationFrame(() =>
                        setTimeout(() => {
                            window.removeEventListener('keydown', onKey, true);
                            resolve(start ? performance.now() - start : -1);
                        }, 0)
                    );
                });
                observer.observe(el, { attributes: true, attributeFilter: ['data-open'] });
            })
    );
    await page.waitForTimeout(100);
    await page.keyboard.press(key);
    const ms = /** @type {number} */ (await measured);
    await expect(element).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(element).toBeHidden();
    return Math.round(ms);
}

for (const vp of [
    { width: 1440, height: 900 },
    { width: 1280, height: 720 }
]) {
    const tag = String(vp.width);
    const FULL = { x: 0, y: 0, width: vp.width, height: vp.height };

    test.describe(`FR2 review at ${vp.width}x${vp.height}`, () => {
        test.use({ viewport: vp });

        test(`${tag} compact window: hotkey and click, quick actions, voice, brand variable, axe, open speed`, async ({ page, panel }) => {
            await settle(page, 1500);
            // By the hotkey.
            await panel.open();
            await panel.sheet.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
            const box = await panel.dialog.boundingBox();
            const quick = panel.host.getByRole('group', { name: 'Quick actions', exact: true });
            await expect(panel.dialog.locator('button.abp-quick').first()).toBeVisible();
            const chipButtons = panel.dialog.locator('button.abp-quick');
            const chips = [];
            for (let i = 0; i < (await chipButtons.count()); i += 1) chips.push((await chipButtons.nth(i).innerText()) || '');
            const row = await quick.evaluate((el) => ({ scrollWidth: el.scrollWidth, clientWidth: el.clientWidth }));
            const mic = panel.host.getByRole('button', { name: /^(Talk|Stop)$/ });
            await expect(mic).toBeVisible();
            const micLabel = await mic.getAttribute('aria-label');
            const axe = await axeOn(panel.host);
            record({
                vp: tag,
                check: 'compact',
                byHotkey: true,
                box: box && { w: Math.round(box.width), h: Math.round(box.height), right: Math.round(vp.width - box.x - box.width), bottom: Math.round(vp.height - box.y - box.height) },
                chips: chips.map((s) => s.trim()),
                chipRowOverflowPx: row.scrollWidth - row.clientWidth,
                micLabel,
                axe
            });
            await panel.composer.blur();
            await page.mouse.move(vp.width - 40, 20);
            await still(page, `fr2-review-${tag}-compact.png`, FULL, CSS);

            // Esc (from inside the window) closes; a click on the launcher opens it again.
            await panel.composer.focus();
            await page.keyboard.press('Escape');
            await expect(panel.dialog).toBeHidden();
            await panel.launcher.click();
            await expect(panel.dialog).toBeVisible();
            await panel.expectFocused(panel.composer, 'the composer has focus after a click on the launcher');
            record({ vp: tag, check: 'compact', byClick: true });

            // Brand: override one theme variable on the stage, from the test only, and read what is painted.
            const send = panel.dialog.getByRole('button', { name: /^(Talk|Stop)$/ });
            const before = await send.evaluate((el) => getComputedStyle(el).borderColor);
            const launcherBefore = await panel.host.evaluate((el) => getComputedStyle(el).getPropertyValue('--cs-color-primary').trim());
            await panel.host.evaluate((el) => /** @type {HTMLElement} */ (el).style.setProperty('--cs-color-primary', 'rgb(200, 30, 120)'));
            await panel.settle();
            const after = await send.evaluate((el) => getComputedStyle(el).borderColor);
            record({ vp: tag, check: 'brand', variable: '--cs-color-primary', stageValueBefore: launcherBefore, micBorderBefore: before, micBorderAfter: after, changed: before !== after });
            if (tag === '1440') {
                await page.mouse.move(vp.width - 40, 20);
                await still(page, `fr2-review-${tag}-brand.png`, FULL, CSS);
            }
            expect(after, 'the overridden variable reaches the mic button border').toBe('rgb(200, 30, 120)');
            await panel.host.evaluate((el, v) => /** @type {HTMLElement} */ (el).style.setProperty('--cs-color-primary', v), launcherBefore);
            await page.keyboard.press('Escape');
            await expect(panel.dialog).toBeHidden();

            // Open speed: three warm samples each, after one warm open from the page (as e2e spec 10 does).
            const key = await panel.hotkey();
            await anchorOf(page).focus();
            await panel.open();
            await page.keyboard.press('Escape');
            await expect(panel.dialog).toBeHidden();
            const compactMs = [];
            for (let i = 0; i < 3; i += 1) compactMs.push(await timeOpen(page, panel, panel.sheet, key));
            const railMs = [];
            for (let i = 0; i < 3; i += 1) railMs.push(await timeOpen(page, panel, panel.rail, await panel.railHotkey()));
            record({ vp: tag, check: 'speed', compactFirstPaintMs: compactMs, railFirstPaintMs: railMs, budgetMs: 300 });
        });

        test(`${tag} draft card to Cancel, Expand keeps the thread, rail context, timeline and chart, axe`, async ({ page, panel }) => {
            const commits = countRequests(page, 'commitAction');
            await settle(page, 1500);
            await panel.open();
            const chip = panel.host.getByRole('group', { name: 'Quick actions', exact: true }).getByRole('button', { name: 'Create a follow-up', exact: true });
            const drafted = panel.apexResponse('draftAction', 60_000);
            await chip.click();
            await drafted;
            await panel.settle();
            const card = panel.host.locator('c-customer-summary-card article[data-type="actionDraft"]');
            await expect(card).toHaveCount(1, { timeout: 60_000 });
            const confirm = card.getByRole('button', { name: 'Confirm', exact: true });
            const turnsBefore = await panel.turns.count();
            const axeDraft = await axeOn(panel.host);
            record({ vp: tag, check: 'draft', turns: turnsBefore, confirmDisabled: await confirm.isDisabled(), axe: axeDraft });
            if (tag === '1440') {
                await page.mouse.move(vp.width - 40, 20);
                await still(page, `fr2-review-${tag}-draft.png`, FULL, CSS);
            }

            // Expand: the same thread in the rail.
            await panel.expandButton.click();
            await expect(panel.rail).toBeVisible();
            await expect(panel.dialog).toBeHidden();
            await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
            const turnsAfter = await panel.turns.count();
            const draftInRail = await panel.rail.locator('c-customer-summary-card article[data-type="actionDraft"]').count();
            const sections = {};
            for (const name of SECTIONS) {
                const body = panel.railSection(name);
                await expect(body).toHaveAttribute('aria-busy', 'false', { timeout: 20_000 });
                sections[name] = await body.evaluate((el) => (el.textContent || '').replace(/\s+/g, ' ').trim().length);
            }
            const history = panel.rail.locator('c-customer-summary-history-timeline');
            const chart = panel.rail.locator('c-customer-summary-sentiment-chart');
            await expect(history).toBeVisible({ timeout: 20_000 });
            await expect(chart).toBeVisible({ timeout: 20_000 });
            await expect(history.locator('c-customer-summary-card').or(history.getByTestId('empty')).first()).toBeVisible({ timeout: 20_000 });
            await expect(chart.locator('svg').or(chart.getByTestId('note')).first()).toBeVisible({ timeout: 20_000 });
            const points = await chart.locator('[data-point]').count();
            const chartBox = await chart.boundingBox();
            const timelineEntries = await history.locator('li').count();
            const railBox = await panel.rail.boundingBox();
            const axeRail = await axeOn(panel.host);
            record({
                vp: tag,
                check: 'rail',
                turnsBefore,
                turnsAfter,
                threadKept: turnsBefore === turnsAfter,
                draftInRail,
                railWidth: railBox && Math.round(railBox.width),
                sectionTextChars: sections,
                timelineEntries,
                chartPoints: points,
                chartWidth: chartBox && Math.round(chartBox.width),
                axe: axeRail
            });
            await panel.composer.blur();
            await page.mouse.move(200, 400);
            await still(page, `fr2-review-${tag}-rail.png`, FULL, CSS);
            if (tag === '1440') {
                await chart.scrollIntoViewIfNeeded();
                await still(page, `fr2-review-${tag}-history.png`, FULL, CSS);
            }

            // Cancel the draft wherever it is now; nothing is written.
            const anyCard = panel.host.locator('c-customer-summary-card article[data-type="actionDraft"]').last();
            if (await anyCard.count()) {
                await anyCard.getByRole('button', { name: 'Cancel', exact: true }).click();
                await expect(panel.host.locator('.abp-action-note').last()).toHaveText('Cancelled. Nothing was saved.');
            }
            record({ vp: tag, check: 'cancel', commitActionRequests: commits.count });
            expect(commits.count, 'no commitAction request was sent').toBe(0);
        });

        test(`${tag} history reopen`, async ({ page, panel }) => {
            await settle(page, 1500);
            await panel.open();
            const toggle = panel.host.getByRole('button', { name: 'History', exact: true });
            const region = panel.host.locator('.abp-sessions');
            const rows = region.locator('button.abp-session');
            await toggle.click();
            await expect(toggle).toHaveAttribute('aria-expanded', 'true');
            await expect(rows.first().or(region.getByText(/No earlier conversations/i)).first()).toBeVisible({ timeout: 30_000 });
            const listed = await rows.count();
            let reopenedTurns = 0;
            if (listed > 0) {
                await rows.first().click();
                await expect(region).toBeHidden({ timeout: 60_000 });
                await expect(panel.turns.first()).toBeVisible();
                reopenedTurns = await panel.turns.count();
            }
            record({ vp: tag, check: 'historyReopen', listed, reopenedTurns });
            if (tag === '1440') {
                await panel.composer.blur();
                await page.mouse.move(vp.width - 40, 20);
                await still(page, `fr2-review-${tag}-reopen.png`, FULL, CSS);
            }
            expect(reopenedTurns, 'the reopened conversation has turns').toBeGreaterThan(0);
        });

        test(`${tag} reduced motion turns the transitions off`, async ({ page }) => {
            await page.emulateMedia({ reducedMotion: 'reduce' });
            const panel = new Panel(page);
            await panel.gotoAccount();
            await panel.open();
            const sheet = await panel.sheet.evaluate((el) => getComputedStyle(el).transitionDuration);
            await page.keyboard.press('Escape');
            await panel.openRail();
            const rail = await panel.rail.evaluate((el) => getComputedStyle(el).transitionDuration);
            const running = await panel.rail.evaluate((el) => el.getAnimations().length);
            await page.keyboard.press('Escape');
            await page.emulateMedia({ reducedMotion: 'no-preference' });
            await panel.open();
            const sheetNormal = await panel.sheet.evaluate((el) => getComputedStyle(el).transitionDuration);
            record({ vp: tag, check: 'reducedMotion', sheet, rail, railAnimations: running, sheetWithoutPreference: sheetNormal });
            expect(sheet.split(',').every((d) => parseFloat(d) === 0)).toBe(true);
            expect(rail.split(',').every((d) => parseFloat(d) === 0)).toBe(true);
        });
    });
}

test('1440 voice: the mic is hidden, with its note, when the speech API is stubbed out', async ({ page }) => {
    await page.addInitScript(() => {
        const w = /** @type {any} */ (window);
        try {
            delete w.SpeechRecognition;
            delete w.webkitSpeechRecognition;
        } catch (e) {
            // fall through to the define below
        }
        Object.defineProperty(window, 'SpeechRecognition', { value: undefined, configurable: true });
        Object.defineProperty(window, 'webkitSpeechRecognition', { value: undefined, configurable: true });
    });
    const panel = new Panel(page);
    await panel.gotoAccount();
    await panel.open();
    const mic = panel.host.getByRole('button', { name: /^(Talk|Stop)$/ });
    const note = panel.host.getByText('Voice input is not available in this browser. You can type instead.', { exact: true });
    await expect(note).toBeVisible();
    const micCount = await mic.count();
    record({ vp: '1440', check: 'voiceStubbed', micButtons: micCount, noteShown: true });
    await panel.composer.blur();
    await still(page, 'fr2-review-1440-voice-stubbed.png', { x: 0, y: 0, width: 1440, height: 900 }, CSS);
    expect(micCount).toBe(0);
});
