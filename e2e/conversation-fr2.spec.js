// @ts-check
/**
 * FE-22 in a real org: the sessions control (History), the scope chip and the answer cards, on the
 * record page of Edge Communications inside the Customer Summary app (see support/panel.js).
 *
 * Model calls per run: (1) 1 brief, (2) 0, (3) 1 question, so 2. A brief writes the account's
 * session row for the signed-in user (CustomerSummaryMemory: one row per user and account, kept
 * while the user is active), so (1) always has at least one conversation to reopen.
 */
const { test, expect, ANSWER_TIMEOUT } = require('./support/panel');
const { ACCOUNT_NAME } = require('./support/env');

const ORG_QUESTION = 'How many accounts are there?';

/** The History button, the sessions region under the bar and its rows. */
function sessionsOf(panel) {
    const toggle = panel.host.getByRole('button', { name: 'History', exact: true });
    const region = panel.host.locator('.abp-sessions');
    return { toggle, region, rows: region.locator('button.abp-session') };
}

/** The scope chip: a group named "Question scope" with its label and its switch. */
function scopeOf(panel) {
    const group = panel.host.getByRole('group', { name: 'Question scope', exact: true });
    return { group, label: group.locator('.abp-scope-label') };
}

/**
 * A promise for the parsed params of the next explore request. The body is read in memory only and
 * never logged or saved: it carries record Ids.
 */
function nextExploreParams(page) {
    const needle = '"classname":"CustomerSummaryPanelController","method":"explore"';
    return page
        .waitForRequest(
            (r) => {
                const body = r.postData();
                if (!body || !r.url().includes('/aura')) return false;
                try {
                    return decodeURIComponent(body.replace(/\+/g, ' ')).includes(needle);
                } catch (e) {
                    return false;
                }
            },
            { timeout: ANSWER_TIMEOUT }
        )
        .then((r) => {
            const message = new URLSearchParams(r.postData() || '').get('message') || '{}';
            const action = (JSON.parse(message).actions || []).find((a) => a.params && a.params.method === 'explore');
            return (action && action.params && action.params.params) || {};
        });
}

test('FR2 1. History lists the account’s conversations; New conversation starts clean; reopening one loads its turns', async ({ page, panel }) => {
    const { toggle, region, rows } = sessionsOf(panel);
    await panel.open();

    const brief = await test.step('a brief of the account renders as answer cards', async () => {
        const turn = await panel.briefThisAccount();
        await expect(panel.cards(turn).first()).toBeVisible();
        await expect(turn.locator('c-customer-summary-card article[data-type="summary"]')).toHaveCount(1);
        return turn;
    });
    const headline = ((await panel.headline(brief).textContent()) || '').trim();
    expect(headline.length, 'the summary card has a title').toBeGreaterThan(0);

    await test.step('History opens the list of this account’s conversations, newest first', async () => {
        await expect(toggle).toHaveAttribute('aria-expanded', 'false');
        await toggle.click();
        await expect(toggle).toHaveAttribute('aria-expanded', 'true');
        await expect(region.getByRole('heading', { name: 'Earlier conversations about ' + ACCOUNT_NAME, exact: true })).toBeVisible();
        await expect(rows.first()).toBeVisible({ timeout: 30_000 });
        // One Tab stop for the list: one row at tabindex 0.
        await expect(region.locator('button.abp-session[tabindex="0"]')).toHaveCount(1);
    });

    await test.step('New conversation clears the thread and closes the list', async () => {
        await region.getByRole('button', { name: 'New conversation', exact: true }).click();
        await expect(panel.turns).toHaveCount(0);
        await expect(region).toBeHidden();
        await expect(toggle).toHaveAttribute('aria-expanded', 'false');
    });

    await test.step('reopening the newest conversation loads its turns and returns to the composer', async () => {
        await toggle.click();
        await expect(rows.first()).toBeVisible({ timeout: 30_000 });
        await rows.first().click();
        await expect(region).toBeHidden({ timeout: 60_000 });
        await expect(panel.turns.first()).toBeVisible();
        expect(await panel.turns.count(), 'the reopened conversation has turns').toBeGreaterThan(0);
        // The brief just made is the newest turn of that conversation; memory keeps text, not cards.
        await expect(panel.turns.last()).toContainText(headline.slice(0, 24));
        await panel.expectFocused(panel.composer, 'the composer has focus after a reopen');
    });
    await expect(page.locator('body')).not.toContainText("Couldn't open that conversation");
});

test('FR2 2. the scope chip reads About the account and switches to Whole org and back, by keyboard', async ({ page, panel }) => {
    const { group, label } = scopeOf(panel);
    await panel.open();
    await expect(group).toBeVisible();
    await expect(label).toHaveText('About ' + ACCOUNT_NAME);

    await test.step('Shift+Tab from the composer reaches the switch; Enter asks the whole org', async () => {
        await panel.expectFocused(panel.composer, 'the composer has focus');
        await page.keyboard.press('Shift+Tab');
        const toOrg = group.getByRole('button', { name: 'Ask the whole org', exact: true });
        await panel.expectFocused(toOrg, 'the scope switch has focus');
        await page.keyboard.press('Enter');
        await expect(label).toHaveText('Whole org');
        await expect(panel.liveRegion).toHaveText('Questions now go to the whole org');
    });

    await test.step('the switch now asks about the account again', async () => {
        const toAccount = group.getByRole('button', { name: 'Ask about ' + ACCOUNT_NAME, exact: true });
        await expect(toAccount).toBeVisible();
        const box = await toAccount.boundingBox();
        expect(box && box.height >= 24 && box.width >= 24, 'the switch is at least 24 by 24 CSS px').toBe(true);
        await toAccount.press('Enter');
        await expect(label).toHaveText('About ' + ACCOUNT_NAME);
        await expect(panel.liveRegion).toHaveText('Questions now about ' + ACCOUNT_NAME);
    });
});

test('FR2 3. a whole-org question goes without the account and its answer shows a card', async ({ page, panel }) => {
    const { group, label } = scopeOf(panel);
    await panel.open();
    await group.getByRole('button', { name: 'Ask the whole org', exact: true }).click();
    await expect(label).toHaveText('Whole org');

    const params = nextExploreParams(page);
    await panel.ask(ORG_QUESTION);
    expect((await params).contextRecordId ?? null, 'a whole-org question sends no context record').toBeNull();

    await expect(panel.turns).toHaveCount(1, { timeout: ANSWER_TIMEOUT });
    await expect(panel.spinner).toBeHidden({ timeout: ANSWER_TIMEOUT });
    const answer = panel.turns.last();
    await expect(panel.cards(answer).first()).toBeVisible();
    // The answer's first card is its text, named "Answer" when it has no title. That no record Id
    // reaches a card's markup is checked by the Jest suite: the page cannot read a component's markup.
    const articles = answer.locator('c-customer-summary-card article');
    await expect(articles.first()).toBeVisible();
    expect(await articles.count(), 'the answer is drawn as cards').toBeGreaterThan(0);
    await expect(answer.getByRole('article', { name: 'Answer', exact: true }).first()).not.toHaveText('');
});
