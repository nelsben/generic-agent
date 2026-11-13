// @ts-check
/**
 * fr2-conversation-core.png (FE-12): the whole 1440x900 window on the Edge Communications record page
 * with the panel open on c-customer-summary-conversation in its empty state: the brand bar, the empty
 * state, the quick chips, and the composer with the mic. No model call; nothing is written to the org.
 */
const { test, expect, still } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };

test('fr2-conversation-core.png', async ({ page, panel }) => {
    await panel.open();
    await expect(panel.host.locator('c-customer-summary-conversation')).toBeAttached();
    await expect(panel.host.locator('.abp-empty')).toBeVisible();
    await expect(panel.host.getByRole('group', { name: 'Quick actions', exact: true })).toBeVisible();
    await expect(panel.host.locator('c-customer-summary-voice-input')).toBeVisible();
    await expect(panel.send).toBeVisible();
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-conversation-core.png', FULL, CSS);
});
