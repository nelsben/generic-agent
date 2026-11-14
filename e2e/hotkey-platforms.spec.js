// @ts-check
/**
 * The hotkey on both branches (FE-21, N11 of the LWC review): Cmd-K where the panel reads a Mac and
 * Ctrl-K where it reads Windows or Linux. The `mac` and `windows` projects of playwright.config.js
 * set the branch (support/panel.js, platformScript), so each branch runs on any machine. All
 * tests here make no model call.
 */
const { test, expect } = require('./support/panel');

test.describe('hotkey branches @hotkey', () => {
    test('@smoke the platform key opens the window, focuses the composer, and the launcher names the key', async ({ page, panel, platform }) => {
        const mac = platform === 'mac';
        await expect(panel.launcher.locator('kbd')).toHaveText(mac ? '⌘K' : 'Ctrl K');
        await expect(panel.launcher).toHaveAttribute('aria-keyshortcuts', mac ? 'Meta+K' : 'Control+K');
        await expect(panel.dialog).toBeHidden();
        await page.keyboard.press(mac ? 'Meta+k' : 'Control+k');
        await expect(panel.dialog).toBeVisible();
        await panel.expectFocused(panel.composer, 'the composer has focus');
    });

    test('the other platform’s key does nothing', async ({ page, panel, platform }) => {
        await page.keyboard.press(platform === 'mac' ? 'Control+k' : 'Meta+k');
        await page.waitForTimeout(1_000);
        await expect(panel.dialog).toBeHidden();
    });

    test('Cmd/Ctrl-Shift-K opens the rail, not the window, and Alt opens neither', async ({ page, panel, platform }) => {
        const mod = platform === 'mac' ? 'Meta' : 'Control';
        // Shift is the rail's key (FE-15): the compact window stays shut.
        await page.keyboard.press(mod + '+Shift+k');
        await expect(panel.rail).toBeVisible();
        await expect(panel.dialog).toBeHidden();
        await page.keyboard.press('Escape');
        await expect(panel.rail).toBeHidden();
        await page.keyboard.press(mod + '+Alt+k');
        await page.waitForTimeout(1_000);
        await expect(panel.dialog).toBeHidden();
        await expect(panel.rail).toBeHidden();
    });

    test('on a Mac, Ctrl-K inside a text field is left alone: the window stays shut and the key is not taken', async ({ page, panel, platform }) => {
        test.skip(platform !== 'mac', 'the Mac branch only');
        // A stand-in text field on the page, and a listener after the panel's own that records
        // whether the keydown reached it with its default already prevented.
        await page.evaluate(() => {
            const input = document.createElement('input');
            input.setAttribute('aria-label', 'Temporary e2e field');
            input.style.cssText = 'position:fixed;top:4px;left:4px';
            document.body.appendChild(input);
            /** @type {any} */ (window).__ctrlK = [];
            window.addEventListener('keydown', (e) => {
                if (e.code === 'KeyK') /** @type {any} */ (window).__ctrlK.push({ ctrl: e.ctrlKey, prevented: e.defaultPrevented });
            });
        });
        const field = page.getByRole('textbox', { name: 'Temporary e2e field', exact: true });
        await field.focus();
        await panel.expectFocused(field, 'the stand-in field has focus');
        await page.keyboard.type('ab');
        await page.keyboard.press('Control+k');
        await page.waitForTimeout(1_000);
        await expect(panel.dialog).toBeHidden();
        const seen = await page.evaluate(() => /** @type {any} */ (window).__ctrlK);
        expect(seen, 'the key reached the page').toEqual([{ ctrl: true, prevented: false }]);
        await panel.expectFocused(field, 'focus stayed in the field');
        await field.evaluate((el) => el.remove());
    });
});
