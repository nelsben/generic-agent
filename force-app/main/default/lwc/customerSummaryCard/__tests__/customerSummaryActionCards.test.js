/**
 * FE-14: the action draft and action result cards (BE-39's actionDraft and actionResult types, as
 * BE-27 fills them), drawn by c-customer-summary-card when its host sets action-mode. Without
 * action-mode the card is as FE-22 built it (customerSummaryCard.test.js, unchanged): the action
 * types show their own text.
 */
import { createElement } from 'lwc';
import CustomerSummaryCard from 'c/customerSummaryCard';
import { viewOf } from '../cardContract';
import { FIXTURES } from './fixtures';

const flush = () => Promise.resolve();

/** A create_task draft as BE-27 builds it: the subject and the contact resolved, the due date missing. */
const NEEDS_DRAFT = {
    type: 'actionDraft',
    version: 1,
    key: 'drf',
    title: 'Create a task',
    meta: 'Task · create',
    status: 'NEEDS_INPUT',
    text: 'Create a task · Task · create\nSubject: Follow up on pricing\nDue: (needed)\nContact: Maria Lopez\nRelated to: Acme\nPriority: Normal\nNote: Two Marias work here; this is the one on the account.\nOptions: Confirm, Edit, Cancel',
    body: [],
    fields: [
        { key: 'Subject', label: 'Subject', value: 'Follow up on pricing' },
        { key: 'ActivityDate', label: 'Due', value: '', state: 'missing' },
        { key: 'WhoId', label: 'Contact', value: 'Maria Lopez', ref: 'c1' },
        { key: 'WhatId', label: 'Related to', value: 'Acme', ref: 'a1' },
        { key: 'Priority', label: 'Priority', value: 'Normal' }
    ],
    items: [{ label: 'Two Marias work here; this is the one on the account.' }],
    controls: [
        { key: 'confirm', label: 'Confirm', kind: 'primary' },
        { key: 'edit', label: 'Edit', kind: 'neutral' },
        { key: 'cancel', label: 'Cancel', kind: 'link' }
    ],
    refs: [
        { key: 'c1', recordId: 'record-id:c1', objectName: 'Contact', label: 'Maria Lopez' },
        { key: 'a1', recordId: 'record-id:a1', objectName: 'Account', label: 'Acme' }
    ]
};

const READY_DRAFT = {
    ...NEEDS_DRAFT,
    status: 'READY',
    text: NEEDS_DRAFT.text.replace('Due: (needed)', 'Due: 2026-11-17'),
    fields: NEEDS_DRAFT.fields.map((f) => (f.key === 'ActivityDate' ? { key: 'ActivityDate', label: 'Due', value: '2026-11-17' } : f))
};

/** An update_opportunity draft: the change shows its value before. */
const UPDATE_DRAFT = {
    type: 'actionDraft',
    version: 1,
    key: 'drf',
    title: 'Update an opportunity',
    meta: 'Opportunity · update',
    status: 'READY',
    text: 'Update an opportunity · Opportunity · update\nOpportunity: Edge SLA\nStage: Negotiation (was Qualification)\nOptions: Confirm, Edit, Cancel',
    body: [],
    fields: [
        { key: 'Id', label: 'Opportunity', value: 'Edge SLA', ref: 'o1' },
        { key: 'StageName', label: 'Stage', value: 'Negotiation (was Qualification)' }
    ],
    items: [],
    controls: NEEDS_DRAFT.controls,
    refs: [{ key: 'o1', recordId: 'record-id:o1', objectName: 'Opportunity', label: 'Edge SLA' }]
};

const RESULT = {
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
    refs: [{ key: 't9', recordId: 'record-id:t9', objectName: 'Task', label: 'Follow up on pricing' }]
};

function mount(card, mode, density = 'compact') {
    const el = createElement('c-customer-summary-card', { is: CustomerSummaryCard });
    el.density = density;
    el.actionMode = mode;
    el.card = card;
    document.body.appendChild(el);
    return el;
}

const q = (el, sel) => el.shadowRoot.querySelector(sel);
const qa = (el, sel) => Array.from(el.shadowRoot.querySelectorAll(sel));
const button = (el, label) => qa(el, '.cs-controls button').find((b) => b.textContent === label);
const input = (el, key) => q(el, 'input[data-field="' + key + '"]');

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
});

