// @ts-check
const { defineConfig } = require('@playwright/test');
const { STATE_FILE } = require('./e2e/support/env');

/**
 * Evidence capture: writes the screenshots and GIFs listed in docs/assets/MANIFEST.md from the
 * live org (npm run capture; see "Capture" in e2e/README.md). Separate from the e2e suite: its own
 * test folder, file pattern and output folder, and no HTML report, so it never touches
 * test-results/.last-run.json or playwright-report/ of an e2e run.
 *
 * Sign-in is the e2e suite's own global setup. Video and screenshots only: tracing and HAR stay
 * off (a trace records request headers and Aura POST bodies, which carry the session).
 */
module.exports = defineConfig({
    testDir: './e2e/capture',
    testMatch: '**/*.capture.js',
    globalSetup: require.resolve('./e2e/global-setup.js'),
    workers: 1,
    fullyParallel: false,
    retries: 0,
    timeout: 300_000,
    expect: { timeout: 20_000 },
    reporter: [['list']],
    outputDir: 'test-results/capture',
    use: {
        browserName: 'chromium',
        viewport: { width: 1440, height: 900 },
        deviceScaleFactor: 2,
        storageState: STATE_FILE,
        actionTimeout: 30_000,
        navigationTimeout: 90_000,
        trace: 'off',
        // The video is recorded at the viewport's CSS size, so GIF crops use CSS px.
        video: { mode: 'on', size: { width: 1440, height: 900 } },
        screenshot: 'off'
    },
    projects: [{ name: 'capture', use: { browserName: 'chromium' } }]
});
