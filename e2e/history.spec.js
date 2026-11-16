// @ts-check
/**
 * The customer history timeline and the sentiment chart (FE-19, FR2) in the right rail of the Edge
 * Communications record page: both sit in the rail's context column under the sections (FE-15).
 *
 * Model calls per full run: 0. No spec inserts or changes a record, so an account with no outcomes shows
 * the empty line and passes; the outcomes an account holds come from real summaries.
 */
const { test, expect } = require('./support/panel');

const HISTORY = 'c-customer-summary-history-timeline';
const CHART = 'c-customer-summary-sentiment-chart';
const EMPTY_HISTORY = /Nothing recorded for this account yet/;
const EMPTY_CHART = /Not enough to chart yet/;

/** FE-32: History is closed by default in the rail; its timeline and chart mount when its header is opened. */
async function openHistory(panel) {
    const toggle = panel.rail.locator('[data-testid="ctx-history"] button.cs-ctx-toggle');
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');
    await toggle.click();
    await expect(toggle).toHaveAttribute('aria-expanded', 'true');
}

test.describe('customer history and sentiment in the rail', () => {
    test('1. @smoke the history timeline opens in the rail: newest entries first as a timeline card, or the empty line', async ({ panel }) => {
        await panel.openRail();
        await openHistory(panel);
        const history = panel.rail.locator(HISTORY);
        await expect(history).toBeVisible({ timeout: 20_000 });
        // Loading ends in the card or the plain empty line.
        const card = history.locator('c-customer-summary-card');
        const empty = history.getByText(EMPTY_HISTORY);
        await expect(card.or(empty).first()).toBeVisible({ timeout: 20_000 });
        if (await card.count()) {
            await expect(card.locator('time.cs-at').first()).toBeVisible();
            const dates = await card.locator('time.cs-at').allInnerTexts();
            expect(dates, 'newest first').toEqual(dates.slice().sort().reverse());
            // Opening an entry shows its detail; Close hides it. Nothing is written.
            await card.locator('button.cs-item-label').first().click();
            const detail = history.getByTestId('detail');
            await expect(detail).toBeVisible();
            await expect(detail.getByRole('heading')).not.toHaveText('');
            await detail.getByRole('button', { name: 'Close', exact: true }).click();
            await expect(detail).toBeHidden();
        }
    });

    test('2. the sentiment chart opens in the rail: labelled points and a text table, or the plain note, and it says it shows labels only', async ({
        panel
    }) => {
        await panel.openRail();
        await openHistory(panel);
        const chart = panel.rail.locator(CHART);
        await expect(chart).toBeVisible({ timeout: 20_000 });
        const svg = chart.locator('svg');
        const note = chart.getByText(EMPTY_CHART);
        await expect(svg.or(note).first()).toBeVisible({ timeout: 20_000 });
        if (await svg.count()) {
            await expect(chart.getByTestId('labels-only')).toContainText('Labels only');
            const points = svg.locator('[data-point]');
            expect(await points.count()).toBeGreaterThanOrEqual(2);
            // No line joins the points: the score is not steady enough to chart.
            await expect(svg.locator('polyline, path')).toHaveCount(0);
            // Focus a point: its date and label show, and its reason only where the viewer may see it.
            await points.first().focus();
            await expect(chart.getByTestId('focus')).toContainText(/^\d{4}-\d{2}-\d{2}, /);
            expect(await chart.locator('table tbody tr').count()).toBeGreaterThanOrEqual(2);
        }
    });
});