describe('the contract with actions drawn', () => {
    test('viewOf draws the action types only when asked; the fallback rule still holds', () => {
        expect(viewOf(NEEDS_DRAFT, 'compact').isFallback).toBe(true);
        const v = viewOf(NEEDS_DRAFT, 'compact', { actions: true });
        expect(v.isFallback).toBe(false);
        expect(v.family).toBe('fields');
        expect(viewOf({ ...NEEDS_DRAFT, version: 2 }, 'compact', { actions: true }).reason).toBe('unknown-version');
        expect(viewOf({ ...NEEDS_DRAFT, fields: [null] }, 'compact', { actions: true }).reason).toBe('render-error');
    });

    test('without action-mode the card stays as FE-22 drew it: the action text', () => {
        const el = mount(NEEDS_DRAFT, '');
        expect(q(el, '.cs-fallback')).not.toBeNull();
        expect(q(el, 'input')).toBeNull();
    });
});

describe('the draft card', () => {
    test('shows the action, the account, each field with its label and an editable value, the warning, and Confirm, Edit and Cancel', () => {
        const el = mount(READY_DRAFT, 'open');
        expect(q(el, 'article').dataset.type).toBe('actionDraft');
        expect(q(el, '.cs-title-text').textContent).toBe('Create a task');
        expect(q(el, '.cs-meta').textContent).toBe('Task · create');
        expect(qa(el, '.cs-dt').map((d) => d.textContent)).toEqual(['Subject', 'Due', 'Contact', 'Related to', 'Priority']);
        expect(input(el, 'Subject').value).toBe('Follow up on pricing');
        expect(input(el, 'ActivityDate').value).toBe('2026-11-17');
        expect(input(el, 'WhoId').value).toBe('Maria Lopez');
        // The account the record goes on is shown, not edited.
        expect(input(el, 'WhatId')).toBeNull();
        expect(q(el, '.cs-field[data-field="WhatId"]').textContent).toContain('Acme');
        expect(qa(el, '.cs-notes li').map((n) => n.textContent)).toEqual(['Two Marias work here; this is the one on the account.']);
        expect(qa(el, '.cs-controls button').map((b) => b.textContent)).toEqual(['Confirm', 'Edit', 'Cancel']);
        expect(button(el, 'Confirm').disabled).toBe(false);
        // Each input is named by its field's label.
        const due = input(el, 'ActivityDate');
        const label = qa(el, 'label').find((l) => l.textContent === 'Due');
        expect(label).toBeTruthy();
        expect(label.getAttribute('for')).toBe(due.getAttribute('id'));
    });

    test('a missing field is highlighted and Confirm stays disabled until it is filled', () => {
        const el = mount(NEEDS_DRAFT, 'open');
        const due = input(el, 'ActivityDate');
        expect(due.value).toBe('');
        expect(due.getAttribute('aria-invalid')).toBe('true');
        expect(due.required).toBe(true);
        expect(q(el, '.cs-field[data-field="ActivityDate"]').className).toContain('cs-field-missing');
        expect(q(el, '.cs-field[data-field="ActivityDate"]').textContent).toContain('Needed');
        expect(button(el, 'Confirm').disabled).toBe(true);
        expect(button(el, 'Cancel').disabled).toBe(false);
    });

    test('editing a field fires cardedit with the field and the new value', () => {
        const el = mount(NEEDS_DRAFT, 'open');
        const edit = jest.fn();
        document.body.addEventListener('cardedit', edit);
        const due = input(el, 'ActivityDate');
        due.value = 'next Tuesday';
        due.dispatchEvent(new CustomEvent('change', { bubbles: true }));
        document.body.removeEventListener('cardedit', edit);
        expect(edit).toHaveBeenCalledTimes(1);
        expect(edit.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', fieldKey: 'ActivityDate', value: 'next Tuesday' });
    });

    test('an unchanged value fires nothing', () => {
        const el = mount(READY_DRAFT, 'open');
        const edit = jest.fn();
        el.addEventListener('cardedit', edit);
        input(el, 'Subject').dispatchEvent(new CustomEvent('change', { bubbles: true }));
        expect(edit).not.toHaveBeenCalled();
    });

    test('keys typed in a field stay in the card, except Esc', () => {
        const el = mount(READY_DRAFT, 'open');
        const keys = jest.fn();
        document.body.addEventListener('keydown', keys);
        input(el, 'Subject').dispatchEvent(new KeyboardEvent('keydown', { key: 'g', bubbles: true, composed: true }));
        input(el, 'Subject').dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, composed: true }));
        document.body.removeEventListener('keydown', keys);
        expect(keys).toHaveBeenCalledTimes(1);
        expect(keys.mock.calls[0][0].key).toBe('Escape');
    });

    test('Edit moves focus to the first field to fill, or the first field', async () => {
        const el = mount(NEEDS_DRAFT, 'open');
        const action = jest.fn();
        el.addEventListener('cardaction', action);
        button(el, 'Edit').click();
        await flush();
        expect(el.shadowRoot.activeElement).toBe(input(el, 'ActivityDate'));
        expect(action.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', control: 'edit' });

        const ready = mount(READY_DRAFT, 'open');
        button(ready, 'Edit').click();
        await flush();
        expect(ready.shadowRoot.activeElement).toBe(input(ready, 'Subject'));
    });

    test('Confirm and Cancel fire cardaction', () => {
        const el = mount(READY_DRAFT, 'open');
        const action = jest.fn();
        el.addEventListener('cardaction', action);
        button(el, 'Confirm').click();
        button(el, 'Cancel').click();
        expect(action.mock.calls.map((c) => c[0].detail.control)).toEqual(['confirm', 'cancel']);
    });

    test('busy: every field and button is disabled', () => {
        const el = mount(READY_DRAFT, 'busy');
        qa(el, 'input').forEach((i) => expect(i.disabled).toBe(true));
        qa(el, '.cs-controls button').forEach((b) => expect(b.disabled).toBe(true));
        expect(q(el, 'article').getAttribute('aria-busy')).toBe('true');
    });

    test('closed: the values are shown, nothing is editable and no button is left', () => {
        const el = mount(READY_DRAFT, 'closed');
        expect(q(el, 'input')).toBeNull();
        expect(q(el, '.cs-controls')).toBeNull();
        expect(qa(el, '.cs-dd').map((d) => d.textContent.trim())).toContain('2026-11-17');
    });

    test('an update edits the new value only; the value before is shown beside it', () => {
        const el = mount(UPDATE_DRAFT, 'open');
        expect(input(el, 'StageName').value).toBe('Negotiation');
        expect(q(el, '.cs-field[data-field="StageName"] .cs-was').textContent).toBe('Was Qualification');
        expect(input(el, 'Id').value).toBe('Edge SLA');
    });

    test('a field with several matches keeps its choice chips beside the field', () => {
        const draft = FIXTURES.find((c) => c.type === 'actionDraft');
        const el = mount(draft, 'open');
        const choose = jest.fn();
        el.addEventListener('cardchoose', choose);
        expect(input(el, 'WhoId').value).toBe('Jordan');
        expect(input(el, 'Priority').value).toBe('');
        qa(el, '.cs-choices button')[0].click();
        expect(choose.mock.calls[0][0].detail).toEqual({ cardKey: 'drf', fieldKey: 'WhoId', ref: 'c1', recordId: 'record-id:c1' });
        expect(button(el, 'Confirm').disabled).toBe(true);
    });

    test('a refused draft offers only Cancel', () => {
        const refused = {
            ...NEEDS_DRAFT,
            status: 'REFUSED',
            fields: [],
            items: [{ label: "You can't create tasks with your access." }],
            controls: [{ key: 'cancel', label: 'Cancel', kind: 'link' }],
            refs: [],
            text: "Create a task · Task · create\nNote: You can't create tasks with your access.\nOptions: Cancel"
        };
        const el = mount(refused, 'open');
        expect(qa(el, '.cs-controls button').map((b) => b.textContent)).toEqual(['Cancel']);
        expect(q(el, '.cs-badge').textContent).toBe('Refused');
    });
});

