// @ts-check
/**
 * One brief of Edge Communications (one model call) and one follow-up question (one call):
 * brief-flow.gif, panel-brief.png, panel-sections-open.png and memory-followup.png.
 */
const { test, expect, watch, still, gif, at, settle, savedVideo } = require('./kit');
const { ANSWER_TIMEOUT } = require('../support/panel');

const BRIEF = '/brief Edge Communications';
const FOLLOWUP = 'In one sentence, what was the main risk in that brief?';
// The two sections panel-sections-open.png expands.
const OPEN_SECTIONS = ['Open deals', 'Service health'];
// The spinner wait is cut out of brief-flow.gif: it keeps this much after Send and before the answer.
const KEEP_AFTER_SEND = 3;
const KEEP_BEFORE_ANSWER = 1;
// brief-flow.gif ends on the arrived brief, held this long with its headline in view.
const HOLD_ON_HEADLINE = 3500;

/**
 * Scrolls the conversation so the brief's question sits at the top of the scroll box, then checks
 * that the summary's headline and the first two section headers are all inside the box. The
 * summary's rest starts collapsed, so they fit in the 340x480 panel. Throws, naming the CSS px, when
 * they do not: the still would not show what its caption says.
 */
async function headlineAndSections(panel, turn, sections) {
    await turn.locator('.abp-question').first().evaluate((el) => el.scrollIntoView({ block: 'start' }));
    await panel.page.waitForTimeout(300);
    const box = await panel.body.boundingBox();
    const headline = await panel.headline(turn).boundingBox();
    const second = await sections.nth(1).getByRole('button').first().boundingBox();
    if (!box || !headline || !second) {
        throw new Error('panel-brief.png: the scroll box, the headline or the second section is not rendered.');
    }
    const bottom = Math.ceil(second.y + second.height - box.y);
    if (headline.y < box.y || bottom > box.height) {
        throw new Error(`panel-brief.png: the headline and two section headers need ${bottom} px; the scroll box is ${Math.round(box.height)} px.`);
    }
    return { box: Math.round(box.height), needed: bottom };
}

test('brief-flow.gif, panel-brief.png, panel-sections-open.png, memory-followup.png', async ({ page, panel, t0 }) => {
    const guard = watch(page, 'the brief');
    await settle(page, 3000);
    const start = at(t0);
    await page.waitForTimeout(1200);
    await panel.open();
    await page.waitForTimeout(600);
    await panel.composer.pressSequentially(BRIEF, { delay: 80 });
    await expect(panel.send).toBeEnabled();
    await page.waitForTimeout(500);
    await panel.composer.press('Enter');
    const sent = at(t0);
    await expect(panel.liveRegion).toHaveText(/^Brief ready: /, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();
    const arrived = at(t0);
    const turn = panel.turns.last();
    await expect(panel.headline(turn)).toBeVisible();
    // The panel scrolls the new turn to the top: the question, then the headline. The GIF ends here,
    // held still on the headline.
    await page.waitForTimeout(HOLD_ON_HEADLINE);
    const end = at(t0);

    // panel-brief.png: the question at the top of the scroll box, the headline, the collapsed
    // summary and at least the first two section headers.
    const sections = turn.locator('lightning-accordion-section');
    const fit = await headlineAndSections(panel, turn, sections);
    console.log(`panel-brief.png: box ${fit.box} px, question to second section header ${fit.needed} px`);
    await panel.composer.blur();
    await still(page, 'panel-brief.png');

    // panel-sections-open.png: two sections expanded.
    for (const title of OPEN_SECTIONS) {
        const section = sections.filter({ hasText: title + ' · ' }).first();
        await section.getByRole('button').first().click();
    }
    const first = sections.filter({ hasText: OPEN_SECTIONS[0] + ' · ' }).first();
    await first.getByRole('button').first().evaluate((el) => el.scrollIntoView({ block: 'start' }));
    await still(page, 'panel-sections-open.png');
    for (const title of OPEN_SECTIONS) {
        await sections.filter({ hasText: title + ' · ' }).first().getByRole('button').first().click();
    }

    // memory-followup.png: a follow-up answered from the brief (the panel sends it as history).
    await panel.ask(FOLLOWUP);
    await expect(panel.liveRegion).toHaveText('Answer ready', { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();
    await panel.composer.blur();
    await still(page, 'memory-followup.png');
    await guard.stop();

    const raw = await savedVideo(page, 'brief-flow.gif');
    const segments =
        arrived - KEEP_BEFORE_ANSWER > sent + KEEP_AFTER_SEND
            ? [
                  [start, sent + KEEP_AFTER_SEND],
                  [arrived - KEEP_BEFORE_ANSWER, end]
              ]
            : [[start, end]];
    gif(raw, 'brief-flow.gif', segments);
});
