// @ts-check
/**
 * FE-27 in a real org: the conversation's own View record button, from the compact window and from the
 * right rail. A drill from a line of the brief opens the record view; View record must land the page on
 * that record's page (the URL path holds /lightning/r/ and the record page header shows its name).
 *
 * Model calls per run: 1 brief per test, so 2. Tagged @hotkey so both projects (mac, windows) run them.
 */
const { test, expect, ANSWER_TIMEOUT } = require('./support/panel');

/** Drills into the first drillable line of a fresh brief, then clicks View record. Returns the drilled name. */
async function drillAndView(page, panel) {
    // Not briefThisAccount: the rail shows the sessions list open, and its live region line replaces "Summary ready".
    const turnsBefore = await panel.turns.count();
    await panel.briefButton.click();
    await expect(panel.turns).toHaveCount(turnsBefore + 1, { timeout: ANSWER_TIMEOUT });
    const brief = panel.turns.last();
    await expect(panel.cards(brief).first()).toBeVisible({ timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
    const line = await panel.firstDrillLine(brief);
    expect(line, 'a brief section line is drillable').not.toBeNull();
    await /** @type {import('@playwright/test').Locator} */ (line).click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    const heading = panel.host.locator('article').getByRole('heading', { level: 2 });
    await expect(heading).toBeVisible();
    await expect(heading).not.toHaveText('');
    const name = ((await heading.innerText()) || '').trim();
    const viewRecord = panel.host.getByRole('button', { name: 'View record' });
    await expect(viewRecord).toBeVisible();
    const before = page.url();
    await viewRecord.click();
    await expect.poll(() => page.url() !== before && /\/lightning\/r\//.test(new URL(page.url()).pathname), { timeout: 30_000 }).toBe(true);
    // The record page header shows the drilled record's name.
    await expect(page.getByRole('heading', { name, exact: true }).or(page.locator('lightning-formatted-text, slot[name="primaryField"]').filter({ hasText: name })).first()).toBeVisible({ timeout: 30_000 });
    return name;
}

test.describe('conversation View record', () => {
    test('1. @hotkey View record in the compact window lands on the drilled record page', async ({ page, panel }) => {
        await panel.open();
        await drillAndView(page, panel);
    });

    test('2. @hotkey View record in the rail lands on the drilled record page', async ({ page, panel }) => {
        await panel.openRail();
        await drillAndView(page, panel);
    });
});
