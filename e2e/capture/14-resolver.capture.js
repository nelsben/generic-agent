// @ts-check
/**
 * Pattern page 01 (OPS-52), the whole 1440x900 window on the Edge Communications record page, compact window:
 *   fr2-01-not-found.png: "/brief" of a name that matches no account, and the fixed not-found line.
 *   fr2-01-several-matches.png: "/brief" of a partial name that matches several accounts, and the choice.
 * The resolver answers from SOQL: no model call. Nothing is written to the org.
 */
const { test, expect, still, watch } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };
// A name that matches no account, and a partial name that matches several sample accounts.
const UNKNOWN = '/brief Zephyr Quartz Holdings';
const PARTIAL = '/brief United Oil';

test('fr2-01-not-found.png', async ({ page, panel }) => {
    const guard = watch(page, 'fr2-01-not-found.png');
    await panel.open();
    await panel.ask(UNKNOWN);
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden({ timeout: 60_000 });
    await expect(panel.turns.last()).toContainText(/Try a fuller or different account name/);
    await panel.composer.blur();
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-01-not-found.png', FULL, CSS);
    await guard.stop();
});

test('fr2-01-several-matches.png', async ({ page, panel }) => {
    const guard = watch(page, 'fr2-01-several-matches.png');
    await panel.open();
    await panel.ask(PARTIAL);
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden({ timeout: 60_000 });
    const turn = panel.turns.last();
    const choices = turn.locator('button.abp-candidate');
    await expect(choices.first()).toBeVisible();
    expect(await choices.count()).toBeGreaterThan(1);
    await panel.composer.blur();
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-01-several-matches.png', FULL, CSS);
    await guard.stop();
});
