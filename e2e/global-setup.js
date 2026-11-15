// @ts-check
/**
 * Signs in with the sf CLI session the developer already has: never a password.
 *
 * 1. Asks `sf org open --url-only --json` for a one-time frontdoor URL. The URL carries a
 *    session token, so it is held in memory only: never printed, logged, put in an error
 *    message, written to a file or opened in a traced context.
 * 2. Opens it in a plain (untraced) Chromium context, waits for Lightning and saves storageState
 *    to e2e/.auth/user.json (gitignored, mode 0600).
 * 3. Looks up the account Edge Communications by name and saves its Id and the Lightning origin
 *    (no secrets) to e2e/.auth/run.json for the specs.
 *
 * A missing or expired CLI session fails with one line telling the developer to log in.
 */
const fs = require('fs');
const { chromium } = require('@playwright/test');
const { ORG, SF, ACCOUNT_NAME, AUTH_DIR, STATE_FILE, RUN_FILE, sf } = require('./support/env');

/** An error Playwright prints as its message alone: no stack, no code frame. */
function oneLine(message) {
    const e = new Error(message);
    e.stack = message;
    return e;
}

function loginHint() {
    return oneLine(`No usable sf CLI session for org alias "${ORG}". Run: sf org login web -a ${ORG}`);
}

/** The frontdoor URL, or a thrown one-line hint. The URL never leaves this function's caller. */
function frontdoorUrl() {
    const out = sf(['org', 'open', '--url-only', '--json', '-o', ORG]);
    const url = out && out.status === 0 && out.result && out.result.url;
    if (!url || !/^https:\/\//.test(url)) {
        throw loginHint();
    }
    return url;
}

function accountId() {
    const soql = `SELECT Id FROM Account WHERE Name = '${ACCOUNT_NAME}' ORDER BY CreatedDate LIMIT 2`;
    const out = sf(['data', 'query', '--query', soql, '--json', '-o', ORG]);
    const records = out && out.status === 0 && out.result && out.result.records;
    if (!records) {
        throw loginHint();
    }
    if (records.length === 0) {
        throw oneLine(`No Account named "${ACCOUNT_NAME}" in org "${ORG}": the specs need it.`);
    }
    return records[0].Id;
}

module.exports = async function globalSetup() {
    if (!fs.existsSync(SF)) {
        throw oneLine(`The sf CLI was not found at ${SF}.`);
    }
    const id = accountId();
    fs.mkdirSync(AUTH_DIR, { recursive: true, mode: 0o700 });

    const browser = await chromium.launch();
    try {
        // No tracing, video or HAR on this context: the frontdoor URL and the session cookie it
        // sets must never land in an artifact.
        const context = await browser.newContext();
        const page = await context.newPage();
        try {
            await page.goto(frontdoorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
            // A new org lands on exactly /lightning (title "Home | Salesforce"), not /lightning/...
            await page.waitForURL((u) => u.pathname === '/lightning' || u.pathname.startsWith('/lightning/'), { timeout: 60_000 });
        } catch (e) {
            // Playwright's own message would quote the URL: replace it.
            throw loginHint();
        }
        // The Lightning origin (no secrets). Each test then opens the Customer Summary app itself.
        const origin = new URL(page.url()).origin;
        await context.storageState({ path: STATE_FILE });
        fs.chmodSync(STATE_FILE, 0o600);
        fs.writeFileSync(RUN_FILE, JSON.stringify({ origin, accountId: id, org: ORG }, null, 2), { mode: 0o600 });
        await context.close();
    } finally {
        await browser.close();
    }
};
