// @ts-check
/**
 * FE-18 card spike captures: docs/assets/fr2-cards-{340,640}-{summary,explorer,actions}.png from the
 * "Cards Spike" tab in agent-probe (spikes/cards, deployed). It reuses the e2e suite's sign-in
 * (e2e/global-setup.js, unedited) and the capture kit's privacy guard. No model call, no write.
 *
 *   SF_E2E_ORG=agent-probe npx playwright test -c spikes/cards/__tests__/playwright.cards.config.js
 *
 * The viewport is tall so a whole group fits without scrolling. Test output goes outside the repo
 * (CARDS_CAPTURE_OUT, default the system temp folder). Video and tracing stay off.
 */
const os = require('os');
const path = require('path');
const { defineConfig } = require('@playwright/test');
const { STATE_FILE } = require('../../../e2e/support/env');

module.exports = defineConfig({
    testDir: __dirname,
    testMatch: 'cards.capture.js',
    globalSetup: require.resolve('../../../e2e/global-setup.js'),
    workers: 1,
    retries: 0,
    timeout: 240_000,
    expect: { timeout: 20_000 },
    reporter: [['list']],
    outputDir: process.env.CARDS_CAPTURE_OUT || path.join(os.tmpdir(), 'fr2-cards-capture'),
    use: {
        browserName: 'chromium',
        viewport: { width: 1440, height: 4200 },
        deviceScaleFactor: 2,
        storageState: STATE_FILE,
        actionTimeout: 30_000,
        navigationTimeout: 90_000,
        trace: 'off',
        video: 'off',
        screenshot: 'off'
    }
});
