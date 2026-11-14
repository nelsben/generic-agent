/**
 * FE-14: the write actions in the conversation. A typed or spoken request that names an action, or
 * an action chip, drafts it (draftFromText or draftAction) and shows BE-39's actionDraft card in the
 * agent turn; nothing is written before Confirm. Confirm calls commitAction once and shows the
 * actionResult card, or the plain-English error turn. FE-12's and FE-22's tests stay in their files.
 */
import { createElement } from 'lwc';
import CustomerSummaryConversation from 'c/customerSummaryConversation';
import resolve from '@salesforce/apex/CustomerSummaryPanelController.resolve';
import explore from '@salesforce/apex/CustomerSummaryPanelController.explore';
import history from '@salesforce/apex/CustomerSummaryPanelController.history';
import drill from '@salesforce/apex/CustomerSummaryPanelController.drill';
import sources from '@salesforce/apex/CustomerSummaryPanelController.sources';
import draftAction from '@salesforce/apex/CustomerSummaryPanelController.draftAction';
import draftFromText from '@salesforce/apex/CustomerSummaryPanelController.draftFromText';
import commitAction from '@salesforce/apex/CustomerSummaryPanelController.commitAction';
import undoAction from '@salesforce/apex/CustomerSummaryPanelController.undoAction';

const fs = require('fs');
const path = require('path');

const mockNavigate = jest.fn();
jest.mock('lightning/navigation', () => {
    const Navigate = Symbol('Navigate');
    const NavigationMixin = (Base) =>
        class extends Base {
            [Navigate](ref) {
                mockNavigate(ref);
            }
        };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin };
});

