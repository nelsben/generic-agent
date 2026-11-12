// @ts-check
/**
 * One org-wide question (one explorer run) and a drill into one of its rows (Apex, no model):
 * explore-answer.png, explore-drill.gif and drill-view.png. The question asks for no owners.
 */
const { test, expect, watch, still, gif, at, settle, savedVideo } = require('./kit');
const { ANSWER_TIMEOUT } = require('../support/panel');

// The explorer tends to list every row in its text, which pushes the table out of a 340x480 panel;
// asking for one sentence keeps the question, the answer and the table's header row in one view.
const QUESTION = 'Which 5 open opportunities have the largest amounts? Answer in one sentence.';

test('explore-answer.png, explore-drill.gif, drill-view.png', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'the explorer');
    await panel.open();
    await panel.ask(QUESTION);
    await expect(panel.liveRegion).toHaveText('Answer ready', { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();
    const turn = panel.turns.last();
    const rows = turn.locator('button.abp-row-button');
    await expect(rows.first()).toBeVisible();
    await panel.composer.blur();

    // explore-answer.png: the question at the top of the scroll box, then the one-sentence answer, the
    // table's title and its header row. The run fails, naming the CSS px, if the header row does not
    // fit under the question: the still would not show what its caption says.
    const question = turn.locator('.abp-question').first();
    await question.evaluate((el) => el.scrollIntoView({ block: 'start' }));
    await page.waitForTimeout(300);
    const box = await panel.body.boundingBox();
    const head = await turn.locator('table thead').first().boundingBox();
    if (!box || !head) {
        throw new Error('explore-answer.png: the scroll box or the table header row is not rendered.');
    }
    const needed = Math.ceil(head.y + head.height - box.y);
    if (needed > box.height) {
        throw new Error(`explore-answer.png: the question to the header row needs ${needed} px; the scroll box is ${Math.round(box.height)} px.`);
    }
    console.log(`explore-answer.png: box ${Math.round(box.height)} px, question to header row ${needed} px`);
    await still(page, 'explore-answer.png');

    // explore-drill.gif: click a row, the drill view opens, the breadcrumb goes back.
    await settle(page, 1000);
    const start = at(t0);
    await page.waitForTimeout(1200);
    await rows.first().click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    await expect(panel.host.locator('article h2')).toBeVisible();
    await page.waitForTimeout(3000);
    await panel.breadcrumbs.getByRole('link', { name: 'Conversation', exact: true }).click();
    await expect(panel.breadcrumbs).toBeHidden();
    await page.waitForTimeout(2500);
    const end = at(t0);

    // drill-view.png: the same row's drill view again, outside the recorded span.
    await rows.first().click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    await expect(panel.host.locator('article h2')).toBeVisible();
    await still(page, 'drill-view.png');
    await guard.stop();

    const raw = await savedVideo(page, 'explore-drill.gif');
    gif(raw, 'explore-drill.gif', [[start, end]]);
});
