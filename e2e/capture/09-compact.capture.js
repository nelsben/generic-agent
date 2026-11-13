// @ts-check
/**
 * The compact window (FE-13), the whole 1440x900 window on the Edge Communications record page:
 *   fr2-compact-launcher.png: closed, the launcher at the bottom right with the agent name and the key.
 *   fr2-compact-open.png: open after Cmd/Ctrl-K, the 420x560 window in the same corner, empty state.
 * No model call; nothing is written to the org.
 */
const { test, expect, still } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };

test('fr2-compact-launcher.png', async ({ page, panel }) => {
    await expect(panel.launcher).toBeVisible();
    await expect(panel.dialog).toBeHidden();
    // The brand settings have arrived: the launcher carries the agent's name.
    await expect(panel.launcher).not.toHaveText(/Ask the assistant/);
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-compact-launcher.png', FULL, CSS);
});

test('fr2-compact-open.png', async ({ page, panel }) => {
    await panel.open();
    await expect(panel.host.locator('.abp-empty')).toBeVisible();
    await expect(panel.launcher).toBeHidden();
    // The slide (280 ms) is over.
    await panel.sheet.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-compact-open.png', FULL, CSS);
});