jest.mock('@salesforce/apex/CustomerSummaryPanelController.resolve', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.getBrief', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.explore', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.drill', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.history', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.draftAction', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.draftFromText', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.commitAction', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.undoAction', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryHistory.listSessions', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryHistory.getSession', () => ({ default: jest.fn() }), { virtual: true });
jest.mock(
    '@salesforce/apex/CustomerSummaryPanelController.sources',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const SOURCE_JS = fs.readFileSync(path.join(__dirname, '..', 'customerSummaryConversation.js'), 'utf8');

const ACME = '001000000000001AAA';
const MARIA = '003000000000001AAA';
const JORDAN = '003000000000004AAA';
const TASK = '00T000000000001AAA';
const DEAL = '006000000000001AAA';
const ERROR_TEXT = "I couldn't finish that right now. Try again in a minute.";
const CONTROLS = [
    { key: 'confirm', label: 'Confirm', kind: 'primary' },
    { key: 'edit', label: 'Edit', kind: 'neutral' },
    { key: 'cancel', label: 'Cancel', kind: 'link' }
];

/** A create_task draft as BE-27 returns it, its actionDraft card included. */
function taskDraft({ due, contact } = {}) {
    const ready = !!due && contact !== 'choose';
    const input = { subject: 'Follow up on pricing' };
    if (due) {
        input.dueDate = due;
    }
    if (contact === 'choose') {
        input.contact = 'Jordan';
    } else {
        input.contactId = MARIA;
    }
    const contactField =
        contact === 'choose'
            ? { key: 'WhoId', label: 'Contact', value: 'Jordan', state: 'choose', choices: ['c1', 'c4'] }
            : { key: 'WhoId', label: 'Contact', value: 'Maria Lopez', ref: 'c1' };
    const refs =
        contact === 'choose'
            ? [
                  { key: 'c1', recordId: MARIA, objectName: 'Contact', label: 'Jordan Lee' },
                  { key: 'c4', recordId: JORDAN, objectName: 'Contact', label: 'Jordan Park' }
              ]
            : [{ key: 'c1', recordId: MARIA, objectName: 'Contact', label: 'Maria Lopez' }];
    return {
        status: ready ? 'READY' : 'NEEDS_INPUT',
        action: 'create_task',
        actionLabel: 'Create a task',
        objectName: 'Task',
        objectLabel: 'Task',
        mode: 'create',
        accountId: ACME,
        accountName: 'Acme',
        targetLabel: 'Acme',
        inputJson: JSON.stringify(input),
        fields: [],
        missing: due ? [] : ['ActivityDate'],
        warnings: [],
        message: null,
        cards: [
            {
                type: 'actionDraft',
                version: 1,
                key: 'drf',
                title: 'Create a task',
                meta: 'Task · create',
                status: ready ? 'READY' : 'NEEDS_INPUT',
                text: 'Create a task · Task · create',
                body: [],
                fields: [
                    { key: 'Subject', label: 'Subject', value: 'Follow up on pricing' },
                    due ? { key: 'ActivityDate', label: 'Due', value: due } : { key: 'ActivityDate', label: 'Due', value: '', state: 'missing' },
                    contactField,
                    { key: 'WhatId', label: 'Related to', value: 'Acme', ref: 'a1' }
                ],
                items: [],
                controls: CONTROLS,
                refs: refs.concat([{ key: 'a1', recordId: ACME, objectName: 'Account', label: 'Acme' }])
            }
        ]
    };
}

function taskResult(extra) {
    return {
        status: 'OK',
        action: 'create_task',
        title: 'Task created',
        objectName: 'Task',
        objectLabel: 'Task',
        recordId: TASK,
        label: 'Follow up on pricing',
        linkPath: '/lightning/r/Task/' + TASK + '/view',
        undoToken: null,
        message: 'Saved as you, with your access.',
        fields: [],
        cards: [
            {
                type: 'actionResult',
                version: 1,
                key: 'res',
                title: 'Task created',
                meta: 'Task',
                status: 'OK',
                text: 'Task created · Task\nSubject: Follow up on pricing\nDue: 2026-11-17\nSaved as you, with your access.',
                body: [{ kind: 'p', runs: [{ text: 'Saved as you, with your access.' }] }],
                fields: [
                    { key: 'Subject', label: 'Subject', value: 'Follow up on pricing', ref: 't9' },
                    { key: 'ActivityDate', label: 'Due', value: '2026-11-17' }
                ],
                controls: [{ key: 'open', label: 'Open task', kind: 'primary' }],
                refs: [{ key: 't9', recordId: TASK, objectName: 'Task', label: 'Follow up on pricing' }]
            }
        ],
        ...(extra || {})
    };
}

function updateResult() {
    const r = taskResult({ action: 'update_opportunity', title: 'Opportunity updated', objectName: 'Opportunity', objectLabel: 'Opportunity', recordId: DEAL, label: 'Edge SLA', undoToken: 'undo-token-1' });
    r.cards = [
        {
            ...r.cards[0],
            title: 'Opportunity updated',
            meta: 'Opportunity',
            fields: [{ key: 'StageName', label: 'Stage', value: 'Negotiation', ref: 'o1' }],
            controls: [
                { key: 'open', label: 'Open opportunity', kind: 'primary' },
                { key: 'undo', label: 'Undo', kind: 'neutral' }
            ],
            refs: [{ key: 'o1', recordId: DEAL, objectName: 'Opportunity', label: 'Edge SLA' }]
        }
    ];
    return r;
}

async function flush() {
    for (let i = 0; i < 5; i++) {
        // eslint-disable-next-line no-await-in-loop, @lwc/lwc/no-async-operation
        await new Promise((r) => setTimeout(r, 0));
    }
}

function deferred() {
    let res;
    let rej;
    const promise = new Promise((a, b) => {
        res = a;
        rej = b;
    });
    return { promise, resolve: res, reject: rej };
}

async function mountOnAccount() {
    resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme', cards: '[]' });
    const el = createElement('c-customer-summary-conversation', { is: CustomerSummaryConversation });
    Object.assign(el, { recordId: ACME, objectApiName: 'Account', brand: { agentName: 'Northwind Assist' } });
    document.body.appendChild(el);
    sources.emit([]);
    await flush();
    return el;
}

const $ = (el, sel) => el.shadowRoot.querySelector(sel);
const $$ = (el, sel) => Array.from(el.shadowRoot.querySelectorAll(sel));
const chip = (el, label) => $$(el, '.abp-quick').find((b) => b.textContent === label);
const cardEls = (el) => $$(el, 'c-customer-summary-card');
const lastCard = (el) => cardEls(el)[cardEls(el).length - 1];
const inCard = (card, sel) => card.shadowRoot.querySelector(sel);
const control = (card, label) => Array.from(card.shadowRoot.querySelectorAll('.cs-controls button')).find((b) => b.textContent === label);

async function ask(el, text) {
    const box = $(el, 'textarea.abp-composer');
    box.value = text;
    box.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
    await flush();
    box.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, composed: true, cancelable: true }));
    await flush();
}

