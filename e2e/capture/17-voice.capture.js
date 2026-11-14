// @ts-check
/**
 * Pattern page 11 (OPS-52), the whole 1440x900 window on the Edge Communications record page:
 *   fr2-11-mic-compact.png: the compact window's composer with the mic button focused.
 *   fr2-11-mic-rail.png: the rail's composer with the mic button focused.
 * No recognizer is stubbed and no fake media flag is set, so the recording state is not captured: a
 * click in this browser does not reach a real microphone. The transcript is checked by hand (page 11).
 * No model call; nothing is written to the org.
 */
const { test, expect, still } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };

function mic(scope) {
    return scope.locator('c-customer-summary-voice-input button');
}

test('fr2-11-mic-compact.png, fr2-11-mic-rail.png', async ({ page, panel }) => {
    await panel.open();
    const inWindow = mic(panel.dialog);
    await expect(inWindow).toBeVisible();
    await inWindow.focus();
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-11-mic-compact.png', FULL, CSS);

    await panel.minimizeButton.click();
    await expect(panel.dialog).toBeHidden();
    await panel.openRail();
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const inRail = mic(panel.rail);
    await expect(inRail).toBeVisible();
    await inRail.focus();
    await page.mouse.move(400, 500);
    await still(page, 'fr2-11-mic-rail.png', FULL, CSS);
});

// The recording state, only if a real click shows it: no recognizer stub and no fake media flag. In the
// capture browser the microphone permission is not granted, so the recognizer ends at once and
// "Listening" does not show; the test then records that and takes no still. Nothing is spoken or sent.
test('fr2-11-mic-listening.png, only if it shows unstubbed', async ({ page, panel }) => {
    await panel.open();
    const button = mic(panel.dialog);
    // The keyboard, not a pointer click: the launcher strip overlaps the window's lowest pixels.
    await button.focus();
    await button.press('Enter');
    const listening = panel.dialog.locator('c-customer-summary-voice-input .status');
    const shown = await listening
        .waitFor({ state: 'visible', timeout: 3000 })
        .then(() => true)
        .catch(() => false);
    const error = await panel.dialog.locator('c-customer-summary-voice-input .error').textContent().catch(() => null);
    console.log(`mic click: Listening ${shown ? 'shown' : 'not shown'}; pressed=${await button.getAttribute('aria-pressed')}; error=${error ? 'shown' : 'none'}`);
    if (shown) {
        await page.mouse.move(1400, 20);
        await still(page, 'fr2-11-mic-listening.png', FULL, CSS);
        await button.press('Enter');
    }
});
