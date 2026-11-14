// @ts-check
/**
 * The customer history timeline and the sentiment chart (FE-19), each in the right rail of the Edge
 * Communications record page, 1440x900:
 *   fr2-history-timeline.png: the rail with the history timeline in its context column.
 *   fr2-history-sentiment.png: the rail with the sentiment chart in its context column.
 * Model calls: 0. Nothing is written to the org; both read the outcomes the account already holds.
 */
const { test, expect, still, settle } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };

test('fr2-history-timeline.png, fr2-history-sentiment.png', async ({ page, panel }) => {
    await settle(page, 2500);
    await panel.openRail();
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const history = panel.rail.locator('c-customer-summary-history-timeline');
    const chart = panel.rail.locator('c-customer-summary-sentiment-chart');
    await expect(history).toBeVisible({ timeout: 20_000 });
    await expect(chart).toBeVisible({ timeout: 20_000 });
    await expect(history.locator('c-customer-summary-card').or(history.getByTestId('empty')).first()).toBeVisible({ timeout: 20_000 });
    await expect(chart.locator('svg').or(chart.getByTestId('note')).first()).toBeVisible({ timeout: 20_000 });
    await panel.composer.blur();

    await history.scrollIntoViewIfNeeded();
    await page.mouse.move(400, 500);
    await still(page, 'fr2-history-timeline.png', FULL, CSS);

    await chart.scrollIntoViewIfNeeded();
    const point = chart.locator('[data-point]').first();
    if (await point.count()) {
        await point.focus();
    }
    await still(page, 'fr2-history-sentiment.png', FULL, CSS);
});
