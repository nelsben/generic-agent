// @ts-check
/**
 * agent-brief.png and agent-explore.png: the built-in Agentforce panel in the Account Brief app,
 * on the Edge Communications page. The custom panel's "Ask the agent" button opens it and sends
 * the composer's text (lightning/accApi), so no text is typed into the built-in panel itself.
 * Two agent turns in one session: a brief, then an org-wide count.
 */
const { test, expect, watch, still, settle } = require('./kit');
const { ANSWER_TIMEOUT } = require('../support/panel');

const BRIEF = 'Brief me on Edge Communications';
const COUNT = 'How many open opportunities are there in the whole org?';
// The built-in panel docks on the right, about 400 CSS px wide: the crop is the right of the page.
const AGENT_CROP = { x: 680, y: 150, width: 760, height: 750 };
// First-run pop-ups of the built-in panel. The memory pop-up is closed with "Cancel and close",
// never accepted. The generative AI notice has one button, "Got It", which the panel needs before
// it takes a message.
const MEMORY_POPUP = 'Agentforce Learns from Your Conversations';
const AI_NOTICE = 'about to use Agentforce';

// The built-in panel's frame: a custom element with role dialog, named Agentforce.
const SIDE_PANEL = 'runtime_thp_learning-side-panel-frame';

/** The built-in panel's conversation: one list item per message. */
function chat(page) {
    return page.locator(SIDE_PANEL).getByRole('region', { name: 'Chat History', exact: true });
}

/**
 * Waits for the agent's reply number n: each finished reply carries a feedback group (Like,
 * Dislike, Copy). Then waits until nothing spins and the conversation text stops changing for 3 s.
 */
async function waitForReply(page, n) {
    const feedback = chat(page).getByRole('radiogroup', { name: /Give Feedback/ });
    await expect(feedback).toHaveCount(n, { timeout: ANSWER_TIMEOUT });
    let last = -1;
    let stableSince = Date.now();
    const deadline = Date.now() + 60_000;
    while (Date.now() < deadline) {
        // The length only; the text itself never leaves the page.
        const len = await chat(page).evaluate((el) => (el.textContent || '').length);
        if (len !== last) {
            last = len;
            stableSince = Date.now();
        } else if (Date.now() - stableSince >= 3000) {
            break;
        }
        await page.waitForTimeout(500);
    }
    await settle(page, 1000);
}

/** Scrolls the agent's conversation so the user's message with this text sits at the top. */
async function messageAtTop(page, text) {
    await chat(page).getByRole('listitem').filter({ hasText: text }).last().evaluate((el) => el.scrollIntoView({ block: 'start' }));
    await page.waitForTimeout(800);
}

/** Fills the custom panel's composer (without sending) and hands the text to the agent. */
async function askAgent(panel, text) {
    await panel.composer.fill(text);
    await panel.host.getByRole('button', { name: 'Ask the agent', exact: true }).click();
}

test('agent-brief.png, agent-explore.png', async ({ page, panel }) => {
    const popup = page.getByRole('dialog').filter({ hasText: MEMORY_POPUP });
    await page.addLocatorHandler(popup, async (shown) => {
        await shown.getByRole('button', { name: 'Cancel and close', exact: true }).click();
    });
    const notice = page.getByRole('heading', { name: new RegExp(AI_NOTICE) });
    await page.addLocatorHandler(notice, async () => {
        console.log('The generative AI notice was shown: Got It.');
        await page.locator(SIDE_PANEL).getByRole('button', { name: 'Got It', exact: true }).click();
    });
    const guard = watch(page, 'the built-in agent panel');
    await panel.open();
    const askButton = panel.host.getByRole('button', { name: 'Ask the agent', exact: true });
    await expect(askButton).toBeVisible({ timeout: 30_000 });
    // With an empty composer and no turns, the button only opens the built-in panel. It may show
    // an earlier session's messages: count the replies already there.
    await askButton.click();
    await expect(page.locator(SIDE_PANEL).getByRole('textbox', { name: /^Chat message input/ })).toBeVisible({ timeout: 60_000 });
    await settle(page, 3000);
    const before = await chat(page).getByRole('radiogroup', { name: /Give Feedback/ }).count();

    // agent-brief.png: the question and the top of the agent's brief.
    await askAgent(panel, BRIEF);
    await waitForReply(page, before + 1);
    await messageAtTop(page, BRIEF);
    await still(page, 'agent-brief.png', AGENT_CROP);

    // agent-explore.png: an org-wide count in the same session, after the brief.
    await askAgent(panel, COUNT);
    await waitForReply(page, before + 2);
    await messageAtTop(page, COUNT);
    await still(page, 'agent-explore.png', AGENT_CROP);
    await guard.stop();
});
