// @ts-check
/**
 * Pattern page 02 (OPS-52), the whole 1440x900 window on the Edge Communications record page:
 *   fr2-02-explorer-compact.png: a whole-org question and its answer, a short lead and a table card.
 *   fr2-02-drill.gif: a click on the table card's first record opens its drill view; the breadcrumb returns.
 *   fr2-02-explorer-rail.png: the same answer after Expand, at rail width.
 * Model calls: one explorer run. The question asks for no owners. Nothing is written to the org beyond
 * the product's own session row.
 */
const { test, expect, still, watch, gif, at, settle, savedVideo } = require('./kit');
const { ANSWER_TIMEOUT } = require('../support/panel');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };
const QUESTION = 'Which 5 open opportunities have the largest amounts?';

/** Scrolls the question's own scroll box (window or rail) so the question sits at its top. */
async function questionToTop(page, turn) {
    await turn.locator('.abp-question').first().evaluate((el) => {
        let box = el.parentElement;
        const up = (n) => n.parentElement || (n.getRootNode() instanceof ShadowRoot ? /** @type {any} */ (n.getRootNode()).host : null);
        while (box && !(box.scrollHeight > box.clientHeight + 1 && /auto|scroll/.test(getComputedStyle(box).overflowY))) {
            box = up(box);
        }
        if (box) {
            box.scrollTop += el.getBoundingClientRect().top - box.getBoundingClientRect().top - 4;
        }
    });
    await page.waitForTimeout(400);
}

test('fr2-02-explorer-compact.png, fr2-02-drill.gif, fr2-02-explorer-rail.png', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'the explorer');
    await panel.open();
    const scope = panel.host.getByRole('group', { name: 'Question scope', exact: true });
    await scope.getByRole('button', { name: 'Ask the whole org', exact: true }).click();
    await expect(scope.locator('.abp-scope-label')).toHaveText('Whole org');
    await panel.ask(QUESTION);
    await expect(panel.turns).toHaveCount(1, { timeout: 30_000 });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
    const turn = panel.turns.first();
    await expect(turn).not.toContainText("I couldn't finish that right now");
    const table = turn.locator('c-customer-summary-card article[data-type="table"]');
    await expect(table.first()).toBeVisible();
    const row = table.first().locator('button.cs-link[data-ref]').first();
    await expect(row).toBeVisible();
    await panel.composer.blur();
    await questionToTop(page, turn);
    await page.mouse.move(1400, 20);
    await still(page, 'fr2-02-explorer-compact.png', FULL, CSS);

    // The drill: click the first record of the table, then the breadcrumb back.
    await settle(page, 1000);
    const start = at(t0);
    await page.waitForTimeout(1200);
    await row.hover();
    await page.waitForTimeout(400);
    await row.click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    await expect(panel.host.locator('article').getByRole('heading', { level: 2 }).first()).toBeVisible();
    await page.waitForTimeout(3000);
    await panel.breadcrumbs.getByRole('link', { name: 'Conversation', exact: true }).click();
    await expect(panel.breadcrumbs).toBeHidden();
    await page.waitForTimeout(2500);
    const end = at(t0);

    // Expand: the same answer at rail width.
    await panel.expandButton.click();
    await expect(panel.rail).toBeVisible();
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    const history = panel.rail.getByRole('button', { name: 'History', exact: true });
    if ((await history.getAttribute('aria-expanded')) === 'true') {
        await history.click();
    }
    await panel.composer.blur();
    await questionToTop(page, panel.turns.first());
    await page.mouse.move(400, 500);
    await still(page, 'fr2-02-explorer-rail.png', FULL, CSS);
    await guard.stop();

    const raw = await savedVideo(page, 'fr2-02-drill.gif');
    const info = gif(raw, 'fr2-02-drill.gif', [[start, end]], FULL);
    console.log(`fr2-02-drill.gif: ${info.duration.toFixed(1)} s, ${info.width}x${info.height}, ${info.bytes} bytes`);
});
