// @ts-check
/**
 * FE-14 in a real org: a write-action draft card in the conversation, on the record page of Edge
 * Communications (see support/panel.js).
 *
 * The approval row "FR2: e2e and agent tests that create a record" is pending, so this spec stops at
 * the draft and Cancel. It never clicks Confirm, and it fails if a commitAction request is sent. The
 * confirm path (commitAction once, the result card, Undo, the error turn) is proven by the Jest
 * suites customerSummaryConversationActions and customerSummaryActionCards and by the Apex tests.
 *
 * Model calls per run: 0. The chip calls draftAction, which parses no words. Records created: 0, so
 * there is nothing to remove.
 */
const { test, expect } = require('./support/panel');
const { ACCOUNT_NAME } = require('./support/env');

const DRAFT_TIMEOUT = 60_000;

/** Counts the requests to one controller method. Bodies are matched in memory and never logged. */
function countRequests(page, method) {
    const needle = '"classname":"CustomerSummaryPanelController","method":"' + method + '"';
    const seen = { count: 0 };
    page.on('request', (r) => {
        const body = r.postData();
        if (!body || !r.url().includes('/aura')) return;
        try {
            if (decodeURIComponent(body.replace(/\+/g, ' ')).includes(needle)) seen.count += 1;
        } catch (e) {
            // not an Aura body
        }
    });
    return seen;
}

test('FR2 5. @smoke Create a follow-up drafts a task card with fields to fill; Confirm waits for them; Cancel saves nothing', async ({ page, panel }) => {
    const commits = countRequests(page, 'commitAction');
    await panel.open();

    const chip = panel.host.getByRole('group', { name: 'Quick actions', exact: true }).getByRole('button', { name: 'Create a follow-up', exact: true });
    const turn = await test.step('the chip asks for a draft and it shows in the turn', async () => {
        const drafted = panel.apexResponse('draftAction', DRAFT_TIMEOUT);
        await chip.click();
        await drafted;
        await panel.settle();
        const last = panel.turns.last();
        await expect(last.locator('.abp-question')).toHaveText('Create a follow-up');
        await expect(last.locator('c-customer-summary-card article[data-type="actionDraft"]')).toHaveCount(1, { timeout: DRAFT_TIMEOUT });
        return last;
    });
    const card = turn.locator('c-customer-summary-card article[data-type="actionDraft"]');
    const subject = card.getByRole('textbox', { name: 'Subject', exact: true });
    const due = card.getByRole('textbox', { name: 'Due', exact: true });
    const confirm = card.getByRole('button', { name: 'Confirm', exact: true });

    await test.step('the card names the action and the account; the empty required fields are marked and Confirm is off', async () => {
        await expect(card.locator('.cs-title-text')).toHaveText('Create a task');
        await expect(card.locator('[data-field="WhatId"]')).toContainText(ACCOUNT_NAME);
        await expect(card.locator('[data-field="WhatId"] input')).toHaveCount(0);
        await expect(subject).toBeVisible();
        await expect(subject).toHaveAttribute('aria-invalid', 'true');
        await expect(card.locator('.cs-field-missing')).toHaveCount(2);
        await expect(confirm).toBeDisabled();
        for (const name of ['Edit', 'Cancel']) {
            await expect(card.getByRole('button', { name, exact: true })).toBeEnabled();
        }
    });

    await test.step('filling Subject and Due re-drafts the card; Confirm turns on', async () => {
        let redraft = panel.apexResponse('draftAction', DRAFT_TIMEOUT);
        await subject.fill('Send the renewal quote');
        await subject.press('Tab');
        await redraft;
        await panel.settle();
        await expect(card.locator('.cs-field-missing')).toHaveCount(1);
        await expect(confirm).toBeDisabled();

        redraft = panel.apexResponse('draftAction', DRAFT_TIMEOUT);
        await due.fill('next Tuesday');
        await due.press('Tab');
        await redraft;
        await panel.settle();
        await expect(card.locator('.cs-field-missing')).toHaveCount(0);
        await expect(card.getByRole('textbox', { name: 'Subject', exact: true })).toHaveValue('Send the renewal quote');
        await expect(confirm).toBeEnabled();
    });

    await test.step('Cancel closes the card with nothing saved', async () => {
        await card.getByRole('button', { name: 'Cancel', exact: true }).click();
        await expect(turn.locator('.abp-action-note')).toHaveText('Cancelled. Nothing was saved.');
        await expect(card.locator('input')).toHaveCount(0);
        await expect(card.locator('.cs-controls')).toHaveCount(0);
        expect(commits.count, 'no commitAction request was sent').toBe(0);
    });
});
