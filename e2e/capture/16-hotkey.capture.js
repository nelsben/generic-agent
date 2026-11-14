// @ts-check
/**
 * fr2-03-hotkey.gif (pattern page 03, OPS-52), the whole 1440x900 window on the Edge Communications record
 * page: Cmd/Ctrl-K opens the compact window, a "/brief" of an unknown name is answered by the resolver,
 * Minimize hides the window, Cmd/Ctrl-K brings it back with the same thread, and Expand moves that thread
 * into the right rail. No model call (the resolver answers from SOQL). Nothing is written to the org.
 */
const { test, expect, watch, at, settle, savedVideo, gif } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const LINE = '/brief Zephyr Quartz Holdings';
const SECTIONS = ['deals', 'activity', 'cases', 'summary'];

test('fr2-03-hotkey.gif', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'fr2-03-hotkey.gif');
    await settle(page, 4000);
    await page.mouse.move(1400, 20);
    const start = at(t0);
    await page.waitForTimeout(1000);

    await panel.open();
    await page.waitForTimeout(600);
    await panel.composer.pressSequentially(LINE, { delay: 55 });
    await page.waitForTimeout(400);
    await panel.composer.press('Enter');
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden({ timeout: 60_000 });
    await page.waitForTimeout(1500);

    // Minimize, then the key again: the same thread is still there.
    await panel.minimizeButton.hover();
    await page.waitForTimeout(400);
    await panel.minimizeButton.click();
    await expect(panel.dialog).toBeHidden();
    await expect(panel.launcher).toBeVisible();
    await page.waitForTimeout(1500);
    await panel.open();
    await expect(panel.turns).toHaveCount(1);
    await page.waitForTimeout(1500);

    // Expand: the thread moves into the rail.
    await panel.expandButton.hover();
    await page.waitForTimeout(400);
    await panel.expandButton.click();
    await expect(panel.rail).toBeVisible();
    await expect(panel.turns).toHaveCount(1);
    for (const name of SECTIONS) {
        await expect(panel.railSection(name)).toHaveAttribute('aria-busy', 'false', { timeout: 20_000 });
    }
    await page.mouse.move(400, 500);
    await page.waitForTimeout(2500);
    const end = at(t0);
    await guard.stop();

    const raw = await savedVideo(page, 'fr2-03-hotkey.gif');
    const info = gif(raw, 'fr2-03-hotkey.gif', [[start, end]], FULL);
    console.log(`fr2-03-hotkey.gif: ${info.duration.toFixed(1)} s, ${info.width}x${info.height}, ${info.bytes} bytes`);
});
