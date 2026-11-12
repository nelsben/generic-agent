// @ts-check
/**
 * The Account Brief panel in a real org, one journey per test. Each test loads the record page of
 * Edge Communications fresh inside the Account Brief app (see support/panel.js).
 *
 * Model calls per full run (briefs, questions and agent turns): (3) 1, (4) 2, (5) 1, (6) 0, (7) 1,
 * (8) 1-2, (9) 2 agent turns, so 8 to 9. Spec 8 asks one question only when no brief section line
 * is drillable; spec 7 fails instead.
 * Spec 5's second request and spec 6's send are '/brief' of a name that does not exist: the
 * resolver answers NOT_FOUND from SOQL alone, with no model call.
 */
const fs = require('fs');
const AxeBuilder = require('@axe-core/playwright').default;
const { test, expect, ANSWER_TIMEOUT } = require('./support/panel');
const { ACCOUNT_NAME } = require('./support/env');

// Matches no Account: the resolver answers NOT_FOUND without a model call.
const NO_SUCH_ACCOUNT = '/brief Qzxv Nonexistent E2E';
// Asked only when no brief section line is drillable; its answer is a table of Contact rows.
const DRILL_QUESTION = 'List the contacts at this account with their titles';
// Spec 9: the probe's two turns. The follow-up only makes sense after the first.
const AGENT_QUESTION = 'What are the open deals at this account?';
const AGENT_FOLLOWUP = 'What about their open cases?';
/** Text with runs of whitespace made one space, to compare a rendered reply with the returned one. */
const squash = (text) => (text || '').replace(/\s+/g, ' ').trim();
const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];

/** A focusable element on the page outside the panel: the global header's Search button. */
function pageAnchor(page) {
    return page.getByRole('button', { name: 'Search', exact: true }).first();
}

/**
 * Something to drill from, after a brief of the account: a section line that carries a record Id
 * (the panel's section drill). Spec 7 requires one. Otherwise, when no section line carries one,
 * a result row of one question is used instead, so the drill view is still reached. That
 * fallback costs one model call.
 */
