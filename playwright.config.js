// @ts-check
const { defineConfig } = require('@playwright/test');
const { STATE_FILE } = require('./e2e/support/env');

/**
 * End-to-end suite for the Customer Summary panel, run in a real org as the signed-in sf CLI user.
 * See e2e/README.md. Serial on purpose: one browser, one user, one utility bar.
 *
 * Tracing, video and HAR stay off: a trace records request headers and Aura POST bodies, which
 * carry the session cookie and token. Screenshots on failure are kept.
 */
module.exports = defineConfig({
    testDir: './e2e',
    globalSetup: require.resolve('./e2e/global-setup.js'),
    workers: 1,
    fullyParallel: false,
    retries: 0,
    // A brief is a model call of 15-30 s; a test may wait on two of them plus page loads.
    timeout: 300_000,
    expect: { timeout: 20_000 },
    reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
    outputDir: 'test-results',
    use: {
        // No device descriptor: its fixed user agent would change what the panel's isMac() sees.
        browserName: 'chromium',
        viewport: { width: 1440, height: 900 },
        storageState: STATE_FILE,
        actionTimeout: 30_000,
        navigationTimeout: 90_000,
        trace: 'off',
        video: 'off',
        screenshot: 'only-on-failure'
    },
    // One browser, two hotkey branches (FE-21): `mac` runs every spec with the panel reading a Mac
    // (Cmd-K), `windows` runs only the hotkey specs (tagged @hotkey) reading Windows (Ctrl-K).
    // Whatever machine runs them; the project, not the machine, sets the branch.
    projects: [
        { name: 'mac', use: { browserName: 'chromium', platform: 'mac' } },
        { name: 'windows', grep: /@hotkey/, use: { browserName: 'chromium', platform: 'windows' } }
    ]
});
