// @ts-check
/**
 * brand-swap-before.png and brand-swap-after.png: the open panel in its empty state with the brand
 * record deployed at the time. No model call.
 *
 * Run once per brand, after the Brand_Setting Default record for that shot is deployed:
 *   BRAND_SHOT=before  (the shipped Default record)
 *   BRAND_SHOT=after   (the record swapped to the made-up company, see pattern page 10)
 * BRAND_AGENT_NAME is the agent name the shot must show, so a stale record fails the run.
 */
const { test, expect, still } = require('./kit');
const { oneLine } = require('./privacy');

const SHOT = process.env.BRAND_SHOT || '';
const AGENT_NAME = process.env.BRAND_AGENT_NAME || '';

test('brand-swap.png', async ({ page, panel }) => {
    // A plain `npm run capture` skips this file: each shot needs its own record deployed first.
    test.skip(SHOT !== 'before' && SHOT !== 'after', 'Set BRAND_SHOT to before or after (pattern page 10).');
    if (!AGENT_NAME) {
        throw oneLine('Set BRAND_AGENT_NAME to the agent name the deployed record carries.');
    }
    await panel.open();
    const name = panel.host.locator('.abp-agent-name');
    await expect(name).toHaveText(AGENT_NAME);
    // The whole name is in view, not cut short with an ellipsis.
    expect(await name.evaluate((el) => el.scrollWidth <= el.clientWidth)).toBe(true);
    await expect(panel.host.locator('.abp-logo')).toBeVisible();
    await expect(panel.host.locator('.abp-empty')).toBeVisible();
    await page.mouse.move(1400, 880);
    await still(page, `brand-swap-${SHOT}.png`);
});
