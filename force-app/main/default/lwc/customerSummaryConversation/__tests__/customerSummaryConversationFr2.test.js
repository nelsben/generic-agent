/**
 * FE-22: the conversation's sessions control (BE-26 history), the scope chip above the composer, the
 * answer cards (c-customer-summary-card), the density it passes them, and the headings it adds,
 * which wrap at the compact width. FE-12's own tests stay in customerSummaryConversation.test.js, unchanged.
 */
import { createElement } from 'lwc';
import CustomerSummaryConversation from 'c/customerSummaryConversation';
import resolve from '@salesforce/apex/CustomerSummaryPanelController.resolve';
import getBrief from '@salesforce/apex/CustomerSummaryPanelController.getBrief';
import explore from '@salesforce/apex/CustomerSummaryPanelController.explore';
import drill from '@salesforce/apex/CustomerSummaryPanelController.drill';
import history from '@salesforce/apex/CustomerSummaryPanelController.history';
import sources from '@salesforce/apex/CustomerSummaryPanelController.sources';
import listSessions from '@salesforce/apex/CustomerSummaryHistory.listSessions';
import getSession from '@salesforce/apex/CustomerSummaryHistory.getSession';

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

const BUNDLE = path.join(__dirname, '..');
const SOURCE_JS = fs.readFileSync(path.join(BUNDLE, 'customerSummaryConversation.js'), 'utf8');
const SOURCE_HTML = fs.readFileSync(path.join(BUNDLE, 'customerSummaryConversation.html'), 'utf8');
const SOURCE_CSS = fs.readFileSync(path.join(BUNDLE, 'customerSummaryConversation.css'), 'utf8');

const ACME = '001000000000001AAA';
const DEAL = '006000000000001AAA';
const SESSION_NEW = 'a01000000000002AAA';
const SESSION_OLD = 'a01000000000001AAA';
const BRAND = { agentName: 'Northwind Assist', companyName: 'Northwind Health', logoUrl: '/resource/BrandLogo' };

const SESSIONS = [
    { id: SESSION_NEW, accountId: ACME, title: 'Who owns the renewal?', startedAt: '2026-11-12T09:00:00.000Z', lastActive: '2026-11-12T10:00:00.000Z', turnCount: 2 },
    { id: SESSION_OLD, accountId: ACME, title: 'Acme is steady', startedAt: '2026-11-01T09:00:00.000Z', lastActive: '2026-11-01T09:30:00.000Z', turnCount: 1 }
];
const SESSION_DETAIL = {
    ...SESSIONS[0],
    turns: [
        { at: '2026-11-12T09:00:00.000Z', status: 'OK', question: '', headline: 'Acme is steady.', kind: 'summary' },
        { at: '2026-11-12T10:00:00.000Z', status: 'OK', question: 'Who owns the renewal?', headline: 'Pat Lee owns it.', kind: 'explorer' }
    ]
};

const DEAL_REF = { key: 'o1', recordId: DEAL, objectName: 'Opportunity', label: 'Edge SLA' };
const TEXT_CARD = {
    type: 'text',
    version: 1,
    key: 'ans',
    title: '',
    status: 'OK',
    text: 'One deal: Edge SLA.',
    body: [{ kind: 'p', runs: [{ text: 'One deal: ' }, { text: 'Edge SLA', ref: 'o1' }, { text: '.' }] }],
    refs: [DEAL_REF]
};
const TABLE_CARD = {
    type: 'table',
    version: 1,
    key: 'rs0',
    title: 'Opportunity',
    status: 'OK',
    text: 'Opportunity\nName | Stage\nEdge SLA | Qualification',
    columns: [{ key: 'Name', label: 'Name', kind: 'text' }, { key: 'StageName', label: 'Stage', kind: 'text' }],
    rows: [{ ref: 'o1', cells: ['Edge SLA', 'Qualification'] }],
    total: 1,
    shown: 1,
    refs: [DEAL_REF]
};
const FOLLOWUPS_CARD = {
    type: 'followups',
    version: 1,
    key: 'fol',
    title: '',
    status: 'OK',
    text: '- Which close this quarter?',
    items: [{ label: 'Which close this quarter?' }],
    refs: []
};
const RECORD_CARD = {
    type: 'record',
    version: 1,
    key: 'rec',
    title: 'Edge SLA',
    meta: 'Opportunity',
    status: 'OK',
    text: 'Edge SLA · Opportunity\nAccount: Acme\nStage: Qualification',
    body: [],
    fields: [
        { key: 'Account', label: 'Account', value: 'Acme', ref: 'a1' },
        { key: 'StageName', label: 'Stage', value: 'Qualification' }
    ],
    items: [{ label: 'Tasks', kind: 'related' }, { label: 'Opportunity Contact Roles', kind: 'related' }],
    refs: [{ key: 'a1', recordId: ACME, objectName: 'Account', label: 'Acme' }]
};