async function drillOrigin(panel, { briefed = false, requireSectionDrill = true } = {}) {
    const brief = briefed ? panel.turns.last() : await panel.briefThisAccount();
    const line = await panel.firstDrillLine(brief);
    if (requireSectionDrill) {
        expect(line, 'a brief section line is drillable (it needs a record Id in the line)').not.toBeNull();
    }
    if (line) {
        return line;
    }
    await panel.ask(DRILL_QUESTION);
    await expect(panel.turns).toHaveCount(2, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
    const row = panel.turns.last().locator('button[data-id]').first();
    await expect(row, 'the answer has a drillable result row').toBeVisible();
    return row;
}

async function axeScan(page, testInfo, state) {
    const results = await new AxeBuilder({ page }).include('c-account-brief-panel').withTags(WCAG_TAGS).analyze();
    const violations = results.violations.map((v) => ({
        id: v.id,
        impact: v.impact,
        help: v.help,
        nodes: v.nodes.map((n) => ({ target: n.target, summary: n.failureSummary }))
    }));
    // Saved under test-results/ and attached to the report. Rule ids, targets and summaries only.
    const file = testInfo.outputPath('axe-' + state + '.json');
    fs.writeFileSync(file, JSON.stringify({ state, passes: results.passes.length, violations }, null, 2));
    await testInfo.attach('axe-' + state + '.json', { path: file, contentType: 'application/json' });
    // Proof the scan reached the panel's shadow tree rather than matching nothing.
    expect(results.passes.length, 'axe evaluated rules inside the panel').toBeGreaterThan(0);
    return violations;
}

test('1. Cmd/Ctrl-K before the utility was ever opened opens the panel and focuses the composer', async ({ page, panel }) => {
    await expect(panel.dialog).toBeHidden();
    // Pressed once: a retry would hide the defect this test exists to catch.
    await page.keyboard.press(await panel.hotkey());
    await expect(panel.dialog).toBeVisible();
    await expect(panel.composer).toBeFocused();
});

test('2. Esc from the composer and from a button minimizes and returns focus; Tab can leave the panel', async ({ page, panel }) => {
    const anchor = pageAnchor(page);

    await test.step('Esc from the composer', async () => {
        await anchor.focus();
        await expect(anchor).toBeFocused();
        await panel.open();
        await page.keyboard.press('Escape');
        await expect(panel.composer).toBeHidden();
        await panel.expectFocusStays(anchor, 'focus returned to the element focused before the hotkey');
    });

    await test.step('Esc from a button in the panel', async () => {
        await anchor.focus();
        await panel.open();
        await panel.briefButton.focus();
        await expect(panel.briefButton).toBeFocused();
        await page.keyboard.press('Escape');
        await expect(panel.composer).toBeHidden();
        await panel.expectFocusStays(anchor, 'focus returned to the element focused before the hotkey');
    });

    await test.step('Tab leaves the panel (no trap)', async () => {
        await anchor.focus();
        await panel.open();
        let left = false;
        for (let i = 0; i < 30 && !left; i += 1) {
            await page.keyboard.press('Tab');
            left = !(await panel.focusInPanel());
        }
        expect(left, 'focus left the panel within 30 Tabs').toBe(true);
    });
});

test('3. a brief renders with its headline and collapsed accordions, announced by the live region; the pinned bar leaves the conversation the room', async ({ panel }) => {
    await panel.open();
    await expect(panel.briefButton).toBeVisible();
    await panel.briefButton.click();
    await expect(panel.liveRegion).toHaveText('Loading brief for ' + ACCOUNT_NAME);
    await expect(panel.liveRegion).toHaveText(/^Brief ready: \S/, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden();

    const turn = panel.turns.last();
    // The summary card's heading, told apart from the accordion section headers by its test hook.
    const headline = panel.headline(turn);
    await expect(headline).toHaveCount(1);
    await expect(headline).toBeVisible();
    const headlineText = ((await headline.textContent()) || '').trim();
    expect(headlineText.length).toBeGreaterThan(0);
    await expect(panel.liveRegion).toHaveText('Brief ready: ' + headlineText);

    const headers = panel.sectionHeaders(turn);
    expect(await headers.count()).toBeGreaterThan(0);
    for (const header of await headers.all()) {
        await expect(header).toHaveAttribute('aria-expanded', 'false');
    }

    await test.step('the pinned bar is at most 80 CSS px and the scroll box at least 240 CSS px', async () => {
        // The brief reloads the account's earlier briefs: measure with that list rendered.
        await expect(panel.historyHeader).toBeAttached();
        await panel.settle();
        const box = await panel.dialog.boundingBox();
        const header = await panel.panelHeader.boundingBox();
        const body = await panel.body.boundingBox();
        expect(box && header && body, 'the panel, its header and the scroll box are rendered').toBeTruthy();
        if (!box || !header || !body) return;
        expect(Math.round(box.width)).toBe(340);
        expect(Math.round(box.height)).toBe(480);
        const bar = body.y - (header.y + header.height);
        expect(Math.round(bar), 'CSS px from the panel header to the top of the scroll box').toBeLessThanOrEqual(80);
        expect(Math.round(body.height), 'the scroll box height in CSS px').toBeGreaterThanOrEqual(240);
        // Brief and Ask the agent share the one row.
        const brief = await panel.briefButton.boundingBox();
        const agent = await panel.agentButton.boundingBox();
        expect(brief && agent, 'both bar buttons are rendered').toBeTruthy();
        if (!brief || !agent) return;
        const overlap = Math.min(brief.y + brief.height, agent.y + agent.height) - Math.max(brief.y, agent.y);
        expect(overlap, 'the two bar buttons are on one row').toBeGreaterThan(Math.min(brief.height, agent.height) / 2);
    });
});

test('4. after two answers the composer stays pinned in the 340x480 panel and the newest answer is in view', async ({ panel }) => {
    await panel.open();
    await panel.briefThisAccount();
    await panel.ask('How many contacts does this account have?');
    await expect(panel.turns).toHaveCount(2, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });

    const box = await panel.dialog.boundingBox();
    expect(box, 'utility panel box').not.toBeNull();
    if (!box) return;
    expect(Math.round(box.width)).toBe(340);
    expect(Math.round(box.height)).toBe(480);

    for (const control of [panel.composer, panel.send]) {
        await expect(control).toBeVisible();
        const c = await control.boundingBox();
        expect(c).not.toBeNull();
        if (!c) return;
        expect(c.y).toBeGreaterThanOrEqual(box.y);
        expect(c.y + c.height).toBeLessThanOrEqual(box.y + box.height + 1);
    }

    const scroll = await panel.body.evaluate((el) => ({ sh: el.scrollHeight, ch: el.clientHeight, top: el.scrollTop }));
    expect(scroll.sh, 'the body overflows, so it is the scroll box').toBeGreaterThan(scroll.ch);
    expect(scroll.top, 'the body scrolled to the newest answer').toBeGreaterThan(0);
    await expect(panel.turns.last()).toBeInViewport();
});

test('5. a second request sent before the first answers: only the second answer renders', async ({ panel }) => {
    const first = 'Which open opportunities does this account have?';
    await panel.open();

    let firstLanded = false;
    const firstReply = panel.apexResponse('explore').then((r) => {
        firstLanded = true;
        return r;
    });
    await panel.ask(first);
    await expect(panel.spinner).toBeVisible();
    await expect(panel.liveRegion).toHaveText('Loading answer');

    const secondReply = panel.apexResponse('resolve');
    await panel.ask(NO_SUCH_ACCOUNT);
    await secondReply;
    // Otherwise this run did not exercise a late reply (a test problem, not a panel defect).
    expect(firstLanded, 'the first reply was still in flight when the second landed').toBe(false);
    await expect(panel.turns).toHaveCount(1);
    await expect(panel.turns.first()).toContainText(NO_SUCH_ACCOUNT);
    await expect(panel.spinner).toBeHidden();

    // The first reply lands later and must be dropped: never rendered, spinner stays off.
    // The response's body must reach the page before the page can process (and drop) it.
    await (await firstReply).finished();
    await panel.settle();
    await expect(panel.turns).toHaveCount(1);
    await expect(panel.host).not.toContainText(first);
    await expect(panel.spinner).toBeHidden();
    await expect(panel.liveRegion).not.toHaveText('Answer ready');
});

test('6. typing enables Send without blur, and Enter sends', async ({ page, panel }) => {
    await panel.open();
    await expect(panel.send).toBeDisabled();
    await page.keyboard.type(NO_SUCH_ACCOUNT);
    await expect(panel.composer).toBeFocused();
    await expect(panel.send).toBeEnabled();

    await page.keyboard.press('Enter');
    await expect(panel.turns).toHaveCount(1, { timeout: 60_000 });
    await expect(panel.turns.first()).toContainText(NO_SUCH_ACCOUNT);
    await expect(panel.composer).toHaveValue('');
    await expect(panel.spinner).toBeHidden();
});

test('7. a drill opens the record view and a breadcrumb returns without navigating to #', async ({ page, panel }) => {
    await panel.open();
    const origin = await drillOrigin(panel);

    const urlBefore = page.url();
    const navigations = [];
    page.on('framenavigated', (f) => {
        if (f === page.mainFrame()) navigations.push(f.url());
    });

    await origin.click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    const heading = panel.host.locator('article').getByRole('heading', { level: 2 });
    await expect(heading).toBeVisible();
    await expect(heading).not.toHaveText('');
    await expect(heading).toBeFocused();
    await expect(panel.host.getByRole('button', { name: 'View record' })).toBeVisible();
    await expect(origin).toBeHidden();

    await panel.breadcrumbs.getByRole('link', { name: 'Conversation', exact: true }).click();
    await expect(panel.breadcrumbs).toBeHidden();
    await expect(origin).toBeVisible();
    await expect(origin).toBeFocused();
    expect(page.url()).toBe(urlBefore);
    expect(navigations.filter((u) => u.endsWith('#'))).toEqual([]);
});

test('8. axe finds no WCAG A/AA violations in the open panel: brief state and drill state', async ({ panel }, testInfo) => {
    await panel.open();
    await panel.briefThisAccount();
    const briefViolations = await axeScan(panel.page, testInfo, 'brief');

    // Spec 7 owns the section-drill check; here any drill reaches the state to scan.
    const origin = await drillOrigin(panel, { briefed: true, requireSectionDrill: false });
    await origin.click();
    await expect(panel.breadcrumbs).toBeVisible({ timeout: 60_000 });
    const drillViolations = await axeScan(panel.page, testInfo, 'drill');

    expect.soft(briefViolations, 'axe violations in the brief state').toEqual([]);
    expect.soft(drillViolations, 'axe violations in the drill state').toEqual([]);
});

test('9. Ask the agent answers in the panel, and a follow-up that needs the first turn reuses its agent session', async ({ panel }) => {
    // Two agent turns: about 15 s each in agent-probe (docs/research/panel-agent-1.md).
    await panel.open();
    await expect(panel.agentButton).toBeVisible();
    const before = await panel.turns.count();

    // Turn 1: about the open account. The panel sends the record as context on the first turn only.
    await panel.composer.fill(AGENT_QUESTION);
    let call = panel.apexCall('askAgent');
    await panel.agentButton.click();
    await expect(panel.liveRegion).toHaveText('Asking the agent');
    await expect(panel.spinner).toBeVisible();
    const first = await call;
    expect(first.state, 'askAgent returned').toBe('SUCCESS');
    expect(first.params.contextRecordId === panel.run.accountId, 'turn 1 sent the open account as context').toBe(true);
    expect(!first.params.sessionId, 'turn 1 started a new agent session').toBe(true);
    expect(!!first.value && first.value.failed === false && !!first.value.sessionId, 'turn 1 is a reply with a session').toBe(true);
    await expect(panel.liveRegion).toHaveText('Agent replied');
    await expect(panel.spinner).toBeHidden();
    await expect(panel.turns).toHaveCount(before + 1);
    // Pinned by index: last() would move to turn 2 once it renders.
    const turn1 = panel.turns.nth(before);
    await expect(turn1.locator('.abp-question')).toHaveText(AGENT_QUESTION);
    await expect(turn1.locator('[data-error="true"]')).toHaveCount(0);
    expect(squash(await turn1.locator('.abp-pre').textContent()) === squash(first.value.text), 'turn 1 shows the reply').toBe(true);
    expect(/deal|opportunit/i.test(first.value.text), 'turn 1 answers about deals').toBe(true);

    // Turn 2: names no account and carries no record, so only the first turn's session can answer it.
    await panel.composer.fill(AGENT_FOLLOWUP);
    call = panel.apexCall('askAgent');
    await panel.agentButton.click();
    await expect(panel.liveRegion).toHaveText('Asking the agent');
    const second = await call;
    expect(second.state, 'askAgent returned').toBe('SUCCESS');
    expect(second.params.sessionId === first.value.sessionId, "turn 2 sent turn 1's agent session").toBe(true);
    expect(!second.params.contextRecordId, 'turn 2 sent no record').toBe(true);
    expect(!!second.value && second.value.failed === false, 'turn 2 is a reply').toBe(true);
    expect(second.value.sessionId === first.value.sessionId, 'the agent kept the session').toBe(true);
    expect(/case/i.test(second.value.text), 'turn 2 answers about cases').toBe(true);
    expect(/which account|what account|specify (the|an) account/i.test(second.value.text), 'turn 2 did not ask which account').toBe(false);
    await expect(panel.liveRegion).toHaveText('Agent replied');
    await expect(panel.turns).toHaveCount(before + 2);
    const turn2 = panel.turns.nth(before + 1);
    await expect(turn2.locator('.abp-question')).toHaveText(AGENT_FOLLOWUP);
    await expect(turn2.locator('[data-error="true"]')).toHaveCount(0);
    expect(squash(await turn2.locator('.abp-pre').textContent()) === squash(second.value.text), 'turn 2 shows the reply').toBe(true);
    // Both replies stay on screen.
    await expect(turn1.locator('.abp-question')).toHaveText(AGENT_QUESTION);
    expect(squash(await turn1.locator('.abp-pre').textContent()) === squash(first.value.text), 'turn 1 still shows its reply').toBe(true);
});
