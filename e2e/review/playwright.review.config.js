// @ts-check
const path = require('path');
const { defineConfig } = require('@playwright/test');
const { STATE_FILE } = require('../support/env');

/**
 * The FR2 build review's front-end checks (OPS-35): npx playwright test -c e2e/review/playwright.review.config.js
 *
 * Separate from the e2e suite and the capture run: its own folder, the file pattern *.review.js (never *.spec.js,
 * so the suite never picks it up) and its own output folder. Sign-in is the e2e suite's own global setup.
 * Stills go through e2e/capture/kit.js (the privacy guard) into docs/assets/fr2-review-*.png.
 * Tracing, video and HAR stay off: a trace records request headers and Aura bodies, which carry the session.
 * No model call and no write: every draft stops at Cancel.
 */
module.exports = defineConfig({
    testDir: __dirname,
    testMatch: '**/*.review.js',
    globalSetup: require.resolve('../global-setup.js'),
    workers: 1,
    fullyParallel: false,
    retries: 0,
    timeout: 300_000,
    expect: { timeout: 20_000 },
    reporter: [['list']],
    outputDir: path.join(__dirname, '..', '..', 'test-results', 'review'),
    use: {
        browserName: 'chromium',
        viewport: { width: 1440, height: 900 },
        deviceScaleFactor: 2,
        storageState: STATE_FILE,
        actionTimeout: 30_000,
        navigationTimeout: 90_000,
        trace: 'off',
        video: 'off',
        screenshot: 'off'
    },
    projects: [{ name: 'review', use: { browserName: 'chromium' } }]
});
