// @ts-check
// hotkey-open.gif: Cmd/Ctrl-K opens the panel with the composer focused, and Esc closes it. No model call.
const { test, expect, watch, at, settle, savedVideo, gif } = require('./kit');

test('hotkey-open.gif', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'hotkey-open.gif');
    await settle(page, 3000);
    const start = at(t0);
    await page.waitForTimeout(1500);
    await panel.open();
    await page.waitForTimeout(900);
    await panel.composer.pressSequentially('Which cases are still open?', { delay: 70 });
    await page.waitForTimeout(1500);
    await page.keyboard.press('Escape');
    await expect(panel.composer).toBeHidden();
    await page.waitForTimeout(2500);
    const end = at(t0);
    await guard.stop();

    const raw = await savedVideo(page, 'hotkey-open.gif');
    gif(raw, 'hotkey-open.gif', [[start, end]]);
});
