import { createElement } from 'lwc';
import CustomerSummaryRail from 'c/customerSummaryRail';
import { subscribe, MessageContext } from 'lightning/messageService';
import { getRecord } from 'lightning/uiRecordApi';
import getContext from '@salesforce/apex/CustomerSummaryContext.getContext';
import listOutcomes from '@salesforce/apex/CustomerOutcomes.listOutcomes';

const mockNavigate = jest.fn();

jest.mock('lightning/navigation', () => {
    const Navigate = Symbol('Navigate');
    const NavigationMixin = (Base) =>
        class extends Base {
            [Navigate](pageRef) {
                mockNavigate(pageRef);
            }
        };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin };
});
jest.mock('@salesforce/apex/CustomerSummaryContext.getContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerOutcomes.listOutcomes', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/messageChannel/CustomerSummaryExpand__c', () => ({ default: 'CustomerSummaryExpand__c' }), { virtual: true });

const ACME = '001000000000001AAA';
const BETA = '001000000000002AAA';
const DEAL = '006000000000001AAA';
const CASE = '500000000000001AAA';
const TASK = '00T000000000001AAA';
const EMAIL = '02s000000000001AAA';
const COMMENT = '00a000000000001AAA';
const HOVER_OPEN_MS = 350;
const PEEK_CLOSE_MS = 400;
const BRAND = { agentName: 'Customer Summary', companyName: 'Acme Corp', logoUrl: '/resource/logo' };

function context(extra) {
    return {
        openDeals: [{ recordId: DEAL, name: 'Renewal 2027', stage: 'Negotiation', amount: 125000, closeDate: '2026-12-15' }],
        recentActivity: [
            { recordId: TASK, kind: 'call', text: 'Pricing call', activityDate: '2026-11-10', who: 'Pat Lee' },
            { recordId: EMAIL, kind: 'email', text: 'Re: renewal terms', activityDate: '2026-11-09', who: null },
            { recordId: COMMENT, kind: 'case_comment', text: 'Customer confirmed the fix', activityDate: '2026-11-08', who: null }
        ],
        openCases: [{ recordId: CASE, caseNumber: '00001027', subject: 'Login fails on SSO', status: 'Working', priority: 'High' }],
        lastSummary: { summaryDate: '2026-11-12T15:00:00.000Z', firstLines: 'Acme is healthy.\nOne renewal is in negotiation.' },
        unavailable: [],
        ...(extra || {})
    };
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

async function flush() {
    for (let i = 0; i < 4; i++) {
        // eslint-disable-next-line no-await-in-loop, @lwc/lwc/no-async-operation
        await new Promise((r) => setTimeout(r, 0));
    }
}

function setPlatform(value) {
    Object.defineProperty(window.navigator, 'platform', { value, configurable: true });
}

function key(target, init) {
    const event = new KeyboardEvent('keydown', { bubbles: true, composed: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
}

const hotkey = (init) => key(document.body, { code: 'KeyK', key: 'K', ctrlKey: true, shiftKey: true, ...init });

async function mount(props) {
    const el = createElement('c-customer-summary-rail', { is: CustomerSummaryRail });
    Object.assign(el, { recordId: ACME, objectApiName: 'Account', brand: BRAND, ...(props || {}) });
    document.body.appendChild(el);
    MessageContext.emit({});
    await flush();
    return el;
}

const $ = (el, sel) => el.shadowRoot.querySelector(sel);
const $$ = (el, sel) => Array.from(el.shadowRoot.querySelectorAll(sel));
const rail = (el) => $(el, 'dialog.cs-rail');
const tab = (el) => $(el, '.cs-rail-tab');
const isOpen = (el) => rail(el).getAttribute('data-open') === 'true';
const section = (el, name) => $(el, '[data-section-body="' + name + '"]');
const sectionText = (el, name) => section(el, name).textContent;
const expandMessage = () => subscribe.mock.calls[0][2];

describe('c-customer-summary-rail', () => {
    beforeEach(() => {
        setPlatform('Win32');
        getContext.mockResolvedValue(context());
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        getContext.mockReset();
        jest.useRealTimers();
    });

    describe('opening', () => {
        it('opens on Ctrl-Shift-K, takes the key, and starts loading the context on the key press', async () => {
            const el = await mount();
            const opens = jest.fn();
            el.addEventListener('railopen', opens);
            expect(isOpen(el)).toBe(false);
            expect(getContext).not.toHaveBeenCalled();

            const event = hotkey();
            // The call goes out in the key handler itself, before any rerender.
            expect(getContext).toHaveBeenCalledWith({ accountId: ACME });
            expect(event.defaultPrevented).toBe(true);
            await flush();
            expect(isOpen(el)).toBe(true);
            expect(el.state).toBe('open');
            expect(opens.mock.calls[0][0].detail).toMatchObject({ source: 'hotkey', focus: true, sessionId: null });
        });

        it('uses Cmd-Shift-K on a Mac and shows that key in the header', async () => {
            setPlatform('MacIntel');
            const el = await mount();
            expect($(el, '.cs-rail-key').textContent).toBe('⌘⇧K');
            expect(rail(el).getAttribute('aria-keyshortcuts')).toBe('Meta+Shift+K');

            hotkey({ ctrlKey: true });
            await flush();
            expect(isOpen(el)).toBe(false);
            hotkey({ ctrlKey: false, metaKey: true });
            await flush();
            expect(isOpen(el)).toBe(true);
        });

        it('shows Ctrl Shift K elsewhere and leaves Ctrl-K, Alt and a handled key alone', async () => {
            const el = await mount();
            expect($(el, '.cs-rail-key').textContent).toBe('Ctrl Shift K');
            expect(rail(el).getAttribute('aria-keyshortcuts')).toBe('Control+Shift+K');
            key(document.body, { code: 'KeyK', key: 'k', ctrlKey: true });
            hotkey({ altKey: true });
            const handled = new KeyboardEvent('keydown', { code: 'KeyK', key: 'K', ctrlKey: true, shiftKey: true, bubbles: true, cancelable: true });
            handled.preventDefault();
            document.body.dispatchEvent(handled);
            await flush();
            expect(isOpen(el)).toBe(false);
            expect(getContext).not.toHaveBeenCalled();
        });

        it('opens from an expand message on the same session', async () => {
            const el = await mount();
            const opens = jest.fn();
            el.addEventListener('railopen', opens);
            expect(subscribe).toHaveBeenCalledTimes(1);
            expect(subscribe.mock.calls[0][1]).toBe('CustomerSummaryExpand__c');

            expandMessage()({ sessionId: 'sess-7', recordId: ACME });
            await flush();
            expect(isOpen(el)).toBe(true);
            expect(opens.mock.calls[0][0].detail).toMatchObject({ sessionId: 'sess-7', recordId: ACME, source: 'expand' });
        });

        it('opens through open() with a session id and ignores a second expand while open', async () => {
            const el = await mount();
            const opens = jest.fn();
            el.addEventListener('railopen', opens);
            el.open({ sessionId: 'sess-9', source: 'expand' });
            await flush();
            expect(opens.mock.calls[0][0].detail.sessionId).toBe('sess-9');
            expandMessage()({ sessionId: 'sess-10' });
            await flush();
            expect(opens).toHaveBeenCalledTimes(1);
        });

        it('moves focus into its main column unless the host places focus itself', async () => {
            const el = await mount();
            el.open({ source: 'hotkey' });
            await flush();
            expect(el.shadowRoot.activeElement).toBe($(el, '.cs-rail-main'));
            el.close();
            const outside = document.createElement('button');
            document.body.appendChild(outside);
            outside.focus();
            await flush();

            el.addEventListener('railopen', (event) => event.preventDefault());
            el.open({ source: 'hotkey' });
            await flush();
            expect(el.shadowRoot.activeElement).not.toBe($(el, '.cs-rail-main'));
            expect(document.activeElement).toBe(outside);
        });

        it('slides over the page as an overlay and never restyles the page underneath', async () => {
            const viewport = document.createElement('div');
            viewport.className = 'viewport';
            document.body.appendChild(viewport);
            const el = await mount();
            hotkey();
            await flush();
            expect(rail(el).classList.contains('cs-rail_overlay')).toBe(true);
            expect(rail(el).classList.contains('cs-rail_push')).toBe(false);
            expect(viewport.getAttribute('style')).toBeNull();
            expect(document.body.getAttribute('style')).toBeNull();
        });

        it('opens as a non-modal dialog', async () => {
            const proto = window.HTMLDialogElement.prototype;
            const show = jest.fn(function show() {
                this.setAttribute('open', '');
            });
            const close = jest.fn(function close() {
                this.removeAttribute('open');
            });
            const showModal = jest.fn();
            Object.assign(proto, { show, close, showModal });
            try {
                const el = await mount();
                hotkey();
                await flush();
                expect(show).toHaveBeenCalledTimes(1);
                expect(showModal).not.toHaveBeenCalled();
                el.close();
                expect(close).toHaveBeenCalledTimes(1);
            } finally {
                delete proto.show;
                delete proto.close;
                delete proto.showModal;
            }
        });
    });

    describe('header', () => {
        it('shows the brand logo, the agent name and the key hint', async () => {
            const el = await mount();
            const logo = $(el, '.cs-rail-logo');
            expect(logo.getAttribute('src')).toBe('/resource/logo');
            expect(logo.getAttribute('alt')).toBe('Acme Corp logo');
            expect($(el, '.cs-rail-name').textContent).toBe('Customer Summary');
            expect(rail(el).getAttribute('aria-label')).toBe('Customer Summary side panel');
            expect($(el, '.cs-rail-key')).not.toBeNull();
        });

        it('falls back to a neutral name with no logo', async () => {
            const el = await mount({ brand: null });
            expect($(el, '.cs-rail-logo')).toBeNull();
            expect($(el, '.cs-rail-name').textContent).toBe('Assistant');
        });

        it('heads the context with the account name when it can read it', async () => {
            const el = await mount();
            getRecord.emit({ apiName: 'Account', fields: { Name: { value: 'Acme Corp' } } });
            await flush();
            expect($(el, '.cs-ctx-heading').textContent).toBe('About Acme Corp');
        });
    });

    describe('closing, minimizing and hover', () => {
        it('closes on Esc and gives focus back to where it came from', async () => {
            const outside = document.createElement('button');
            outside.textContent = 'Outside';
            document.body.appendChild(outside);
            outside.focus();
            const el = await mount();
            const closes = jest.fn();
            el.addEventListener('railclose', closes);
            hotkey();
            await flush();
            expect(el.shadowRoot.activeElement).toBe($(el, '.cs-rail-main'));

            key($(el, '.cs-rail-main'), { key: 'Escape' });
            await flush();
            expect(isOpen(el)).toBe(false);
            expect(closes.mock.calls[0][0].detail).toEqual({ hadFocus: true, restored: true });
            expect(document.activeElement).toBe(outside);
        });

        it('leaves Esc alone during an IME composition', async () => {
            const el = await mount();
            hotkey();
            await flush();
            key($(el, '.cs-rail-main'), { key: 'Escape', isComposing: true });
            await flush();
            expect(isOpen(el)).toBe(true);
        });

        it('closes from its close button', async () => {
            const el = await mount();
            hotkey();
            await flush();
            $(el, 'lightning-button-icon[data-action="close"]').click();
            await flush();
            expect(el.state).toBe('closed');
            expect(tab(el).classList.contains('cs-rail-tab_shown')).toBe(false);
        });

        it('minimizes to a slim edge tab and moves focus to it', async () => {
            const el = await mount();
            const minimized = jest.fn();
            el.addEventListener('railminimize', minimized);
            hotkey();
            await flush();
            expect(tab(el).classList.contains('cs-rail-tab_shown')).toBe(false);

            $(el, 'lightning-button-icon[data-action="minimize"]').click();
            await flush();
            expect(el.state).toBe('minimized');
            expect(isOpen(el)).toBe(false);
            expect(minimized).toHaveBeenCalledTimes(1);
            expect(tab(el).classList.contains('cs-rail-tab_shown')).toBe(true);
            expect(tab(el).getAttribute('aria-label')).toBe('Open the Customer Summary side panel');
            expect(el.shadowRoot.activeElement).toBe(tab(el));

            tab(el).click();
            await flush();
            expect(el.state).toBe('open');
        });

        it('opens on hover of the tab after a short delay, as a peek that slides back when the pointer leaves', async () => {
            const el = await mount();
            const opens = jest.fn();
            el.addEventListener('railopen', opens);
            el.open();
            el.minimize();
            await flush();
            jest.useFakeTimers();

            tab(el).dispatchEvent(new CustomEvent('mouseenter'));
            jest.advanceTimersByTime(HOVER_OPEN_MS - 50);
            expect(el.state).toBe('minimized');
            jest.advanceTimersByTime(50);
            expect(el.state).toBe('open');
            expect(opens.mock.calls[1][0].detail).toMatchObject({ source: 'hover', focus: false });

            rail(el).dispatchEvent(new CustomEvent('mouseleave'));
            jest.advanceTimersByTime(PEEK_CLOSE_MS);
            expect(el.state).toBe('minimized');
        });

        it('slides a peek back when the pointer leaves the sliding tab without entering the rail, and stays if it enters', async () => {
            const el = await mount();
            el.open();
            el.minimize();
            await flush();
            jest.useFakeTimers();
            tab(el).dispatchEvent(new CustomEvent('mouseenter'));
            jest.advanceTimersByTime(HOVER_OPEN_MS);
            expect(el.state).toBe('open');
            tab(el).dispatchEvent(new CustomEvent('mouseleave'));
            jest.advanceTimersByTime(PEEK_CLOSE_MS);
            expect(el.state).toBe('minimized');

            tab(el).dispatchEvent(new CustomEvent('mouseenter'));
            jest.advanceTimersByTime(HOVER_OPEN_MS);
            tab(el).dispatchEvent(new CustomEvent('mouseleave'));
            rail(el).dispatchEvent(new CustomEvent('mouseenter'));
            jest.advanceTimersByTime(PEEK_CLOSE_MS * 2);
            expect(el.state).toBe('open');
        });

        it('does not open when the pointer only passes over the tab', async () => {
            const el = await mount();
            el.open();
            el.minimize();
            await flush();
            jest.useFakeTimers();
            tab(el).dispatchEvent(new CustomEvent('mouseenter'));
            jest.advanceTimersByTime(100);
            tab(el).dispatchEvent(new CustomEvent('mouseleave'));
            jest.advanceTimersByTime(HOVER_OPEN_MS * 2);
            expect(el.state).toBe('minimized');
        });

        it('keeps a peek open once the rep clicks into it', async () => {
            const el = await mount();
            el.open();
            el.minimize();
            await flush();
            jest.useFakeTimers();
            tab(el).dispatchEvent(new CustomEvent('mouseenter'));
            jest.advanceTimersByTime(HOVER_OPEN_MS);
            rail(el).dispatchEvent(new CustomEvent('pointerdown', { bubbles: true }));
            rail(el).dispatchEvent(new CustomEvent('mouseleave'));
            jest.advanceTimersByTime(PEEK_CLOSE_MS * 2);
            expect(el.state).toBe('open');
        });
    });

    describe('context', () => {
        it('shows skeletons, never a blank block, while the context loads', async () => {
            const pending = deferred();
            getContext.mockReturnValue(pending.promise);
            const el = await mount();
            hotkey();
            await flush();
            for (const name of ['deals', 'activity', 'cases', 'summary']) {
                expect(section(el, name).querySelectorAll('.cs-ctx-skeleton').length).toBeGreaterThan(0);
                expect(section(el, name).getAttribute('aria-busy')).toBe('true');
            }
            pending.resolve(context());
            await flush();
            expect($$(el, '.cs-ctx-skeleton')).toHaveLength(0);
            expect($(el, '.cs-ctx-status').textContent).toBe('Account details loaded');
        });

        it('lists open deals, recent activity with each kind, open cases and the last summary', async () => {
            const el = await mount();
            hotkey();
            await flush();
            expect(sectionText(el, 'deals')).toContain('Renewal 2027');
            expect(sectionText(el, 'deals')).toContain('Negotiation');
            const kinds = Array.from(section(el, 'activity').querySelectorAll('.cs-ctx-kind')).map((n) => n.textContent);
            expect(kinds).toEqual(['Call', 'Email', 'Case comment']);
            expect(sectionText(el, 'activity')).toContain('Pricing call');
            expect(sectionText(el, 'activity')).toContain('Pat Lee');
            expect(sectionText(el, 'cases')).toContain('Login fails on SSO');
            expect(sectionText(el, 'cases')).toContain('Case 00001027');
            expect(sectionText(el, 'cases')).toContain('High priority');
            const lines = Array.from(section(el, 'summary').querySelectorAll('.cs-ctx-summary-line')).map((n) => n.textContent);
            expect(lines).toEqual(['Acme is healthy.', 'One renewal is in negotiation.']);
            expect($(el, '[data-count="deals"]').textContent).toBe('1');
            expect($(el, '[data-count="activity"]').textContent).toBe('3');
        });

        it('shows the empty state for each list with nothing in it', async () => {
            getContext.mockResolvedValue(context({ openDeals: [], recentActivity: [], openCases: [], lastSummary: null }));
            const el = await mount();
            hotkey();
            await flush();
            expect(sectionText(el, 'deals')).toContain('No open deals.');
            expect(sectionText(el, 'activity')).toContain('No recent activity.');
            expect(sectionText(el, 'cases')).toContain('No open cases.');
            expect(sectionText(el, 'summary')).toContain('No summary of this account yet.');
        });

        it('says when the rep cannot read a part, and names the hidden activity sources', async () => {
            getContext.mockResolvedValue(
                context({ openDeals: [], openCases: [], lastSummary: null, unavailable: ['openDeals', 'openCases', 'lastSummary', 'emails'] })
            );
            const el = await mount();
            hotkey();
            await flush();
            for (const name of ['deals', 'cases', 'summary']) {
                expect(sectionText(el, name)).toContain("Your access doesn't include this.");
            }
            expect(sectionText(el, 'activity')).toContain("your access doesn't include emails");
            expect($(el, '[data-count="deals"]')).toBeNull();
        });

        it('shows one fixed sentence and Retry when the call fails, and Retry loads again', async () => {
            getContext.mockRejectedValueOnce({ body: { message: 'System.QueryException: secret detail' } });
            const el = await mount();
            hotkey();
            await flush();
            const error = $(el, '.cs-ctx-error');
            expect(error.textContent).toContain("Couldn't load this account's details. Try again in a minute.");
            expect(el.shadowRoot.textContent).not.toContain('QueryException');

            getContext.mockResolvedValue(context());
            $(el, 'lightning-button[data-action="retry"]').click();
            await flush();
            expect(getContext).toHaveBeenCalledTimes(2);
            expect($(el, '.cs-ctx-error')).toBeNull();
            expect(sectionText(el, 'deals')).toContain('Renewal 2027');
        });

        it('asks the rep to open an account when the page is not one, and makes no call', async () => {
            const el = await mount({ recordId: null });
            hotkey();
            await flush();
            expect($(el, '.cs-ctx-none').textContent).toContain('Open an account to see');
            expect(getContext).not.toHaveBeenCalled();
        });

        it('keeps its account while the rep opens a deal from it, and loads the next account', async () => {
            const el = await mount();
            hotkey();
            await flush();
            el.recordId = DEAL;
            await flush();
            expect(getContext).toHaveBeenCalledTimes(1);
            expect(sectionText(el, 'deals')).toContain('Renewal 2027');
            el.recordId = BETA;
            await flush();
            expect(getContext).toHaveBeenLastCalledWith({ accountId: BETA });
        });

        it('loads once: a second open of the same account uses what it has', async () => {
            const el = await mount();
            hotkey();
            await flush();
            el.close();
            hotkey();
            await flush();
            expect(getContext).toHaveBeenCalledTimes(1);
        });

        it('opens the record behind a deal, a case and an activity, and puts no record Id in the markup', async () => {
            const el = await mount();
            hotkey();
            await flush();
            section(el, 'deals').querySelector('button.cs-ctx-item').click();
            section(el, 'cases').querySelector('button.cs-ctx-item').click();
            section(el, 'activity').querySelectorAll('button.cs-ctx-item')[1].click();
            const ids = mockNavigate.mock.calls.map((c) => c[0].attributes.recordId);
            expect(ids).toEqual([DEAL, CASE, EMAIL]);
            expect(mockNavigate.mock.calls[0][0]).toEqual({ type: 'standard__recordPage', attributes: { recordId: DEAL, actionName: 'view' } });
            const markup = el.shadowRoot.innerHTML;
            for (const id of [ACME, DEAL, CASE, TASK, EMAIL, COMMENT]) {
                expect(markup).not.toContain(id);
            }
        });

        it('hands the record to a host that takes railopenrecord, and then does not navigate itself', async () => {
            const el = await mount();
            const asked = jest.fn((event) => event.preventDefault());
            el.addEventListener('railopenrecord', asked);
            hotkey();
            await flush();
            section(el, 'deals').querySelector('button.cs-ctx-item').click();
            expect(asked).toHaveBeenCalledTimes(1);
            expect(asked.mock.calls[0][0].detail).toEqual({ recordId: DEAL });
            expect(mockNavigate).not.toHaveBeenCalled();
        });

        it('collapses and expands a section', async () => {
            const el = await mount();
            hotkey();
            await flush();
            const toggle = $(el, 'button[data-section="cases"]');
            expect(toggle.getAttribute('aria-expanded')).toBe('true');
            toggle.click();
            await flush();
            expect(toggle.getAttribute('aria-expanded')).toBe('false');
            expect(section(el, 'cases').classList.contains('slds-hide')).toBe(true);
            toggle.click();
            await flush();
            expect(toggle.getAttribute('aria-expanded')).toBe('true');
        });
    });

    describe('accessibility', () => {
        it('has no axe violations open with its context', async () => {
            const el = await mount();
            hotkey();
            await flush();
            await expect(el).toBeAccessible();
        });

        it('has no axe violations minimized, loading or in error', async () => {
            const pending = deferred();
            getContext.mockReturnValue(pending.promise);
            const el = await mount();
            hotkey();
            await flush();
            await expect(el).toBeAccessible();
            pending.reject(new Error('x'));
            await flush();
            await expect(el).toBeAccessible();
            el.minimize();
            await flush();
            await expect(el).toBeAccessible();
        });
    });

    describe('history and sentiment (FE-19)', () => {
        const history = (el) => $(el, 'c-customer-summary-history-timeline');
        const chart = (el) => $(el, 'c-customer-summary-sentiment-chart');

        const toggle = (el) => $(el, '[data-testid="ctx-history"] button.cs-ctx-toggle');

        it('History is closed by default: a header button with aria-expanded=false, and no timeline, chart or outcomes call', async () => {
            const el = await mount();
            listOutcomes.mockClear();
            hotkey();
            await flush();
            const btn = toggle(el);
            expect(btn).not.toBeNull();
            expect(btn.getAttribute('aria-expanded')).toBe('false');
            expect(btn.getAttribute('aria-controls')).toBeTruthy();
            const body = $(el, '[data-history-body]');
            expect(body.id).toBe(btn.getAttribute('aria-controls'));
            expect(body.className).toContain('slds-hide');
            // The four context sections keep their own marker: History's body is not one of them.
            const bodies = $$(el, '[data-section-body]');
            expect(bodies.map((b) => b.getAttribute('data-section-body')).sort()).toEqual(['activity', 'cases', 'deals', 'summary']);
            expect(bodies.every((b) => b.hasAttribute('aria-busy'))).toBe(true);
            expect(history(el)).toBeNull();
            expect(chart(el)).toBeNull();
            expect(listOutcomes).not.toHaveBeenCalled();
        });

        it('opening History loads the timeline and the chart on the rail\'s account, inside the context column; closing it removes them', async () => {
            listOutcomes.mockResolvedValue([]);
            const el = await mount();
            hotkey();
            await flush();
            const btn = toggle(el);
            btn.click();
            await flush();
            expect(btn.getAttribute('aria-expanded')).toBe('true');
            expect(history(el).recordId).toBe(ACME);
            expect(chart(el).recordId).toBe(ACME);
            expect($(el, '.cs-rail-context, aside.cs-rail-context').contains(history(el))).toBe(true);
            expect(listOutcomes).toHaveBeenCalled();
            toggle(el).click();
            await flush();
            expect(toggle(el).getAttribute('aria-expanded')).toBe('false');
            expect(history(el)).toBeNull();
            expect(chart(el)).toBeNull();
        });

        it('shows the entry count on the History header once the timeline has loaded it', async () => {
            listOutcomes.mockResolvedValue([
                { id: 'a0C000000000001AAA', type: 'Summary', createdDate: '2026-11-01T15:00:00.000Z', textShown: true, title: 'One' },
                { id: 'a0C000000000002AAA', type: 'Summary', createdDate: '2026-11-02T15:00:00.000Z', textShown: true, title: 'Two' },
                { id: 'a0C000000000003AAA', type: 'Summary', createdDate: '2026-11-03T15:00:00.000Z', textShown: true, title: 'Three' }
            ]);
            const el = await mount();
            hotkey();
            await flush();
            expect($(el, '[data-count="history"]')).toBeNull();
            toggle(el).click();
            await flush();
            expect($(el, '[data-count="history"]').textContent).toBe('3');
        });

        it('an account change closes History and drops the previous account\'s count', async () => {
            listOutcomes.mockReset();
            listOutcomes.mockResolvedValue([
                { id: 'a0C000000000001AAA', type: 'Summary', createdDate: '2026-11-01T15:00:00.000Z', textShown: true, title: 'One' },
                { id: 'a0C000000000002AAA', type: 'Summary', createdDate: '2026-11-02T15:00:00.000Z', textShown: true, title: 'Two' },
                { id: 'a0C000000000003AAA', type: 'Summary', createdDate: '2026-11-03T15:00:00.000Z', textShown: true, title: 'Three' }
            ]);
            const el = await mount();
            hotkey();
            await flush();
            toggle(el).click();
            await flush();
            expect($(el, '[data-count="history"]').textContent).toBe('3');
            el.recordId = BETA;
            await flush();
            expect(toggle(el).getAttribute('aria-expanded')).toBe('false');
            expect($(el, '[data-count="history"]')).toBeNull();
            expect(history(el)).toBeNull();
            expect(chart(el)).toBeNull();
        });

        it('a count that arrives late from the previous account is ignored, and the reopened History shows the new account\'s count', async () => {
            listOutcomes.mockReset();
            const late = deferred();
            let acmeTimeline = true;
            listOutcomes.mockImplementation((args) => {
                if (args.types === null && acmeTimeline) {
                    acmeTimeline = false;
                    return late.promise;
                }
                return Promise.resolve([]);
            });
            const el = await mount();
            hotkey();
            await flush();
            toggle(el).click();
            await flush();
            el.recordId = BETA;
            await flush();
            late.resolve([{ id: 'a0C000000000009AAA', type: 'Summary', createdDate: '2026-11-09T15:00:00.000Z', textShown: true, title: 'Old' }]);
            await flush();
            expect($(el, '[data-count="history"]')).toBeNull();
            expect(toggle(el).getAttribute('aria-expanded')).toBe('false');
            toggle(el).click();
            await flush();
            expect(history(el).recordId).toBe(BETA);
            expect($(el, '[data-count="history"]').textContent).toBe('0');
        });

        it('shows neither without an account', async () => {
            const el = await mount({ recordId: null, objectApiName: 'Contact' });
            hotkey();
            await flush();
            expect(history(el)).toBeNull();
            expect(chart(el)).toBeNull();
        });
    });
});
