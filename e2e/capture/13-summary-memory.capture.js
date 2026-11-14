// @ts-check
/**
 * Pattern pages 01 and 05 and the README (OPS-52), the whole 1440x900 window on the Edge Communications
 * record page:
 *   fr2-01-summary.gif: Cmd/Ctrl-K, "/brief Edge Communications" typed and sent, the wait cut, the summary
 *     arriving as cards in the compact window.
 *   fr2-readme-hero.gif: the same, then Expand moves the thread into the rail beside the account's context.
 *   fr2-01-summary-compact.png, fr2-01-summary-rail.png: the summary in the window and in the rail.
 *   fr2-05-followup-compact.png, fr2-05-followup-rail.png: a follow-up answered from that summary.
 * Model calls: 2 (the summary and the follow-up). They write the product's own session and outcome rows.
 *
 *   fr2-05-reopened-compact.png, fr2-05-reopened-rail.png: History, a past conversation reopened (window)
 *     and the History list (rail). No model call.
 *   fr2-05-outcomes-rail.png: the rail's context column with the outcome timeline at its top and the
 *     sentiment chart under it, or their empty lines. No model call; it writes nothing.
 */
const { test, expect, still, watch, at, settle, savedVideo, gif } = require('./kit');
const { ANSWER_TIMEOUT } = require('../support/panel');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };
const BRIEF = '/brief Edge Communications';
const FOLLOWUP = 'In one sentence, what is the main risk in that summary?';
const KEEP_AFTER_SEND = 1.5;
const KEEP_BEFORE_ANSWER = 0.6;
const SECTIONS = ['deals', 'activity', 'cases', 'summary'];

/**
 * Scrolls the question's nearest scrolling ancestor (the conversation's scroll box, in the window or
 * the rail) so the turn's question sits at its top, or as near as the box's end allows. Only that box moves: scrollIntoView would also
 * scroll the rail's dialog and leave the page half off screen. Throws when the question did not get
 * there: the still would not show what its caption says.
 */
async function questionToTop(page, turn) {
    const question = turn.locator('.abp-question').first();
    const off = await question.evaluate((el) => {
        let box = el.parentElement;
        const up = (n) => n.parentElement || (n.getRootNode() instanceof ShadowRoot ? /** @type {any} */ (n.getRootNode()).host : null);
        while (box && !(box.scrollHeight > box.clientHeight + 1 && /auto|scroll/.test(getComputedStyle(box).overflowY))) {
            box = up(box);
        }
        if (!box) {
            return -1;
        }
        box.scrollTop += el.getBoundingClientRect().top - box.getBoundingClientRect().top - 4;
        // The last turn may be too short to reach the top: then the box is scrolled to its end.
        const atEnd = box.scrollTop + box.clientHeight >= box.scrollHeight - 2;
        return atEnd ? 0 : Math.abs(el.getBoundingClientRect().top - box.getBoundingClientRect().top - 4);
    });
    await page.waitForTimeout(400);
    if (off < 0 || off > 40) {
        throw new Error(`questionToTop: the question is ${Math.round(off)} px from the top of its scroll box.`);
    }
}

function sessionsOf(panel) {
    const toggle = panel.host.getByRole('button', { name: 'History', exact: true });
    const region = panel.host.locator('.abp-sessions');
    return { toggle, region, rows: region.locator('button.abp-session') };
}

