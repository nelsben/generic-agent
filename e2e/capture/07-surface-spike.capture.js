// @ts-check
/**
 * OPS-29 FR2 surface spike: stills docs/assets/fr2-spike-*.png and the evidence lines quoted in
 * docs/research/fr2-surfaces-spike.md. It drives the throwaway "FR2 Surface Spike" app
 * (spikes/surface), not the Customer Summary panel. No model call; nothing is written to the org.
 *
 * A plain `npm run capture` skips this file. Run it on its own, once per utility bar alignment:
 *   SURFACE_SPIKE=mirrored  (the spike utility bar deployed with isLeftAligned=false)
 *   SURFACE_SPIKE=final     (the spike utility bar deployed with the default, left alignment)
 *   SURFACE_SPIKE=micfake   (the mic test again, with Chromium's fake media flags)
 * npx playwright test -c playwright.capture.config.js e2e/capture/07-surface-spike.capture.js
 *
 * Evidence lines are printed as "SPIKE <name> <json>": counts, sizes and event names only, never a
 * URL, an Id or a name.
 */
const { test, expect, still, settle } = require('./kit');
const { RUN_FILE } = require('../support/env');

const MODE = process.env.SURFACE_SPIKE || '';
const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };

// SURFACE_SPIKE=micfake: the mic test only, in Chromium with the fake media flags and the microphone granted.
if (MODE === 'micfake') {
    test.use({
        launchOptions: { args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'] },
        permissions: ['microphone']
    });
}

function run() {
    // eslint-disable-next-line global-require
    return require(RUN_FILE);
}

function log(name, value) {
    // eslint-disable-next-line no-console
    console.log('SPIKE ' + name + ' ' + JSON.stringify(value));
}

/** @param {import('@playwright/test').Page} page */
async function dismissPopups(page) {
    const walkthrough = page.getByRole('dialog').filter({ hasText: 'Meet the new Guidance Center' });
    await page.addLocatorHandler(walkthrough, async (shown) => {
        await shown.getByRole('button', { name: 'Dismiss', exact: true }).click();
    });
    // In-app guidance cards (for example "Welcome to Data Cloud") open over the bottom right corner.
    const guidance = page.locator('.forceGuidanceDocked, [class*="guidance"]').filter({ has: page.getByRole('button', { name: 'Close', exact: true }) });
    await page.addLocatorHandler(guidance.first(), async (shown) => {
        await shown.getByRole('button', { name: 'Close', exact: true }).first().click();
    });
}

/** The spike app first (so it is the current app), then the given path. */
async function open(page, path) {
    const { origin } = run();
    await dismissPopups(page);
    await page.goto(origin + '/lightning/app/c__FR2_Surface_Spike');
    await expect(page.getByRole('button', { name: 'Surface Spike', exact: true })).toBeVisible({ timeout: 90_000 });
    if (path) {
        await page.goto(origin + path);
        await expect(page.getByRole('button', { name: 'Surface Spike', exact: true })).toBeVisible({ timeout: 90_000 });
    }
    await expect(page.locator('[data-portal=launcher]')).toBeVisible({ timeout: 60_000 });
    await settle(page, 2000);
}

function recordPath() {
    return '/lightning/r/Account/' + run().accountId + '/view';
}

/** @param {import('@playwright/test').Page} page */
async function states(page) {
    const els = page.locator('c-surface-spike [data-spike-state]');
    const out = [];
    for (let i = 0; i < (await els.count()); i += 1) {
        out.push(JSON.parse((await els.nth(i).getAttribute('data-state')) || '{}'));
    }
    return out;
}

/** @param {import('@playwright/test').Page} page */
async function hotkeys(page) {
    const mac = await page.evaluate(() => /mac/i.test(navigator.platform));
    return mac ? { compact: 'Meta+k', rail: 'Meta+Shift+k' } : { compact: 'Control+k', rail: 'Control+Shift+k' };
}

/** The utility bar's visible items, left to right, with their left and right edges. */
async function barItems(page) {
    return page.locator('.oneUtilityBar button').evaluateAll((els) =>
        els
            .map((e) => {
                const r = e.getBoundingClientRect();
                const label = (e.getAttribute('title') || e.textContent || '').trim().replace(/\s+/g, ' ');
                return r.width ? { label: label.slice(0, 40), left: Math.round(r.left), right: Math.round(r.right) } : null;
            })
            .filter(Boolean)
    );
}

test.describe('surface spike', () => {
    test.skip(MODE !== 'mirrored' && MODE !== 'final', 'Set SURFACE_SPIKE to mirrored or final (see the file header).');

    test('mirrored utility bar', async ({ page }) => {
        test.skip(MODE !== 'mirrored', 'mirrored run only');
        await open(page, recordPath());
        const items = await barItems(page);
        const launcher = await page.locator('[data-portal=launcher]').boundingBox();
        log('mirrored.bar', items);
        log('mirrored.launcher', launcher);
        await page.mouse.move(700, 450);
        await still(page, 'fr2-spike-mirrored-bar.png', { x: 0, y: 700, width: 1440, height: 200 }, CSS);
    });

    test('final: launcher, compact window, rail modes, hotkeys', async ({ page }) => {
        test.skip(MODE !== 'final', 'final run only');
        const keys = await hotkeys(page);
        await open(page, recordPath());
        log('final.bar', await barItems(page));
        log('final.portal', (await states(page)).map((s) => ({ role: s.role, portal: s.portal })));
        await page.mouse.move(700, 450);
        await still(page, 'fr2-spike-launcher.png', FULL, CSS);

        // Record page: both hotkeys reach the utility item's document listener, nobody prevented them first.
        await page.keyboard.press(keys.compact);
        await expect(page.locator('[data-portal=compact]')).toBeVisible();
        await still(page, 'fr2-spike-compact.png', FULL, CSS);
        await page.keyboard.press('Escape');
        await expect(page.locator('[data-portal=compact]')).toBeHidden();

        await page.keyboard.press(keys.rail);
        await expect(page.locator('[data-portal=backdrop]')).toBeVisible();
        await still(page, 'fr2-spike-rail-sheet.png', FULL, CSS);
        log('record.keys', (await states(page)).map((s) => ({ role: s.role, compact: s.compact, rail: s.rail, prevented: s.prevented })));

        const viewportRight = () => page.locator('.viewport').first().evaluate((e) => Math.round(e.getBoundingClientRect().right));
        const before = await viewportRight();
        await page.locator('[data-portal=push]').click();
        await expect(page.locator('[data-portal=backdrop]')).toBeHidden();
        const after = await viewportRight();
        log('push', { viewportRightBefore: before, viewportRightAfter: after, component: (await states(page))[0].push });
        await still(page, 'fr2-spike-rail-push.png', FULL, CSS);

        await page.locator('[data-portal=minimize]').click();
        await expect(page.locator('[data-portal=rail]')).toHaveAttribute('data-rail', 'min');
        log('push.afterMinimize', await viewportRight());
        await page.mouse.move(700, 450);
        await still(page, 'fr2-spike-rail-min.png', FULL, CSS);

        await page.locator('[data-portal=strip]').hover();
        await expect(page.locator('[data-portal=rail]')).toHaveAttribute('data-rail', 'hover');
        await still(page, 'fr2-spike-rail-hover.png', FULL, CSS);
        await page.mouse.move(300, 450);
        await expect(page.locator('[data-portal=rail]')).toHaveAttribute('data-rail', 'min');

        // Lightning's own shortcut list, opened with its documented key (Cmd-/ on a Mac, Ctrl-/ elsewhere).
        await page.keyboard.press('Escape');
        await page.mouse.click(700, 230);
        await page.keyboard.press(keys.compact.replace('k', 'Slash'));
        const dialog = page.getByRole('dialog').filter({ hasText: /Keyboard Shortcuts/i });
        const shown = await dialog
            .waitFor({ state: 'visible', timeout: 10_000 })
            .then(() => true)
            .catch(() => false);
        if (shown) {
            const text = (await dialog.innerText()).split('\n').map((l) => l.trim()).filter(Boolean);
            log('lightning.shortcuts', text);
            await still(page, 'fr2-spike-lightning-shortcuts.png', FULL, CSS);
            await page.keyboard.press('Escape');
        } else {
            log('lightning.shortcuts', 'dialog did not open');
        }
    });

    test('final: hotkeys on the home page and an app page', async ({ page }) => {
        test.skip(MODE !== 'final', 'final run only');
        const keys = await hotkeys(page);
        await open(page, '');
        await page.keyboard.press(keys.compact);
        await page.keyboard.press('Escape');
        await page.keyboard.press(keys.rail);
        await page.keyboard.press('Escape');
        log('home.keys', (await states(page)).map((s) => ({ role: s.role, compact: s.compact, rail: s.rail, prevented: s.prevented })));

        await page.goto(run().origin + '/lightning/n/FR2_Surface_Spike');
        const probe = page.locator('c-surface-spike').filter({ hasText: 'FR2 surface spike (probe)' });
        await expect(probe).toBeVisible({ timeout: 90_000 });
        await settle(page, 2000);
        await page.keyboard.press(keys.compact);
        await page.keyboard.press('Escape');
        await page.keyboard.press(keys.rail);
        await page.keyboard.press('Escape');
        await expect(probe.locator('[data-count=rail]')).toHaveText('1');
        log('apppage.keys', (await states(page)).map((s) => ({ role: s.role, compact: s.compact, rail: s.rail, prevented: s.prevented })));
        // The page's opportunity list shows an owner alias column, which the privacy guard does not
        // rewrite: hide that card before the still.
        await page
            .locator('article')
            .filter({ hasText: 'All Opportunities' })
            .first()
            .evaluate((el) => {
                /** @type {HTMLElement} */ (el).style.visibility = 'hidden';
            });
        await page.mouse.move(700, 600);
        await still(page, 'fr2-spike-app-page.png', FULL, CSS);
    });
});

test('mic', async ({ page }) => {
    test.skip(MODE !== 'final' && MODE !== 'micfake', 'final or micfake run only');
    const fake = MODE === 'micfake';
    await dismissPopups(page);
    await page.goto(run().origin + '/lightning/app/c__FR2_Surface_Spike');
    await page.goto(run().origin + '/lightning/n/FR2_Surface_Spike');
    const probe = page.locator('c-surface-spike').filter({ hasText: 'FR2 surface spike (probe)' });
    await expect(probe).toBeVisible({ timeout: 90_000 });
    await probe.getByRole('button', { name: 'Test mic' }).click();
    await page.waitForTimeout(20_000);
    const s = JSON.parse((await probe.locator('[data-spike-state]').getAttribute('data-state')) || '{}');
    log(`mic.${fake ? 'fake' : 'plain'}`, s.mic);

    // The same calls in the page's main world, outside Lightning Web Security, for comparison.
    const main = await page.evaluate(
        () =>
            new Promise((resolve) => {
                const w = /** @type {any} */ (window);
                const Ctor = w.SpeechRecognition || w.webkitSpeechRecognition;
                const events = [];
                if (!Ctor) {
                    resolve(['unavailable']);
                    return;
                }
                const rec = new Ctor();
                rec.continuous = true;
                rec.interimResults = true;
                rec.lang = 'en-US';
                ['start', 'audiostart', 'soundstart', 'speechstart', 'end', 'nomatch', 'result'].forEach((n) => {
                    rec['on' + n] = () => events.push(n);
                });
                rec.onerror = (e) => events.push('error:' + e.error);
                try {
                    rec.start();
                    events.push('start-called');
                } catch (e) {
                    events.push('throw');
                }
                setTimeout(() => resolve(events), 15_000);
            })
    );
    log(`mic.mainworld.${fake ? 'fake' : 'plain'}`, main);
});