async function flush() {
    for (let i = 0; i < 4; i++) {
        // eslint-disable-next-line no-await-in-loop, @lwc/lwc/no-async-operation
        await new Promise((r) => setTimeout(r, 0));
    }
}

function deferred() {
    let res;
    const promise = new Promise((a) => {
        res = a;
    });
    return { promise, resolve: res };
}

async function mount(props) {
    const el = createElement('c-customer-summary-conversation', { is: CustomerSummaryConversation });
    Object.assign(el, props || {});
    document.body.appendChild(el);
    sources.emit([{ key: 'profile', title: 'Profile' }]);
    await flush();
    return el;
}

async function mountOnAccount(extra) {
    resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme', cards: '[]' });
    return mount({ recordId: ACME, objectApiName: 'Account', brand: BRAND, ...(extra || {}) });
}

const $ = (el, sel) => el.shadowRoot.querySelector(sel);
const $$ = (el, sel) => Array.from(el.shadowRoot.querySelectorAll(sel));
const composer = (el) => $(el, 'textarea.abp-composer');
const cards = (el) => $$(el, 'c-customer-summary-card');
const questions = (el) => $$(el, '.abp-turn .abp-question').map((q) => q.textContent);

async function ask(el, question) {
    const box = composer(el);
    box.value = question;
    box.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
    await flush();
    box.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, composed: true, cancelable: true }));
    await flush();
}

async function openSessions(el) {
    $(el, '.abp-sessions-toggle').click();
    await flush();
}

