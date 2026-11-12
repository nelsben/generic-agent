import { createElement } from 'lwc';
import AccountBriefPanel from 'c/accountBriefPanel';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, MessageContext } from 'lightning/messageService';
import { EnclosingUtilityId, open as openUtility, minimize as minimizeUtility } from 'lightning/platformUtilityBarApi';
import resolve from '@salesforce/apex/AccountBriefPanelController.resolve';
import getBrief from '@salesforce/apex/AccountBriefPanelController.getBrief';
import explore from '@salesforce/apex/AccountBriefPanelController.explore';
import drill from '@salesforce/apex/AccountBriefPanelController.drill';
import history from '@salesforce/apex/AccountBriefPanelController.history';
import sources from '@salesforce/apex/AccountBriefPanelController.sources';

const mockNavigate = jest.fn();

jest.mock('lightning/navigation', () => {
    const { createTestWireAdapter } = require('@salesforce/wire-service-jest-util');
    const Navigate = Symbol('Navigate');
    const NavigationMixin = (Base) =>
        class extends Base {
            [Navigate](pageRef) {
                mockNavigate(pageRef);
            }
        };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin, CurrentPageReference: createTestWireAdapter(jest.fn()) };
});

jest.mock('@salesforce/apex/AccountBriefPanelController.resolve', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AccountBriefPanelController.getBrief', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AccountBriefPanelController.explore', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AccountBriefPanelController.drill', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AccountBriefPanelController.history', () => ({ default: jest.fn() }), { virtual: true });
jest.mock(
    '@salesforce/apex/AccountBriefPanelController.sources',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/AccountBriefPanelController.agentId',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock('@salesforce/messageChannel/AccountBriefOpen__c', () => ({ default: 'AccountBriefOpen__c' }), { virtual: true });

const FIXED_ERROR = "I couldn't finish that right now. Try again in a minute.";
const ACME = '001000000000001AAA';
const BETA = '001000000000002AAA';
const DEAL = '006000000000001AAA';
const XSS = '<img src=x onerror=alert(1)>';

const ACCOUNT_PAGE = (id) => ({ type: 'standard__recordPage', attributes: { recordId: id, objectApiName: 'Account', actionName: 'view' } });
const HOME_PAGE = { type: 'standard__namedPage', attributes: { pageName: 'home' } };

function deferred() {
    let res;
    let rej;
    const promise = new Promise((a, b) => {
        res = a;
        rej = b;
    });
    return { promise, resolve: res, reject: rej };
}

// Settles promise chains and the panel's setTimeout(0) focus.
async function flush() {
    for (let i = 0; i < 4; i++) {
        // eslint-disable-next-line no-await-in-loop, @lwc/lwc/no-async-operation
        await new Promise((r) => setTimeout(r, 0));
    }
}

function exploreResult(answer, extra) {
    return { status: 'OK', answer, resultSets: [], trail: [], followups: [], ...(extra || {}) };
}

function dealResult() {
    return exploreResult('One open deal.', {
        resultSets: [
            {
                objectName: 'Opportunity',
                columns: ['Name', 'Amount'],
                rows: [{ Id: DEAL, Name: 'Panel Deal', Amount: 500 }],
                total: 1,
                shown: 1
            }
        ],
        trail: ['Opportunity | AccountId = x | 1 row'],
        followups: ['Who owns it?']
    });
}

function briefResult(extra) {
    return {
        status: 'OK',
        message: '',
        answer: 'Acme is healthy.\nOne open deal.',
        sections: [{ key: 'open_deals', title: 'Open deals', status: 'OK', body: 'Panel Deal — ' + DEAL, total: 1, shown: 1 }],
        ignored: [],
        ...(extra || {})
    };
}

async function mount() {
    const el = createElement('c-account-brief-panel', { is: AccountBriefPanel });
    document.body.appendChild(el);
    MessageContext.emit({});
    EnclosingUtilityId.emit('u1');
    // A rerender runs renderedCallback, which subscribes once MessageContext has arrived.
    sources.emit([{ key: 'profile', title: 'Profile' }, { key: 'open_deals', title: 'Open deals' }]);
    await flush();
    return el;
}

const $ = (el, sel) => el.shadowRoot.querySelector(sel);
const $$ = (el, sel) => Array.from(el.shadowRoot.querySelectorAll(sel));
const text = (el) => el.shadowRoot.textContent;
const composer = (el) => $(el, '.abp-composer');

async function ask(el, question) {
    composer(el).dispatchEvent(new CustomEvent('change', { detail: { value: question } }));
    await flush();
    $(el, '.abp-send').click();
}

function key(target, init) {
    const event = new KeyboardEvent('keydown', { bubbles: true, composed: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
}

function setPlatform(value) {
    Object.defineProperty(window.navigator, 'platform', { value, configurable: true });
}

describe('c-account-brief-panel', () => {
    beforeEach(() => {
        setPlatform('Win32');
        Element.prototype.scrollIntoView = jest.fn();
        history.mockResolvedValue([]);
        resolve.mockResolvedValue({ status: 'NOT_FOUND', message: 'No account matches.' });
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        resolve.mockReset();
        getBrief.mockReset();
        explore.mockReset();
        drill.mockReset();
        history.mockReset();
    });

    // 1 (card finding 2): one request path, the latest request wins.
    describe('concurrency', () => {
        it('drops a slow first response that arrives after a second request', async () => {
            const first = deferred();
            const second = deferred();
            explore.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
            const el = await mount();

            await ask(el, 'first question');
            await flush();
            await ask(el, 'second question');
            await flush();
            expect(explore).toHaveBeenCalledTimes(2);

            second.resolve(exploreResult('Second answer.'));
            await flush();
            first.resolve(exploreResult('First answer.'));
            await flush();

            expect(text(el)).toContain('Second answer.');
            expect(text(el)).not.toContain('First answer.');
            expect($(el, 'lightning-spinner')).toBeNull();
        });

        it('keeps pending until the latest request finishes, whatever finishes first', async () => {
            const first = deferred();
            const second = deferred();
            explore.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
            const el = await mount();
            await ask(el, 'first');
            await flush();
            await ask(el, 'second');
            await flush();

            first.resolve(exploreResult('First answer.'));
            await flush();
            expect($(el, 'lightning-spinner')).not.toBeNull();
            expect(text(el)).not.toContain('First answer.');

            second.resolve(exploreResult('Second answer.'));
            await flush();
            expect($(el, 'lightning-spinner')).toBeNull();
        });

        it('does not go on to brief when a superseded resolve returns', async () => {
            const slowResolve = deferred();
            resolve.mockReturnValueOnce(slowResolve.promise);
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount();

            await ask(el, '/brief Acme');
            await flush();
            await ask(el, 'something else');
            await flush();
            slowResolve.resolve({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            await flush();

            expect(getBrief).not.toHaveBeenCalled();
            expect(text(el)).toContain('Answer.');
        });

        it('ignores a repeat click on the candidate already in flight, but a message still supersedes it', async () => {
            resolve.mockResolvedValueOnce({
                status: 'AMBIGUOUS',
                message: 'Two accounts match.\nAcme — Austin — ' + ACME + '\nAcme — Boston — ' + BETA
            });
            const el = await mount();
            await ask(el, '/brief Acme');
            await flush();

            const slow = deferred();
            resolve.mockReturnValueOnce(slow.promise);
            const candidate = $(el, '.abp-candidate');
            candidate.click();
            candidate.click();
            await flush();
            expect(resolve).toHaveBeenCalledTimes(2);

            explore.mockResolvedValue(exploreResult('Message answer.'));
            subscribe.mock.calls[0][2]({ prompt: 'Open deals?' });
            await flush();
            slow.resolve({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            await flush();
            expect(getBrief).not.toHaveBeenCalled();
            expect(text(el)).toContain('Message answer.');
        });

        it('drops a page-context resolve that lands after the page moved on', async () => {
            const lateA = deferred();
            resolve.mockReturnValueOnce(lateA.promise).mockResolvedValueOnce({ status: 'RESOLVED', accountId: BETA, accountName: 'Beta' });
            const el = await mount();
            CurrentPageReference.emit(ACCOUNT_PAGE(ACME));
            await flush();
            CurrentPageReference.emit(ACCOUNT_PAGE(BETA));
            await flush();
            lateA.resolve({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            await flush();

            expect($(el, '.abp-bar-row lightning-button').label).toBe('Brief Beta');
            expect(history).toHaveBeenCalledTimes(1);
            expect(history).toHaveBeenCalledWith({ accountId: BETA });
        });

        it('drops a drill reply that a newer request superseded', async () => {
            explore.mockResolvedValueOnce(dealResult());
            const el = await mount();
            await ask(el, 'deals?');
            await flush();

            const slowDrill = deferred();
            drill.mockReturnValueOnce(slowDrill.promise);
            $(el, '.abp-row-button').click();
            await flush();
            explore.mockResolvedValueOnce(exploreResult('Newer answer.'));
            await ask(el, 'newer');
            await flush();
            slowDrill.resolve({ result: { objectName: 'Opportunity', columns: ['Name'], rows: [{ Id: DEAL, Name: 'Panel Deal' }], total: 1, shown: 1 }, related: [] });
            await flush();

            expect($(el, '.abp-drill-heading')).toBeNull();
            expect(text(el)).toContain('Newer answer.');
        });
    });

    // 2: model text is bound as text only.
    it('renders markup in answers, cells, section lines and follow-ups as text', async () => {
        explore.mockResolvedValueOnce(
            exploreResult(XSS, {
                resultSets: [{ objectName: 'Opportunity', columns: ['Name'], rows: [{ Id: DEAL, Name: XSS }], total: 1, shown: 1 }],
                followups: [XSS],
                trail: [XSS]
            })
        );
        resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
        getBrief.mockResolvedValueOnce(briefResult({ answer: XSS + '\n' + XSS, sections: [{ key: 'k', title: 'T', status: 'OK', body: XSS + ' ' + DEAL, total: 1, shown: 1 }] }));
        const el = await mount();
        await ask(el, 'q');
        await flush();
        await ask(el, '/brief Acme');
        await flush();

        expect($$(el, 'img')).toHaveLength(0);
        expect(text(el)).toContain(XSS);
    });

    // 3: turn mapping.
    describe('turn mapping', () => {
        it('briefs a RESOLVED account: header, sections with status, ignored keys', async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(briefResult({ ignored: ['nope'] }));
            const el = await mount();
            await ask(el, '/brief Acme');
            await flush();

            expect(resolve).toHaveBeenCalledWith({ accountName: 'Acme', recordId: null });
            expect(getBrief).toHaveBeenCalledWith({ accountId: ACME, question: null, include: null });
            expect($(el, '.abp-summary h2').textContent).toBe('Acme is healthy.');
            const section = $(el, 'lightning-accordion-section.abp-section');
            expect(section.label).toBe('Open deals · 1 of 1');
            expect(section.querySelector('lightning-badge').label).toBe('OK');
            expect(text(el)).toContain('Not sections: nope');
        });

        it('turns AMBIGUOUS lines into candidates without raw Ids and re-resolves by Id', async () => {
            resolve.mockResolvedValueOnce({
                status: 'AMBIGUOUS',
                message: 'Two accounts match.\nAcme — Austin — ' + ACME + '\nAcme — Boston — ' + BETA + '\nShowing the first 2.'
            });
            const el = await mount();
            await ask(el, '/brief Acme');
            await flush();

            const candidates = $$(el, '.abp-candidate');
            expect(candidates.map((c) => c.dataset.id)).toEqual([ACME, BETA]);
            expect(candidates[0].textContent.trim()).toBe('Acme — Austin');
            expect(text(el)).toContain('Showing the first 2.');

            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: BETA, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(briefResult());
            candidates[1].click();
            await flush();
            expect(resolve).toHaveBeenLastCalledWith({ accountName: null, recordId: BETA });
            expect(getBrief).toHaveBeenCalledWith(expect.objectContaining({ accountId: BETA }));
        });

        it('shows NOT_FOUND and ERROR text verbatim, with error styling for ERROR', async () => {
            resolve.mockResolvedValueOnce({ status: 'NOT_FOUND', message: 'I can\'t find "Zed".' });
            const el = await mount();
            await ask(el, '/brief Zed');
            await flush();
            expect(text(el)).toContain('I can\'t find "Zed".');

            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce({ status: 'ERROR', message: 'I couldn\'t finish the brief right now. Try again in a minute.', answer: '', sections: [], ignored: [] });
            await ask(el, '/brief Acme');
            await flush();
            const errorLine = $$(el, '[data-error="true"]').pop();
            expect(errorLine.textContent).toBe('I couldn\'t finish the brief right now. Try again in a minute.');
        });
    });

    // 4: errors.
    describe('errors', () => {
        it('shows the AuraHandledException text from body.message', async () => {
            explore.mockRejectedValueOnce({ body: { message: FIXED_ERROR } });
            const el = await mount();
            await ask(el, 'q');
            await flush();
            expect($(el, '[data-error="true"]').textContent).toBe(FIXED_ERROR);
        });

        it('shows the fixed fallback, never raw script text, when there is no body.message', async () => {
            explore.mockRejectedValueOnce(new TypeError("Cannot read properties of undefined (reading 'rows')"));
            const el = await mount();
            await ask(el, 'q');
            await flush();
            expect($(el, '[data-error="true"]').textContent).toBe(FIXED_ERROR);
            expect(text(el)).not.toContain('Cannot read properties');
        });
    });

    // 5 (finding 11): the hotkey.
    describe('hotkey', () => {
        async function mountWithComposerSpy() {
            const el = await mount();
            const focus = jest.fn();
            composer(el).focus = focus;
            return { el, focus };
        }

        it('Ctrl-K off Mac opens the utility and focuses the composer, by key code', async () => {
            const { focus } = await mountWithComposerSpy();
            const event = key(document.body, { code: 'KeyK', key: 'л', ctrlKey: true });
            await flush();
            expect(event.defaultPrevented).toBe(true);
            expect(openUtility).toHaveBeenCalledWith('u1', { autoFocus: true });
            expect(focus).toHaveBeenCalled();
        });

        it('ignores Shift, Alt and Cmd off Mac', async () => {
            await mountWithComposerSpy();
            key(document.body, { code: 'KeyK', key: 'K', ctrlKey: true, shiftKey: true });
            key(document.body, { code: 'KeyK', key: 'k', ctrlKey: true, altKey: true });
            key(document.body, { code: 'KeyK', key: 'k', metaKey: true });
            await flush();
            expect(openUtility).not.toHaveBeenCalled();
        });

        it('on Mac takes Cmd-K only and leaves Ctrl-K to the text field', async () => {
            setPlatform('MacIntel');
            const { focus } = await mountWithComposerSpy();
            const ctrl = key(document.body, { code: 'KeyK', key: 'k', ctrlKey: true });
            await flush();
            expect(ctrl.defaultPrevented).toBe(false);
            expect(openUtility).not.toHaveBeenCalled();

            key(document.body, { code: 'KeyK', key: 'k', metaKey: true });
            await flush();
            expect(openUtility).toHaveBeenCalledTimes(1);
            expect(focus).toHaveBeenCalled();
        });

        it('handles Ctrl-K typed inside the composer', async () => {
            const { el } = await mountWithComposerSpy();
            const event = key(composer(el), { code: 'KeyK', key: 'k', ctrlKey: true });
            await flush();
            expect(event.defaultPrevented).toBe(true);
            expect(openUtility).toHaveBeenCalled();
        });

        it('yields to a handler that already prevented the event, and stops after removal', async () => {
            const { el } = await mountWithComposerSpy();
            const blocker = (e) => e.preventDefault();
            document.body.addEventListener('keydown', blocker);
            key(document.body, { code: 'KeyK', key: 'k', ctrlKey: true });
            document.body.removeEventListener('keydown', blocker);
            await flush();
            expect(openUtility).not.toHaveBeenCalled();

            document.body.removeChild(el);
            key(document.body, { code: 'KeyK', key: 'k', ctrlKey: true });
            await flush();
            expect(openUtility).not.toHaveBeenCalled();
        });
    });

    // 6: message channel.
    describe('message channel', () => {
        it('runs a prompt with the message recordId as context, then clears it', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount();
            subscribe.mock.calls[0][2]({ prompt: 'Open deals?', recordId: DEAL });
            await flush();
            expect(explore).toHaveBeenLastCalledWith(expect.objectContaining({ question: 'Open deals?', contextRecordId: DEAL }));
            expect(openUtility).toHaveBeenCalledWith('u1', { autoFocus: true });

            await ask(el, 'And now?');
            await flush();
            expect(explore).toHaveBeenLastCalledWith(expect.objectContaining({ question: 'And now?', contextRecordId: null }));
        });

        it('briefs an Account Id that comes alone', async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(briefResult());
            const el = await mount();
            subscribe.mock.calls[0][2]({ recordId: ACME });
            await flush();
            expect(resolve).toHaveBeenCalledWith({ accountName: null, recordId: ACME });
            expect(getBrief).toHaveBeenCalledWith(expect.objectContaining({ accountId: ACME }));
            expect(text(el)).toContain('Acme is healthy.');
        });
    });

    // 7 (finding 9): history.
    describe('history', () => {
        it('loads on an Account page, names the account, and clears on leaving it', async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            history.mockResolvedValueOnce([{ at: '2026-11-10T10:00:00.000Z', status: 'OK', question: 'Q1', headline: 'Acme headline' }]);
            const el = await mount();
            CurrentPageReference.emit(ACCOUNT_PAGE(ACME));
            await flush();
            expect(history).toHaveBeenCalledWith({ accountId: ACME });
            expect(text(el)).toContain('Acme headline');
            expect($(el, '.abp-history-section').label).toBe('Earlier briefs of Acme (1)');

            CurrentPageReference.emit(HOME_PAGE);
            await flush();
            expect(text(el)).not.toContain('Acme headline');
            expect($(el, '.abp-history-section')).toBeNull();
        });

        it("ignores a late history reply for an account that is no longer current", async () => {
            const lateA = deferred();
            resolve
                .mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' })
                .mockResolvedValueOnce({ status: 'RESOLVED', accountId: BETA, accountName: 'Beta' });
            history
                .mockReturnValueOnce(lateA.promise)
                .mockResolvedValueOnce([{ at: '2026-11-10T10:00:00.000Z', status: 'OK', question: 'QB', headline: 'Beta headline' }]);
            const el = await mount();
            CurrentPageReference.emit(ACCOUNT_PAGE(ACME));
            await flush();
            CurrentPageReference.emit(ACCOUNT_PAGE(BETA));
            await flush();
            lateA.resolve([{ at: '2026-11-09T10:00:00.000Z', status: 'OK', question: 'QA', headline: 'Acme headline' }]);
            await flush();

            expect(text(el)).toContain('Beta headline');
            expect(text(el)).not.toContain('Acme headline');
        });
    });

    // 8 (findings 5 and 7): drill.
    describe('drill', () => {
        const recordDrill = {
            result: { objectName: 'Opportunity', columns: ['Id', 'Name', 'StageName'], rows: [{ Id: DEAL, Name: 'Panel Deal', StageName: 'Prospecting' }], total: 1, shown: 1 },
            related: ['Contact']
        };
        const relatedDrill = {
            result: { objectName: 'Contact', columns: ['Name'], rows: [{ Id: '003000000000001AAA', Name: 'Panelist' }], total: 1, shown: 1 },
            related: []
        };

        it('drills a row through a real button, focuses the heading, pops crumbs, restores the row', async () => {
            explore.mockResolvedValueOnce(dealResult());
            drill.mockResolvedValueOnce(recordDrill).mockResolvedValueOnce(relatedDrill);
            const el = await mount();
            await ask(el, 'deals?');
            await flush();

            const row = $(el, '.abp-row-button');
            expect(row.tagName).toBe('BUTTON'); // native Enter and Space activation
            expect(row.textContent).toBe('Panel Deal');
            expect($(el, 'tr[tabindex]')).toBeNull();
            row.click();
            await flush();

            expect(drill).toHaveBeenCalledWith({ recordId: DEAL, relatedObject: null });
            const heading = $(el, '.abp-drill-heading');
            expect(heading.textContent).toBe('Panel Deal');
            expect(el.shadowRoot.activeElement).toBe(heading);

            $(el, '.abp-related').click();
            await flush();
            expect(drill).toHaveBeenLastCalledWith({ recordId: DEAL, relatedObject: 'Contact' });
            expect($$(el, 'lightning-breadcrumb')).toHaveLength(3);

            $$(el, 'lightning-breadcrumb')[1].dispatchEvent(new CustomEvent('click', { cancelable: true }));
            await flush();
            expect($$(el, 'lightning-breadcrumb')).toHaveLength(2);
            expect($(el, '.abp-drill-heading').textContent).toBe('Panel Deal');

            $$(el, 'lightning-breadcrumb')[0].dispatchEvent(new CustomEvent('click', { cancelable: true }));
            await flush();
            expect($(el, '.abp-drill-heading')).toBeNull();
            expect(el.shadowRoot.activeElement).toBe($(el, '.abp-row-button'));
        });

        it('View record navigates to the drilled record', async () => {
            explore.mockResolvedValueOnce(dealResult());
            drill.mockResolvedValueOnce(recordDrill);
            const el = await mount();
            await ask(el, 'deals?');
            await flush();
            $(el, '.abp-row-button').click();
            await flush();
            $(el, '.abp-view-record').click();
            expect(mockNavigate).toHaveBeenCalledWith({ type: 'standard__recordPage', attributes: { recordId: DEAL, actionName: 'view' } });
        });
    });

    // 9 (findings 5 and 6): keyboard and focus.
    describe('keyboard and focus', () => {
        it('Esc from inside the panel minimizes the utility and returns focus to where Cmd/Ctrl-K came from', async () => {
            const outside = document.createElement('input');
            document.body.appendChild(outside);
            const el = await mount();
            outside.focus();
            key(outside, { code: 'KeyK', key: 'k', ctrlKey: true });
            await flush();
            outside.blur();

            key(composer(el), { key: 'Escape' });
            await flush();
            expect(minimizeUtility).toHaveBeenCalledWith('u1');
            expect(document.activeElement).toBe(outside);
        });

        it('Esc from any control in the panel minimizes, and Tab is never trapped', async () => {
            const el = await mount();
            const send = $(el, '.abp-send');
            const tab = key(send, { key: 'Tab' });
            expect(tab.defaultPrevented).toBe(false);
            key(send, { key: 'Escape' });
            await flush();
            expect(minimizeUtility).toHaveBeenCalledWith('u1');
        });

        it('Enter submits but not mid-IME composition, and Shift-Enter does not submit', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount();
            composer(el).dispatchEvent(new CustomEvent('change', { detail: { value: 'hello' } }));
            await flush();
            key(composer(el), { key: 'Enter', isComposing: true });
            key(composer(el), { key: 'Enter', shiftKey: true });
            expect(explore).not.toHaveBeenCalled();
            key(composer(el), { key: 'Enter' });
            await flush();
            expect(explore).toHaveBeenCalledTimes(1);
        });
    });

    // Findings 4 and 8: announcements and scrolling.
    describe('announcements and layout', () => {
        it('announces the loading and the result in a polite live region', async () => {
            const slow = deferred();
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockReturnValueOnce(slow.promise);
            const el = await mount();
            const live = $(el, '[aria-live="polite"]');
            expect(live).not.toBeNull();

            await ask(el, '/brief Acme');
            await flush();
            expect(live.textContent).toBe('Loading brief for Acme');
            slow.resolve(briefResult());
            await flush();
            expect(live.textContent).toBe('Brief ready: Acme is healthy.');
        });

        it('scrolls the newest turn into view after an answer', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount();
            await ask(el, 'q');
            await flush();
            expect(Element.prototype.scrollIntoView).toHaveBeenCalled();
            const turns = $$(el, '.abp-turn');
            expect(Element.prototype.scrollIntoView.mock.instances.pop()).toBe(turns[turns.length - 1]);
        });
    });

    // 10: automated accessibility checks.
    describe('accessibility', () => {
        it('is accessible empty', async () => {
            const el = await mount();
            await expect(el).toBeAccessible();
        });

        it('is accessible with a brief turn', async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(briefResult());
            const el = await mount();
            await ask(el, '/brief Acme');
            await flush();
            await expect(el).toBeAccessible();
        });

        it('is accessible in the drill view', async () => {
            explore.mockResolvedValueOnce(dealResult());
            drill.mockResolvedValueOnce({
                result: { objectName: 'Opportunity', columns: ['Id', 'Name'], rows: [{ Id: DEAL, Name: 'Panel Deal' }], total: 1, shown: 1 },
                related: ['Contact']
            });
            const el = await mount();
            await ask(el, 'deals?');
            await flush();
            $(el, '.abp-row-button').click();
            await flush();
            await expect(el).toBeAccessible();
        });
    });
});
