// @ts-check
/**
 * The right rail (FE-15), the whole 1440x900 window on the Edge Communications record page:
 *   fr2-rail.gif: Cmd/Ctrl-K opens the compact window, one question is asked and answered, and Expand
 *     moves the same thread into the rail beside the account's context. The wait for the answer is cut.
 *   fr2-rail-open.png: the rail after Expand, the thread in the main column and the context beside it.
 *   fr2-rail-context.png: the rail alone (640 px), the context column filled.
 * Model calls: 1. The question writes the product's own session row (OPS-52).
 */
const { test, expect, still, watch, at, settle, savedVideo, gif } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
// clamp(480px, 46vw, 640px) at a 1440 px window: the rail is the right-hand 640 px.
const RAIL = { x: 800, y: 0, width: 640, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };
const QUESTION = 'How many open opportunities does this account have?';
const ANSWER_TIMEOUT = 120_000;
const KEEP_AFTER_SEND = 1.5;
const KEEP_BEFORE_ANSWER = 0.6;
const SECTIONS = ['deals', 'activity', 'cases', 'summary'];

test('fr2-rail.gif, fr2-rail-open.png, fr2-rail-context.png', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'fr2-rail.gif');
    await settle(page, 2500);
    await page.mouse.move(1400, 20);
    const start = at(t0);
    await page.waitForTimeout(1000);

    // Open the compact window and ask.
    await panel.open();
    await page.waitForTimeout(700);
    await panel.composer.pressSequentially(QUESTION, { delay: 45 });
    await page.waitForTimeout(500);
    await panel.composer.press('Enter');
    const sent = at(t0);
    await expect(panel.turns).toHaveCount(1, { timeout: 30_000 });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
    await expect(panel.turns.first()).not.toContainText("I couldn't finish that right now");
    const arrived = at(t0);
    await page.waitForTimeout(1800);

    // Expand: the same thread moves into the rail, and the context fills beside it.
    await panel.expandButton.hover();
    await page.waitForTimeout(500);
    await panel.expandButton.click();
    await expect(panel.rail).toBeVisible();
    await expect(panel.dialog).toBeHidden();
    await expect(panel.turns).toHaveCount(1);
    for (const name of SECTIONS) {
        await expect(panel.railSection(name)).toHaveAttribute('aria-busy', 'false', { timeout: 20_000 });
    }
    await page.mouse.move(400, 500);
    await page.waitForTimeout(3000);
    const end = at(t0);

    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    await panel.composer.blur();
    await still(page, 'fr2-rail-open.png', FULL, CSS);
    await still(page, 'fr2-rail-context.png', RAIL, CSS);
    await guard.stop();

    const raw = await savedVideo(page, 'fr2-rail.gif');
    const segments =
        arrived - KEEP_BEFORE_ANSWER > sent + KEEP_AFTER_SEND
            ? [
                  [start, sent + KEEP_AFTER_SEND],
                  [arrived - KEEP_BEFORE_ANSWER, end]
              ]
            : [[start, end]];
    const info = gif(raw, 'fr2-rail.gif', segments, FULL);
    console.log(`fr2-rail.gif: ${info.duration.toFixed(1)} s, ${info.width}x${info.height}, ${info.bytes} bytes, frames in ${info.frames}`);
});