describe('c-customer-summary-conversation FE-22', () => {
    beforeEach(() => {
        Element.prototype.scrollIntoView = jest.fn();
        history.mockResolvedValue([]);
        listSessions.mockResolvedValue(SESSIONS);
        resolve.mockResolvedValue({ status: 'NOT_FOUND', message: 'No account matches.', cards: '[]' });
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        [resolve, getBrief, explore, drill, history, listSessions, getSession].forEach((m) => m.mockReset());
    });

    describe('public interface', () => {
        it('documents and keeps density and sessionsOpen next to the FE-12 interface', () => {
            const header = SOURCE_JS.slice(0, SOURCE_JS.indexOf('*/'));
            ['@api recordId', '@api sessionId', '@api focusComposer()', 'sessionchange', '@api density', '@api sessionsOpen'].forEach((part) =>
                expect(header).toContain(part)
            );
        });

        it('density defaults to compact and accepts comfortable only', async () => {
            const el = await mount();
            expect(el.density).toBe('compact');
            el.density = 'comfortable';
            expect(el.density).toBe('comfortable');
            el.density = 'wide';
            expect(el.density).toBe('compact');
        });
    });

    describe('sessions control', () => {
        it('lists this account’s conversations, newest first, through BE-26’s list method', async () => {
            const el = await mountOnAccount();
            const toggle = $(el, '.abp-sessions-toggle');
            expect(toggle.tagName).toBe('BUTTON');
            expect(toggle.getAttribute('aria-expanded')).toBe('false');
            await openSessions(el);
            expect(listSessions).toHaveBeenCalledWith({ accountId: ACME, limitSize: 20 });
            expect(toggle.getAttribute('aria-expanded')).toBe('true');
            expect($$(el, '.abp-session-title').map((t) => t.textContent)).toEqual(['Who owns the renewal?', 'Acme is steady']);
            expect($(el, '.abp-sessions-heading').textContent).toBe('Earlier conversations about Acme');
            expect(el.shadowRoot.innerHTML).not.toContain(SESSION_NEW);
        });

        it('sorts by last activity when the list arrives out of order', async () => {
            listSessions.mockResolvedValue([SESSIONS[1], SESSIONS[0]]);
            const el = await mountOnAccount();
            await openSessions(el);
            expect($$(el, '.abp-session-title').map((t) => t.textContent)).toEqual(['Who owns the renewal?', 'Acme is steady']);
        });

        it('the list is one Tab stop', async () => {
            const el = await mountOnAccount();
            await openSessions(el);
            expect($$(el, '.abp-session').map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1']);
        });

        it('reopening loads its turns in order, sets sessionId and fires sessionchange', async () => {
            getSession.mockResolvedValue(SESSION_DETAIL);
            const el = await mountOnAccount();
            const changed = jest.fn();
            el.addEventListener('sessionchange', changed);
            await openSessions(el);
            $$(el, '.abp-session')[0].click();
            await flush();
            expect(getSession).toHaveBeenCalledWith({ sessionId: SESSION_NEW });
            expect(questions(el)).toEqual(['Summary', 'Who owns the renewal?']);
            expect($$(el, '.abp-turn .abp-agent-text').map((t) => t.textContent)).toEqual(['Acme is steady.', 'Pat Lee owns it.']);
            expect(el.sessionId).toBe(SESSION_NEW);
            expect(changed).toHaveBeenCalledTimes(1);
            expect(changed.mock.calls[0][0].detail).toEqual({ sessionId: SESSION_NEW });
            expect($(el, '.abp-sessions-toggle').getAttribute('aria-expanded')).toBe('false');

            // The reopened turns are the history the next question carries.
            explore.mockResolvedValue({ status: 'OK', answer: 'Yes.', resultSets: [], trail: [], followups: [] });
            await ask(el, 'Is that still true?');
            const sent = JSON.parse(explore.mock.calls[0][0].historyJson);
            expect(sent).toEqual([
                { question: 'Summary', answer: 'Acme is steady.' },
                { question: 'Who owns the renewal?', answer: 'Pat Lee owns it.' }
            ]);
        });

        it('reopening drops a reply still on its way for the old thread', async () => {
            const slow = deferred();
            explore.mockReturnValueOnce(slow.promise);
            getSession.mockResolvedValue(SESSION_DETAIL);
            const el = await mountOnAccount();
            await ask(el, 'Slow question');
            await openSessions(el);
            $$(el, '.abp-session')[0].click();
            await flush();
            slow.resolve({ status: 'OK', answer: 'Late.', resultSets: [], trail: [], followups: [] });
            await flush();
            expect(questions(el)).toEqual(['Summary', 'Who owns the renewal?']);
            expect($(el, '.abp-pending')).toBeNull();
        });

        it('"New conversation" starts a clean thread with a new session id', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'Two.', resultSets: [], trail: [], followups: [] });
            const el = await mountOnAccount();
            await ask(el, 'How many deals?');
            const first = el.sessionId;
            const changed = jest.fn();
            el.addEventListener('sessionchange', changed);
            await openSessions(el);
            $(el, '.abp-sessions-new').click();
            await flush();
            expect($$(el, '.abp-turn')).toHaveLength(0);
            expect(el.sessionId).toMatch(/^cs-/);
            expect(el.sessionId).not.toBe(first);
            expect(changed.mock.calls[0][0].detail).toEqual({ sessionId: el.sessionId });
        });

        it('an empty list says so in one sentence', async () => {
            listSessions.mockResolvedValue([]);
            const el = await mountOnAccount();
            await openSessions(el);
            expect($(el, '.abp-sessions-message').textContent).toBe('No earlier conversations about Acme yet.');
            expect($$(el, '.abp-session')).toHaveLength(0);
        });

        it('a failed load says so in one sentence', async () => {
            listSessions.mockRejectedValue({ body: { message: 'System.QueryException: boom' } });
            const el = await mountOnAccount();
            await openSessions(el);
            expect($(el, '.abp-sessions-message').textContent).toBe("Couldn't load your earlier conversations. Try again in a minute.");
            expect(el.shadowRoot.textContent).not.toContain('boom');
        });

        it('a session whose account the user can no longer see says so, and the thread stays', async () => {
            getSession.mockResolvedValue(null);
            explore.mockResolvedValue({ status: 'OK', answer: 'Two.', resultSets: [], trail: [], followups: [] });
            const el = await mountOnAccount();
            await ask(el, 'How many deals?');
            const id = el.sessionId;
            await openSessions(el);
            $$(el, '.abp-session')[1].click();
            await flush();
            expect($(el, '.abp-sessions-message').textContent).toBe("That conversation can't be opened: you can no longer see its account.");
            expect(questions(el)).toEqual(['How many deals?']);
            expect(el.sessionId).toBe(id);
        });

        it('a reopen that fails says so in one sentence', async () => {
            getSession.mockRejectedValue({});
            const el = await mountOnAccount();
            await openSessions(el);
            $$(el, '.abp-session')[0].click();
            await flush();
            expect($(el, '.abp-sessions-message').textContent).toBe("Couldn't open that conversation. Try again in a minute.");
        });

        it('with no account it asks for one and calls nothing', async () => {
            const el = await mount();
            await openSessions(el);
            expect($(el, '.abp-sessions-message').textContent).toBe('Open or summarize an account to see your earlier conversations about it.');
            expect(listSessions).not.toHaveBeenCalled();
        });

        it('sessionsOpen shows the control open through the public interface', async () => {
            const el = await mountOnAccount({ sessionsOpen: true });
            expect(el.sessionsOpen).toBe(true);
            expect($(el, '.abp-sessions-toggle').getAttribute('aria-expanded')).toBe('true');
            expect($(el, '.abp-sessions').hasAttribute('hidden')).toBe(false);
            expect(listSessions).toHaveBeenCalledWith({ accountId: ACME, limitSize: 20 });
            expect($$(el, '.abp-session')).toHaveLength(2);
            el.sessionsOpen = false;
            await flush();
            expect($(el, '.abp-sessions').hasAttribute('hidden')).toBe(true);
        });
    });

    describe('scope chip', () => {
        it('on an account: "About Acme", and a control to ask the whole org instead', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'A.', resultSets: [], trail: [], followups: [] });
            const el = await mountOnAccount();
            const group = $(el, '.abp-scope');
            expect(group.getAttribute('role')).toBe('group');
            expect(group.getAttribute('aria-label')).toBe('Question scope');
            expect($(el, '.abp-scope-label').textContent).toBe('About Acme');
            const sw = $(el, '.abp-scope-switch');
            expect(sw.tagName).toBe('BUTTON');
            expect(sw.textContent).toBe('Ask the whole org');
            await ask(el, 'Who owns it?');
            expect(explore.mock.calls[0][0].contextRecordId).toBe(ACME);

            sw.click();
            await flush();
            expect($(el, '.abp-scope-label').textContent).toBe('Whole org');
            expect($(el, '.abp-scope-switch').textContent).toBe('Ask about Acme');
            await ask(el, 'Which accounts have open cases?');
            expect(explore.mock.calls[1][0].contextRecordId).toBeNull();

            $(el, '.abp-scope-switch').click();
            await flush();
            expect($(el, '.abp-scope-label').textContent).toBe('About Acme');
            await ask(el, 'And now?');
            expect(explore.mock.calls[2][0].contextRecordId).toBe(ACME);
        });

        it('with no account: "Whole org", and its control starts a summary', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'A.', resultSets: [], trail: [], followups: [] });
            const el = await mount();
            expect($(el, '.abp-scope-label').textContent).toBe('Whole org');
            const sw = $(el, '.abp-scope-switch');
            expect(sw.textContent).toBe('Ask about an account');
            sw.click();
            await flush();
            expect(composer(el).value).toBe('/brief ');
            expect(el.shadowRoot.activeElement).toBe(composer(el));
            await ask(el, 'Anything?');
            expect(explore.mock.calls[0][0].contextRecordId).toBeNull();
        });

        it('after a summary off the account page: "About" the summarized account', async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme', cards: '[]' });
            getBrief.mockResolvedValue({ status: 'OK', message: '', answer: 'Acme is steady.', sections: [], ignored: [], cards: [] });
            explore.mockResolvedValue({ status: 'OK', answer: 'A.', resultSets: [], trail: [], followups: [] });
            const el = await mount();
            await ask(el, '/brief Acme');
            expect($(el, '.abp-scope-label').textContent).toBe('About Acme');
            await ask(el, 'Who owns it?');
            expect(explore.mock.calls[0][0].contextRecordId).toBe(ACME);
        });

        it('on another record: "About this record"', async () => {
            const el = await mount({ recordId: DEAL, objectApiName: 'Opportunity' });
            expect($(el, '.abp-scope-label').textContent).toBe('About this record');
            expect($(el, '.abp-scope-switch').textContent).toBe('Ask the whole org');
        });

        it('the quick actions keep the account whatever the chip says', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'A.', resultSets: [], trail: [], followups: [] });
            const el = await mountOnAccount();
            $(el, '.abp-scope-switch').click();
            await flush();
            $$(el, '.abp-quick').find((b) => b.textContent.trim() === 'Open deals').click();
            await flush();
            expect(explore.mock.calls[0][0].contextRecordId).toBe(ACME);
        });

        it('a host ask with a record keeps that record', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'A.', resultSets: [], trail: [], followups: [] });
            const el = await mountOnAccount();
            $(el, '.abp-scope-switch').click();
            await flush();
            await el.ask('Open deals?', DEAL);
            expect(explore.mock.calls[0][0].contextRecordId).toBe(DEAL);
        });
    });

    describe('answer cards', () => {
        it('an answer with cards draws each card at the conversation’s density', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal: Edge SLA.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD, TABLE_CARD, FOLLOWUPS_CARD] });
            const el = await mount();
            await ask(el, 'deals?');
            expect(cards(el)).toHaveLength(3);
            expect(cards(el).map((c) => c.density)).toEqual(['compact', 'compact', 'compact']);
            expect(cards(el)[1].card).toEqual(TABLE_CARD);
            expect($(el, '.abp-answer')).toBeNull();
            el.density = 'comfortable';
            await flush();
            expect(cards(el).map((c) => c.density)).toEqual(['comfortable', 'comfortable', 'comfortable']);
        });

        it('an answer with no cards renders exactly as before', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: '**One** deal.', resultSets: [], trail: [], followups: [], cards: [] });
            const el = await mount();
            await ask(el, 'deals?');
            expect(cards(el)).toHaveLength(0);
            expect($(el, '.abp-answer strong').textContent).toBe('One');
        });

        it('cards as a JSON string (the resolver) are read; unreadable JSON leaves the text', async () => {
            const notice = {
                type: 'notice',
                version: 1,
                key: 'not',
                title: '',
                status: 'NOT_FOUND',
                text: 'No account matches "Edgx". Try a fuller or different account name.',
                body: [{ kind: 'p', runs: [{ text: 'No account matches "Edgx". Try a fuller or different account name.' }] }],
                refs: []
            };
            resolve.mockResolvedValueOnce({ status: 'NOT_FOUND', message: notice.text, cards: JSON.stringify([notice]) });
            resolve.mockResolvedValueOnce({ status: 'NOT_FOUND', message: 'No account matches "Zz".', cards: '[{' });
            const el = await mount();
            await ask(el, '/brief Edgx');
            expect(cards(el)).toHaveLength(1);
            expect(cards(el)[0].card).toEqual(notice);
            await ask(el, '/brief Zz');
            expect(cards(el)).toHaveLength(1);
            expect($$(el, '.abp-agent-text').pop().textContent).toBe('No account matches "Zz".');
        });

        it('a summary with cards draws them in place of the headline and the sections', async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme', cards: '[]' });
            const summary = { type: 'summary', version: 1, key: 'sum', title: 'Acme is steady', status: 'OK', text: 'Acme is steady', body: [], refs: [] };
            getBrief.mockResolvedValue({ status: 'OK', message: '', answer: 'Acme is steady', sections: [], ignored: ['bogus'], cards: [summary] });
            const el = await mount();
            await ask(el, '/brief Acme');
            expect(cards(el)).toHaveLength(1);
            expect($(el, '[data-testid="abp-summary-headline"]')).toBeNull();
            expect(el.shadowRoot.textContent).toContain('Not sections: bogus');
        });

        it('cardopen drills in the panel by the Id it carries; the drill draws its record card', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD] });
            drill.mockResolvedValue({
                result: { objectName: 'Opportunity', columns: ['Id', 'Name'], rows: [{ Id: DEAL, Name: 'Edge SLA' }], total: 1, shown: 1 },
                related: ['Task', 'OpportunityContactRole'],
                cards: [RECORD_CARD]
            });
            const outside = jest.fn();
            document.body.addEventListener('cardopen', outside);
            const el = await mount();
            await ask(el, 'deals?');
            cards(el)[0].shadowRoot.querySelector('button.cs-link').click();
            await flush();
            document.body.removeEventListener('cardopen', outside);
            expect(drill).toHaveBeenCalledWith({ recordId: DEAL, relatedObject: null });
            expect(outside).not.toHaveBeenCalled();
            expect($(el, '.abp-drill-heading').textContent).toBe('Edge SLA');
            expect(cards(el).filter((c) => c.card.type === 'record')).toHaveLength(1);
            expect($(el, '.abp-view-record')).not.toBeNull();
        });

        it('back from a card’s drill, focus returns to the link it started from', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD] });
            drill.mockResolvedValue({
                result: { objectName: 'Opportunity', columns: ['Id', 'Name'], rows: [{ Id: DEAL, Name: 'Edge SLA' }], total: 1, shown: 1 },
                related: [],
                cards: [RECORD_CARD]
            });
            const el = await mount();
            await ask(el, 'deals?');
            const link = cards(el)[0].shadowRoot.querySelector('button.cs-link');
            link.click();
            await flush();
            $(el, 'lightning-breadcrumb').dispatchEvent(new CustomEvent('click', { cancelable: true }));
            await flush();
            expect($(el, '.abp-drill-heading')).toBeNull();
            expect(cards(el)[0].shadowRoot.activeElement).toBe(link);
        });

        it('an AMBIGUOUS resolve keeps its candidate buttons (its choice card is not drawn here)', async () => {
            const choice = {
                type: 'choice',
                version: 1,
                key: 'cho',
                title: 'Which Acme?',
                status: 'AMBIGUOUS',
                text: 'Which Acme?',
                items: [{ label: 'Acme', detail: 'Austin', ref: 'a1' }],
                refs: [{ key: 'a1', recordId: ACME, objectName: 'Account', label: 'Acme' }]
            };
            resolve.mockResolvedValueOnce({ status: 'AMBIGUOUS', message: 'Which Acme?\nAcme — Austin — ' + ACME, cards: JSON.stringify([choice]) });
            const el = await mount();
            await ask(el, '/brief Acme');
            expect(cards(el)).toHaveLength(0);
            expect($$(el, '.abp-candidate')).toHaveLength(1);
        });

        it('a related object on the drill’s record card drills to its rows', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD] });
            drill.mockResolvedValueOnce({
                result: { objectName: 'Opportunity', columns: ['Id', 'Name'], rows: [{ Id: DEAL, Name: 'Edge SLA' }], total: 1, shown: 1 },
                related: ['Task', 'OpportunityContactRole'],
                cards: [RECORD_CARD]
            });
            drill.mockResolvedValueOnce({ result: { objectName: 'OpportunityContactRole', columns: ['Id'], rows: [], total: 0, shown: 0 }, related: [], cards: [] });
            const el = await mount();
            await ask(el, 'deals?');
            cards(el)[0].shadowRoot.querySelector('button.cs-link').click();
            await flush();
            const record = cards(el).find((c) => c.card.type === 'record');
            const chips = Array.from(record.shadowRoot.querySelectorAll('[aria-label="Related records"] button'));
            chips[1].click();
            await flush();
            expect(drill).toHaveBeenLastCalledWith({ recordId: DEAL, relatedObject: 'OpportunityContactRole' });
            expect(explore).toHaveBeenCalledTimes(1);
        });

        it('cardask goes down the normal ask path', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [FOLLOWUPS_CARD] });
            const el = await mountOnAccount();
            await ask(el, 'deals?');
            cards(el)[0].shadowRoot.querySelector('.cs-chip').click();
            await flush();
            expect(explore).toHaveBeenLastCalledWith(expect.objectContaining({ question: 'Which close this quarter?', contextRecordId: ACME }));
        });

        it('cardchoose and cardaction are not handled here: they bubble out', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD] });
            const el = await mount();
            await ask(el, 'deals?');
            const choose = jest.fn();
            const action = jest.fn();
            document.body.addEventListener('cardchoose', choose);
            document.body.addEventListener('cardaction', action);
            const card = cards(el)[0];
            card.dispatchEvent(new CustomEvent('cardchoose', { detail: { cardKey: 'cho', fieldKey: null, ref: 'a1', recordId: ACME }, bubbles: true, composed: true }));
            card.dispatchEvent(new CustomEvent('cardaction', { detail: { cardKey: 'drf', control: 'confirm' }, bubbles: true, composed: true }));
            document.body.removeEventListener('cardchoose', choose);
            document.body.removeEventListener('cardaction', action);
            expect(choose).toHaveBeenCalledTimes(1);
            expect(action).toHaveBeenCalledTimes(1);
            expect(drill).not.toHaveBeenCalled();
            expect(explore).toHaveBeenCalledTimes(1);
        });

        it('no record Id is in the markup at either density', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD, TABLE_CARD] });
            for (const density of ['compact', 'comfortable']) {
                // eslint-disable-next-line no-await-in-loop
                const el = await mount({ density });
                // eslint-disable-next-line no-await-in-loop
                await ask(el, 'deals?');
                expect(el.shadowRoot.innerHTML).not.toContain(DEAL);
                cards(el).forEach((c) => expect(c.shadowRoot.innerHTML).not.toContain(DEAL));
                document.body.removeChild(el);
            }
        });
    });

    describe('section headings at the compact width', () => {
        // FE-22 kept FE-12's two tools headings as lightning-accordion-section labels: the panel's
        // own suite (customerSummaryPanel.test.js, outside this card's scope) pins them there, and a
        // base component's label cannot be made to wrap from here. The headings FE-22 adds wrap.
        it('the earlier summaries heading keeps its full text as the section label', async () => {
            history.mockResolvedValue([{ at: '2026-11-12T09:00:00.000Z', status: 'OK', question: '', headline: 'Acme is steady.', kind: 'summary' }]);
            const el = await mountOnAccount();
            expect($(el, '.abp-history-section').label).toBe('Earlier summaries of Acme (1)');
        });

        it('the sessions heading and the card titles wrap: no truncation', () => {
            const css = SOURCE_CSS.replace(/\/\*[\s\S]*?\*\//g, '');
            expect(css).toMatch(/\.abp-sessions-heading\s*\{[^}]*white-space:\s*normal;[^}]*overflow-wrap:\s*anywhere;/);
            expect(css).toMatch(/\.abp-card-title\s*\{[^}]*overflow-wrap:\s*anywhere;/);
            expect(SOURCE_HTML).not.toMatch(/class="[^"]*abp-sessions-heading[^"]*slds-truncate/);
        });

        it('the new controls meet the 24 px target size', () => {
            const css = SOURCE_CSS.replace(/\/\*[\s\S]*?\*\//g, '');
            const rule = /([^{}]*)\{[^}]*min-height:\s*24px;[^}]*min-width:\s*24px;[^}]*\}/.exec(css);
            ['.abp-sessions-toggle', '.abp-sessions-new', '.abp-session', '.abp-scope-switch'].forEach((sel) => expect(rule[1]).toContain(sel));
        });
    });

    describe('accessibility', () => {
        it('is accessible with the sessions open, the chip and a card answer', async () => {
            explore.mockResolvedValue({ status: 'OK', answer: 'One deal.', resultSets: [], trail: [], followups: [], cards: [TEXT_CARD, TABLE_CARD, FOLLOWUPS_CARD] });
            const el = await mountOnAccount({ sessionsOpen: true });
            await ask(el, 'deals?');
            await expect(el).toBeAccessible();
        });

        it('is accessible with no account and the sessions open', async () => {
            const el = await mount({ brand: BRAND, sessionsOpen: true });
            await expect(el).toBeAccessible();
        });
    });
});
