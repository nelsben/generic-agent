// @ts-check
/**
 * panel-ask-agent.png: "Ask the agent" in the custom panel. The composer's question goes to the
 * registered Account_Brief agent through Apex (AccountBriefPanelController.askAgent) and the reply
 * shows in the panel, under the question. One agent turn, on the Edge Communications page.
 */
const { test, expect, watch, still } = require('./kit');
const { ANSWER_TIMEOUT } = require('../support/panel');

const QUESTION = 'What are the open deals at this account?';

test('panel-ask-agent.png', async ({ page, panel }) => {
    const guard = watch(page, 'the agent turn');
    await panel.open();
    await expect(panel.agentButton).toBeVisible({ timeout: 30_000 });
    await panel.composer.fill(QUESTION);
    await panel.agentButton.click();
    await expect(panel.liveRegion).toHaveText('Asking the agent');
    await expect(panel.liveRegion).toHaveText('Agent replied', { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();
    const turn = panel.turns.last();
    await expect(turn.locator('.abp-question')).toHaveText(QUESTION);
    await expect(turn.locator('[data-error="true"]')).toHaveCount(0);
    // The question at the top of the scroll box, the start of the reply under it.
    await turn.locator('.abp-question').evaluate((el) => el.scrollIntoView({ block: 'start' }));
    await page.waitForTimeout(300);
    await panel.composer.blur();
    await still(page, 'panel-ask-agent.png');
    await guard.stop();
});
