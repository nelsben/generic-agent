// @ts-check
// not-found.png and ambiguous.png: the resolver answers from SOQL, so neither makes a model call.
const { test, expect, watch, still } = require('./kit');

// A name that matches no account, and a partial name that matches three demo accounts.
const UNKNOWN = '/brief Zephyr Quartz Holdings';
const PARTIAL = '/brief United Oil';

test('not-found.png', async ({ page, panel }) => {
    const guard = watch(page, 'not-found.png');
    await panel.open();
    await panel.ask(UNKNOWN);
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden();
    await expect(panel.turns.last().locator('.abp-pre').first()).toBeVisible();
    await panel.composer.blur();
    await still(page, 'not-found.png');
    await guard.stop();
});

test('ambiguous.png', async ({ page, panel }) => {
    const guard = watch(page, 'ambiguous.png');
    await panel.open();
    await panel.ask(PARTIAL);
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.spinner).toBeHidden();
    const candidates = panel.turns.last().locator('button.abp-candidate');
    await expect(candidates.first()).toBeVisible();
    expect(await candidates.count()).toBeGreaterThan(1);
    await panel.composer.blur();
    await still(page, 'ambiguous.png');
    await guard.stop();
});
