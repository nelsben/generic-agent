// @ts-check
/**
 * fr2-action-draft.png (FE-14) and fr2-action-draft-rail.png (OPS-52): the whole 1440x900 window on the
 * Edge Communications record page with the conversation open, in the compact window and then in the
 * rail, on a "Create a follow-up" draft card: Subject filled, Due still marked
 * "Needed", and Confirm off until it is filled. No model call (the chip calls draftAction, which
 * parses no words). Nothing is written to the org: the run never clicks Confirm, and it Cancels the
 * draft after the still. No result still is taken, since a result needs a saved record.
 */
const { test, expect, still } = require('./kit');

const FULL = { x: 0, y: 0, width: 1440, height: 900 };
const CSS = { scale: /** @type {'css'} */ ('css') };

/** Drafts a follow-up from the chip, fills Subject, takes the still, then Cancels: Confirm is never clicked. */
async function draftThenCancel(page, panel, name, mouse) {
    const chip = panel.host.getByRole('group', { name: 'Quick actions', exact: true }).getByRole('button', { name: 'Create a follow-up', exact: true });
    let drafted = panel.apexResponse('draftAction', 60_000);
    await chip.click();
    await drafted;
    await panel.settle();
    const card = panel.turns.last().locator('c-customer-summary-card article[data-type="actionDraft"]');
    await expect(card).toHaveCount(1, { timeout: 60_000 });

    const subject = card.getByRole('textbox', { name: 'Subject', exact: true });
    drafted = panel.apexResponse('draftAction', 60_000);
    await subject.fill('Send the renewal quote');
    await subject.press('Tab');
    await drafted;
    await panel.settle();
    await expect(card.getByRole('textbox', { name: 'Subject', exact: true })).toHaveValue('Send the renewal quote');
    await expect(card.locator('.cs-field-missing')).toHaveCount(1);
    await expect(card.getByRole('button', { name: 'Confirm', exact: true })).toBeDisabled();

    // Focus moves (the chip, Subject, Tab) scroll the rail's dialog itself (161 px in OPS-52's run) and leave
    // the rail half off screen: put the dialog back, then scroll only the thread's own box to the question.
    if (await panel.rail.isVisible()) {
        await panel.rail.evaluate((el) => {
            el.scrollTop = 0;
        });
    }
    await panel.turns.last().locator('.abp-question').first().evaluate((el) => {
        let box = el.parentElement;
        while (box && !(box.scrollHeight > box.clientHeight + 1 && /auto|scroll/.test(getComputedStyle(box).overflowY))) {
            box = box.parentElement;
        }
        if (box) {
            box.scrollTop += el.getBoundingClientRect().top - box.getBoundingClientRect().top - 4;
        }
    });
    await page.waitForTimeout(400);
    await page.mouse.move(mouse[0], mouse[1]);
    await still(page, name, FULL, CSS);

    await card.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(panel.turns.last().locator('.abp-action-note')).toHaveText('Cancelled. Nothing was saved.');
}

test('fr2-action-draft.png', async ({ page, panel }) => {
    await panel.open();
    await draftThenCancel(page, panel, 'fr2-action-draft.png', [1400, 20]);
});

test('fr2-action-draft-rail.png', async ({ page, panel }) => {
    await panel.openRail();
    await panel.rail.evaluate((el) => Promise.all(el.getAnimations().map((a) => a.finished)));
    // History opens with the rail; fold it so the draft has the column.
    const history = panel.rail.getByRole('button', { name: 'History', exact: true });
    if ((await history.getAttribute('aria-expanded')) === 'true') {
        await history.click();
    }
    await draftThenCancel(page, panel, 'fr2-action-draft-rail.png', [400, 500]);
});