describe('the result card', () => {
    test('shows what was written, the record as a link and the Open button', () => {
        const el = mount(RESULT, 'open');
        const open = jest.fn();
        const action = jest.fn();
        el.addEventListener('cardopen', open);
        el.addEventListener('cardaction', action);
        expect(q(el, 'article').dataset.type).toBe('actionResult');
        expect(q(el, '.cs-title-text').textContent).toBe('Task created');
        expect(qa(el, '.cs-dt').map((d) => d.textContent)).toEqual(['Subject', 'Due']);
        expect(q(el, 'input')).toBeNull();
        expect(q(el, '.cs-p').textContent).toBe('Saved as you, with your access.');
        const link = q(el, '.cs-field button.cs-link');
        expect(link.textContent).toBe('Follow up on pricing');
        link.click();
        expect(open.mock.calls[0][0].detail).toEqual({ ref: 't9', recordId: 'record-id:t9', objectName: 'Task' });
        button(el, 'Open task').click();
        expect(action.mock.calls[0][0].detail).toEqual({ cardKey: 'res', control: 'open' });
    });

    test('an update result offers Undo next to Open', () => {
        const el = mount({ ...RESULT, title: 'Opportunity updated', controls: RESULT.controls.concat([{ key: 'undo', label: 'Undo', kind: 'neutral' }]) }, 'open');
        expect(qa(el, '.cs-controls button').map((b) => b.textContent)).toEqual(['Open task', 'Undo']);
    });
});

describe('accessibility', () => {
    test('the draft, open and busy, the missing field and the result have no violations', async () => {
        mount(NEEDS_DRAFT, 'open');
        mount(UPDATE_DRAFT, 'busy', 'comfortable');
        mount(READY_DRAFT, 'closed');
        mount(RESULT, 'open');
        await flush();
        await expect(document.body).toBeAccessible();
    });
});
