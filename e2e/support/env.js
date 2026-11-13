// @ts-check
/** Shared constants and the sf CLI runner. Nothing here prints CLI output. */
const path = require('path');
const { spawnSync } = require('child_process');

const ORG = process.env.SF_E2E_ORG || process.env.SF_TARGET_ORG || 'agent-probe';
const SF = '/usr/local/bin/sf';
const ACCOUNT_NAME = 'Edge Communications';
// Customer_Summary.app-meta.xml: a custom app, so its Lightning URL name is c__<API name>.
const APP_PATH = '/lightning/app/c__Customer_Summary';
const AUTH_DIR = path.join(__dirname, '..', '.auth');
const STATE_FILE = path.join(AUTH_DIR, 'user.json');
const RUN_FILE = path.join(AUTH_DIR, 'run.json');

/**
 * Runs sf with --json and returns the parsed object, or null. stdout and stderr are captured,
 * never echoed: some sf output (a frontdoor URL) is a secret.
 */
function sf(args) {
    const r = spawnSync(SF, args, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
        env: { ...process.env, SF_AUTOUPDATE_DISABLE: 'true', SF_DISABLE_TELEMETRY: 'true' },
        timeout: 120_000
    });
    try {
        return JSON.parse(r.stdout || '');
    } catch (e) {
        return null;
    }
}

module.exports = { ORG, SF, ACCOUNT_NAME, APP_PATH, AUTH_DIR, STATE_FILE, RUN_FILE, sf };