async function edit(card, fieldKey, value) {
    const box = inCard(card, 'input[data-field="' + fieldKey + '"]');
    box.value = value;
    box.dispatchEvent(new CustomEvent('change', { bubbles: true }));
    await flush();
}

async function draftOnScreen(draft) {
    const el = await mountOnAccount();
    draftAction.mockResolvedValueOnce(draft);
    chip(el, 'Create a follow-up').click();
    await flush();
    return el;
}

describe('c-customer-summary-conversation FE-14 write actions', () => {
    beforeEach(() => {
        Element.prototype.scrollIntoView = jest.fn();
        history.mockResolvedValue([]);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.useRealTimers();
        jest.clearAllMocks();
        [resolve, explore, drill, history, draftAction, draftFromText, commitAction, undoAction].forEach((m) => m.mockReset());
    });

    it('documents what FE-14 adds to the interface at the top of the file', () => {
        const header = SOURCE_JS.slice(0, SOURCE_JS.indexOf('*/'));
        ['FE-14', 'draftFromText', 'draftAction', 'commitAction', 'undoAction', 'cardedit', 'action-mode'].forEach((part) => expect(header).toContain(part));
    });

    describe('what leads to a draft', () => {
        it('on an account the chips offer Create a follow-up and Log a call', async () => {
            const el = await mountOnAccount();
            expect($$(el, '.abp-quick').map((b) => b.textContent)).toEqual(['Summarize', 'Open deals', 'Recent activity', 'Create a follow-up', 'Log a call']);
        });

        it('the follow-up chip calls draftAction and shows the draft card inside the agent turn; nothing is written', async () => {
            const el = await draftOnScreen(taskDraft());
            expect(draftAction).toHaveBeenCalledTimes(1);
            expect(draftAction).toHaveBeenCalledWith({ actionType: 'create_task', accountId: ACME, inputJson: '{}' });
            const turn = $(el, '.abp-turn');
            expect(turn.querySelector('.abp-question').textContent).toBe('Create a follow-up');
            const reply = turn.querySelector('.abp-reply');
            expect(reply.dataset.kind).toBe('actionDraft');
            const card = reply.querySelector('c-customer-summary-card');
            expect(card.actionMode).toBe('open');
            expect(inCard(card, 'article').dataset.type).toBe('actionDraft');
            expect(inCard(card, '.cs-title-text').textContent).toBe('Create a task');
            expect(commitAction).not.toHaveBeenCalled();
            expect(explore).not.toHaveBeenCalled();
        });

        it('the call chip drafts log_call', async () => {
            const el = await mountOnAccount();
            draftAction.mockResolvedValueOnce(taskDraft());
            chip(el, 'Log a call').click();
            await flush();
            expect(draftAction).toHaveBeenCalledWith({ actionType: 'log_call', accountId: ACME, inputJson: '{}' });
        });

        it('a typed request that names an action calls draftFromText, not the explorer', async () => {
            const el = await mountOnAccount();
            draftFromText.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            await ask(el, 'create a follow-up for next Tuesday');
            expect(draftFromText).toHaveBeenCalledWith({ accountId: ACME, text: 'create a follow-up for next Tuesday' });
            expect(explore).not.toHaveBeenCalled();
            expect($(el, '.abp-reply').dataset.kind).toBe('actionDraft');
            expect(lastCard(el).actionMode).toBe('open');
        });

        it('a spoken request fills the composer, and Send drafts it the same way', async () => {
            const el = await mountOnAccount();
            draftFromText.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            const mic = $(el, 'c-customer-summary-voice-input');
            mic.dispatchEvent(new CustomEvent('transcriptfinal', { detail: { transcript: 'log a call with Maria' } }));
            await flush();
            $(el, '.abp-send').click();
            await flush();
            expect(draftFromText).toHaveBeenCalledWith({ accountId: ACME, text: 'log a call with Maria' });
        });

        it('NOT_AN_ACTION goes down the normal ask path', async () => {
            const el = await mountOnAccount();
            draftFromText.mockResolvedValueOnce({ status: 'NOT_AN_ACTION', message: 'That reads as a question.', cards: [] });
            explore.mockResolvedValueOnce({ status: 'OK', answer: 'Two follow-ups are open.', resultSets: [], trail: [], followups: [], cards: [] });
            await ask(el, 'make sense of the open follow-ups');
            expect(explore).toHaveBeenCalledWith(expect.objectContaining({ question: 'make sense of the open follow-ups', contextRecordId: ACME }));
            expect($(el, '.abp-reply').dataset.kind).toBe('explore');
            expect(cardEls(el)).toHaveLength(0);
        });

        it('a question is asked as before, with no draft call', async () => {
            const el = await mountOnAccount();
            explore.mockResolvedValueOnce({ status: 'OK', answer: 'Pat owns it.', resultSets: [], trail: [], followups: [], cards: [] });
            await ask(el, 'Who owns the renewal?');
            expect(draftFromText).not.toHaveBeenCalled();
            expect(explore).toHaveBeenCalledTimes(1);
        });

        it('a request that names an action, with no account in view, is asked as a question', async () => {
            const el = createElement('c-customer-summary-conversation', { is: CustomerSummaryConversation });
            document.body.appendChild(el);
            sources.emit([]);
            await flush();
            explore.mockResolvedValueOnce({ status: 'OK', answer: 'Which account?', resultSets: [], trail: [], followups: [], cards: [] });
            await ask(el, 'create a follow-up for next Tuesday');
            expect(draftFromText).not.toHaveBeenCalled();
            expect(explore).toHaveBeenCalledTimes(1);
        });

        it('a draft that could not be made is the error turn', async () => {
            const el = await mountOnAccount();
            draftFromText.mockResolvedValueOnce({ status: 'ERROR', message: "I couldn't draft that right now. Try again, or pick the action from the list.", cards: [] });
            await ask(el, 'create a follow-up for next Tuesday');
            expect($(el, '.abp-reply').className).toContain('abp-reply-error');
            expect($(el, '.abp-reply .abp-agent-text').textContent).toBe("I couldn't draft that right now. Try again, or pick the action from the list.");
        });
    });

    describe('editing the draft', () => {
        it('an edited field drafts again with the new words, and the card shows the new draft', async () => {
            const el = await draftOnScreen(taskDraft());
            draftAction.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            await edit(lastCard(el), 'ActivityDate', 'next Tuesday');
            expect(draftAction).toHaveBeenCalledTimes(2);
            const args = draftAction.mock.calls[1][0];
            expect(args.actionType).toBe('create_task');
            expect(args.accountId).toBe(ACME);
            expect(JSON.parse(args.inputJson)).toEqual({ subject: 'Follow up on pricing', contactId: MARIA, dueDate: 'next Tuesday' });
            expect(cardEls(el)).toHaveLength(1);
            expect(inCard(lastCard(el), 'input[data-field="ActivityDate"]').value).toBe('2026-11-17');
            expect(control(lastCard(el), 'Confirm').disabled).toBe(false);
            expect(commitAction).not.toHaveBeenCalled();
        });

        it('new words for the contact drop the contact it had; a choice sets the contact by Id', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17', contact: 'choose' }));
            draftAction.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            lastCard(el).dispatchEvent(new CustomEvent('cardchoose', { detail: { cardKey: 'drf', fieldKey: 'WhoId', ref: 'c4', recordId: JORDAN }, bubbles: true, composed: true }));
            await flush();
            expect(JSON.parse(draftAction.mock.calls[1][0].inputJson)).toEqual({ subject: 'Follow up on pricing', dueDate: '2026-11-17', contactId: JORDAN });

            draftAction.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            await edit(lastCard(el), 'WhoId', 'Maria');
            const input = JSON.parse(draftAction.mock.calls[2][0].inputJson);
            expect(input.contact).toBe('Maria');
            expect(input.contactId).toBeUndefined();
        });

        it('a missing field keeps Confirm disabled, and a Confirm on an unready draft writes nothing', async () => {
            const el = await draftOnScreen(taskDraft());
            const card = lastCard(el);
            expect(inCard(card, '.cs-field-missing')).not.toBeNull();
            expect(control(card, 'Confirm').disabled).toBe(true);
            card.dispatchEvent(new CustomEvent('cardaction', { detail: { cardKey: 'drf', control: 'confirm' }, bubbles: true, composed: true }));
            await flush();
            expect(commitAction).not.toHaveBeenCalled();
        });

        it('while a new draft is on its way, Confirm is disabled', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            const later = deferred();
            draftAction.mockReturnValueOnce(later.promise);
            await edit(lastCard(el), 'Subject', 'Call about pricing');
            expect(lastCard(el).actionMode).toBe('busy');
            control(lastCard(el), 'Confirm').click();
            await flush();
            expect(commitAction).not.toHaveBeenCalled();
            later.resolve(taskDraft({ due: '2026-11-17' }));
            await flush();
            expect(lastCard(el).actionMode).toBe('open');
        });

        it('a new draft that fails keeps the last draft and says so', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            draftAction.mockRejectedValueOnce({ body: { message: 'boom' } });
            await edit(lastCard(el), 'Subject', 'Call about pricing');
            expect(lastCard(el).actionMode).toBe('open');
            expect($(el, '.abp-action-note').textContent).toBe(ERROR_TEXT);
        });
    });

    describe('Cancel', () => {
        it('closes the draft, writes nothing and says so', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            control(lastCard(el), 'Cancel').click();
            await flush();
            expect(lastCard(el).actionMode).toBe('closed');
            expect(control(lastCard(el), 'Confirm')).toBeUndefined();
            expect($(el, '.abp-action-note').textContent).toBe('Cancelled. Nothing was saved.');
            expect(commitAction).not.toHaveBeenCalled();
        });
    });

    describe('Confirm', () => {
        it('calls commitAction once with the draft, the button disabled while it runs, then shows the result card', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            const later = deferred();
            commitAction.mockReturnValueOnce(later.promise);
            control(lastCard(el), 'Confirm').click();
            await flush();
            expect(lastCard(el).actionMode).toBe('busy');
            expect(control(lastCard(el), 'Confirm').disabled).toBe(true);
            lastCard(el).dispatchEvent(new CustomEvent('cardaction', { detail: { cardKey: 'drf', control: 'confirm' }, bubbles: true, composed: true }));
            await flush();
            expect(commitAction).toHaveBeenCalledTimes(1);
            const sent = JSON.parse(commitAction.mock.calls[0][0].draftJson);
            expect(sent).toEqual({ action: 'create_task', accountId: ACME, inputJson: taskDraft({ due: '2026-11-17' }).inputJson });

            later.resolve(taskResult());
            await flush();
            const turns = $$(el, '.abp-turn');
            expect(turns).toHaveLength(2);
            expect(turns[0].querySelector('c-customer-summary-card').actionMode).toBe('closed');
            expect(turns[1].querySelector('.abp-question').textContent).toBe('Confirm');
            const result = turns[1].querySelector('c-customer-summary-card');
            expect(turns[1].querySelector('.abp-reply').dataset.kind).toBe('actionResult');
            expect(inCard(result, '.cs-title-text').textContent).toBe('Task created');
            expect(inCard(result, '.cs-field button.cs-link').textContent).toBe('Follow up on pricing');
        });

        it('the result links to the record: the link and Open go to its page', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            commitAction.mockResolvedValueOnce(taskResult());
            control(lastCard(el), 'Confirm').click();
            await flush();
            const result = lastCard(el);
            control(result, 'Open task').click();
            inCard(result, '.cs-field button.cs-link').click();
            await flush();
            expect(mockNavigate).toHaveBeenCalledTimes(2);
            mockNavigate.mock.calls.forEach((c) =>
                expect(c[0]).toEqual({ type: 'standard__recordPage', attributes: { recordId: TASK, objectApiName: 'Task', actionName: 'view' } })
            );
            expect(drill).not.toHaveBeenCalled();
        });

        it('a refusal shows the plain-English error turn and leaves the draft to fix or cancel', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            commitAction.mockResolvedValueOnce({ status: 'REFUSED', title: 'Not saved', message: "Nothing was saved. You can't create tasks with your access.", cards: [] });
            control(lastCard(el), 'Confirm').click();
            await flush();
            const turns = $$(el, '.abp-turn');
            expect(turns).toHaveLength(2);
            expect(turns[1].querySelector('.abp-reply').className).toContain('abp-reply-error');
            expect(turns[1].querySelector('.abp-agent-text').textContent).toBe("Nothing was saved. You can't create tasks with your access.");
            expect(turns[0].querySelector('c-customer-summary-card').actionMode).toBe('open');
        });

        it('a failed call shows the fixed error line, never the raw text', async () => {
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            commitAction.mockRejectedValueOnce({ body: { message: 'System.DmlException: raw' } });
            control(lastCard(el), 'Confirm').click();
            await flush();
            expect($$(el, '.abp-turn')[1].querySelector('.abp-agent-text').textContent).toBe(ERROR_TEXT);
            expect(el.shadowRoot.textContent).not.toContain('DmlException');
        });
    });

    describe('Undo', () => {
        it('an update offers Undo for 15 seconds; Undo calls undoAction with its token', async () => {
            jest.useFakeTimers({ doNotFake: ['setTimeout', 'nextTick', 'setImmediate', 'queueMicrotask'] });
            const el = await draftOnScreen(taskDraft({ due: '2026-11-17' }));
            commitAction.mockResolvedValueOnce(updateResult());
            control(lastCard(el), 'Confirm').click();
            await flush();
            expect(control(lastCard(el), 'Undo')).toBeTruthy();
            undoAction.mockResolvedValueOnce(taskResult({ title: 'Change undone', undoToken: null }));
            control(lastCard(el), 'Undo').click();
            await flush();
            expect(undoAction).toHaveBeenCalledWith({ undoToken: 'undo-token-1' });
            expect($$(el, '.abp-turn')).toHaveLength(3);
        });

        it('Undo is gone after 15 seconds', async () => {
            const realSetTimeout = setTimeout;
            jest.useFakeTimers({ doNotFake: ['nextTick', 'setImmediate', 'queueMicrotask'] });
            const tick = () => new Promise((r) => jest.requireActual('timers').setImmediate(r));
            const el = await (async () => {
                resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme', cards: '[]' });
                const host = createElement('c-customer-summary-conversation', { is: CustomerSummaryConversation });
                Object.assign(host, { recordId: ACME, objectApiName: 'Account' });
                document.body.appendChild(host);
                for (let i = 0; i < 5; i++) {
                    // eslint-disable-next-line no-await-in-loop
                    await tick();
                }
                return host;
            })();
            draftAction.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            chip(el, 'Create a follow-up').click();
            for (let i = 0; i < 5; i++) {
                // eslint-disable-next-line no-await-in-loop
                await tick();
            }
            commitAction.mockResolvedValueOnce(updateResult());
            control(lastCard(el), 'Confirm').click();
            for (let i = 0; i < 5; i++) {
                // eslint-disable-next-line no-await-in-loop
                await tick();
            }
            expect(control(lastCard(el), 'Undo')).toBeTruthy();
            jest.advanceTimersByTime(15000);
            for (let i = 0; i < 5; i++) {
                // eslint-disable-next-line no-await-in-loop
                await tick();
            }
            expect(control(lastCard(el), 'Undo')).toBeUndefined();
            expect(control(lastCard(el), 'Open opportunity')).toBeTruthy();
            expect(realSetTimeout).toBeDefined();
        });
    });

    describe('accessibility', () => {
        it('a draft and a result in the thread have no violations', async () => {
            const el = await draftOnScreen(taskDraft());
            await expect(el).toBeAccessible();
            draftAction.mockResolvedValueOnce(taskDraft({ due: '2026-11-17' }));
            await edit(lastCard(el), 'ActivityDate', '2026-11-17');
            commitAction.mockResolvedValueOnce(taskResult());
            control(lastCard(el), 'Confirm').click();
            await flush();
            await expect(el).toBeAccessible();
        });
    });
});