test('fr2-01-summary.gif, fr2-readme-hero.gif and the summary and follow-up stills', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'the summary');
    await settle(page, 4000);
    await page.mouse.move(1400, 20);
    const start = at(t0);
    await page.waitForTimeout(1000);

    await panel.open();
    await page.waitForTimeout(700);
    await panel.composer.pressSequentially(BRIEF, { delay: 60 });
    await page.waitForTimeout(500);
    await panel.composer.press('Enter');
    const sent = at(t0);
    await expect(panel.liveRegion).toHaveText(/^Summary ready: /, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();
    const arrived = at(t0);
    // The first turn, by position: last() would move to the follow-up once it is asked.
    const summary = panel.turns.first();
    await expect(summary.locator('c-customer-summary-card article[data-type="summary"]')).toHaveCount(1);
    await page.waitForTimeout(3500);
    const summaryEnd = at(t0);

    await panel.composer.blur();
    await questionToTop(page, summary);
    await still(page, 'fr2-01-summary-compact.png', FULL, CSS);

    // The follow-up, answered from the summary the panel sends back as history.
    await panel.ask(FOLLOWUP);
    await expect(panel.turns).toHaveCount(2, { timeout: 30_000 });
    await expect(panel.liveRegion).toHaveText('Answer ready', { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();
    await expect(panel.turns.last()).not.toContainText("I couldn't finish that right now");
    await panel.composer.blur();
    await questionToTop(page, panel.turns.last());
    await still(page, 'fr2-05-followup-compact.png', FULL, CSS);

    // Back to the summary, then Expand: the same thread moves into the rail.
    await questionToTop(page, summary);
    await page.mouse.move(1400, 20);
    await page.waitForTimeout(800);
    const expandStart = at(t0);
    await panel.expandButton.hover();
    await page.waitForTimeout(500);
    await panel.expandButton.click();
    await expect(panel.rail).toBeVisible();
    await expect(panel.turns).toHaveCount(2);
    for (const name of SECTIONS) {
        await expect(panel.railSection(name)).toHaveAttribute('aria-busy', 'false', { timeout: 20_000 });
    }
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    await page.mouse.move(400, 500);
    await page.waitForTimeout(3000);
    const expandEnd = at(t0);

    // History opens with the rail; fold it so the thread has the column.
    const history = panel.rail.getByRole('button', { name: 'History', exact: true });
    if ((await history.getAttribute('aria-expanded')) === 'true') {
        await history.click();
        await expect(history).toHaveAttribute('aria-expanded', 'false');
    }
    await panel.composer.blur();
    await questionToTop(page, summary);
    await still(page, 'fr2-01-summary-rail.png', FULL, CSS);
    await questionToTop(page, panel.turns.last());
    await still(page, 'fr2-05-followup-rail.png', FULL, CSS);
    await guard.stop();

    const raw = await savedVideo(page, 'fr2-readme-hero.gif');
    const ask =
        arrived - KEEP_BEFORE_ANSWER > sent + KEEP_AFTER_SEND
            ? [
                  [start, sent + KEEP_AFTER_SEND],
                  [arrived - KEEP_BEFORE_ANSWER, summaryEnd]
              ]
            : [[start, summaryEnd]];
    const one = gif(raw, 'fr2-01-summary.gif', ask, FULL);
    console.log(`fr2-01-summary.gif: ${one.duration.toFixed(1)} s, ${one.width}x${one.height}, ${one.bytes} bytes`);
    const hero = gif(raw, 'fr2-readme-hero.gif', [...ask, [expandStart, expandEnd]], FULL);
    console.log(`fr2-readme-hero.gif: ${hero.duration.toFixed(1)} s, ${hero.width}x${hero.height}, ${hero.bytes} bytes`);
});

test('fr2-05-reopened-compact.png, fr2-05-reopened-rail.png', async ({ page, panel }) => {
    await settle(page, 2000);
    await panel.open();
    const { toggle, region, rows } = sessionsOf(panel);
    await toggle.click();
    await expect(rows.first()).toBeVisible({ timeout: 30_000 });
    await rows.first().click();
    await expect(region).toBeHidden({ timeout: 60_000 });
    await expect(panel.turns.first()).toBeVisible();
    await panel.settle();
    await panel.composer.blur();
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-05-reopened-compact.png', FULL, CSS);

    await panel.minimizeButton.click();
    await expect(panel.dialog).toBeHidden();
    await panel.openRail();
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const rail = sessionsOf(panel);
    if ((await rail.toggle.getAttribute('aria-expanded')) !== 'true') {
        await rail.toggle.click();
    }
    await expect(rail.rows.first()).toBeVisible({ timeout: 30_000 });
    await panel.composer.blur();
    await page.mouse.move(400, 500);
    await still(page, 'fr2-05-reopened-rail.png', FULL, CSS);
});

test('fr2-05-outcomes-rail.png', async ({ page, panel }) => {
    await settle(page, 2500);
    await panel.openRail();
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const history = panel.rail.locator('c-customer-summary-history-timeline');
    const chart = panel.rail.locator('c-customer-summary-sentiment-chart');
    await expect(history).toBeVisible({ timeout: 20_000 });
    await expect(history.locator('c-customer-summary-card').or(history.getByTestId('empty')).first()).toBeVisible({ timeout: 20_000 });
    await expect(chart.locator('svg').or(chart.getByTestId('note')).first()).toBeVisible({ timeout: 20_000 });
    // The timeline at the top of the context column, so the chart below it is in view too. Only the
    // column's own scroll box moves.
    await history.evaluate((el) => {
        let box = el.parentElement;
        while (box && !(box.scrollHeight > box.clientHeight && /auto|scroll/.test(getComputedStyle(box).overflowY))) {
            box = box.parentElement || (box.getRootNode() instanceof ShadowRoot ? /** @type {any} */ (box.getRootNode()).host : null);
        }
        if (box) {
            box.scrollTop += el.getBoundingClientRect().top - box.getBoundingClientRect().top - 8;
        }
    });
    await panel.composer.blur();
    await page.mouse.move(400, 500);
    await still(page, 'fr2-05-outcomes-rail.png', FULL, CSS);
});
