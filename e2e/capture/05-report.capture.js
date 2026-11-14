// @ts-check
/**
 * fr2-08-e2e-report.png (pattern page 08, OPS-52): the Playwright HTML report of the last full `npm run test:e2e`, opened from the
 * local file. The e2e config keeps tracing off, so the report has no trace attachments.
 */
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { test, expect, still } = require('./kit');
const { oneLine } = require('./privacy');

const REPORT = path.join(__dirname, '..', '..', 'playwright-report', 'index.html');

test('fr2-08-e2e-report.png', async ({ page }) => {
    if (!fs.existsSync(REPORT)) {
        throw oneLine('playwright-report/index.html is missing: run npm run test:e2e first.');
    }
    // 800 CSS px at deviceScaleFactor 2 is 1600 px wide.
    await page.setViewportSize({ width: 800, height: 900 });
    await page.goto(pathToFileURL(REPORT).href);
    await expect(page.getByText('panel.spec.js').first()).toBeVisible();
    await still(page, 'fr2-08-e2e-report.png', { x: 0, y: 0, width: 800, height: 900 });
});
