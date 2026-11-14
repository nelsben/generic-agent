import { createElement } from 'lwc';
import CustomerSummaryConversation from 'c/customerSummaryConversation';
import resolve from '@salesforce/apex/CustomerSummaryPanelController.resolve';
import getBrief from '@salesforce/apex/CustomerSummaryPanelController.getBrief';
import explore from '@salesforce/apex/CustomerSummaryPanelController.explore';
import drill from '@salesforce/apex/CustomerSummaryPanelController.drill';
import history from '@salesforce/apex/CustomerSummaryPanelController.history';
import sources from '@salesforce/apex/CustomerSummaryPanelController.sources';

const fs = require('fs');
const path = require('path');

jest.mock('lightning/navigation', () => {
    const Navigate = Symbol('Navigate');
    const NavigationMixin = (Base) =>
        class extends Base {
            [Navigate]() {}
        };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin };
});

jest.mock('@salesforce/apex/CustomerSummaryPanelController.resolve', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.getBrief', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.explore', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.drill', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/CustomerSummaryPanelController.history', () => ({ default: jest.fn() }), { virtual: true });
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

const FIXED_ERROR = "I couldn't finish that right now. Try again in a minute.";
const ACME = '001000000000001AAA';
const DEAL = '006000000000001AAA';
const DEAL2 = '006000000000002AAA';
const DEAL3 = '006000000000003AAA';
const BRAND = {
    agentName: 'Northwind Assist',
    companyName: 'Northwind Health',
    logoUrl: '/resource/BrandLogo'
};

async function flush() {
    for (let i = 0; i < 4; i++) {
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

function exploreResult(answer, extra) {
    return { status: 'OK', answer, resultSets: [], trail: [], followups: [], ...(extra || {}) };
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

async function mount(props) {
    const el = createElement('c-customer-summary-conversation', { is: CustomerSummaryConversation });
    Object.assign(el, props || {});
    document.body.appendChild(el);
    sources.emit([{ key: 'profile', title: 'Profile' }]);
    await flush();
    return el;
}

async function mountOnAccount(extra) {
    resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
    return mount({ recordId: ACME, objectApiName: 'Account', brand: BRAND, ...(extra || {}) });
}

const $ = (el, sel) => el.shadowRoot.querySelector(sel);
const $$ = (el, sel) => Array.from(el.shadowRoot.querySelectorAll(sel));
const composer = (el) => $(el, 'textarea.abp-composer');
const chipLabels = (el) => $$(el, '.abp-quick').map((b) => b.textContent.trim());

async function type(el, value) {
    const box = composer(el);
    box.value = value;
    box.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
    await flush();
}

function key(target, init) {
    const event = new KeyboardEvent('keydown', { bubbles: true, composed: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
}

async function ask(el, question) {
    await type(el, question);
    key(composer(el), { key: 'Enter' });
    await flush();
}

describe('c-customer-summary-conversation', () => {
    beforeEach(() => {
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

    describe('public interface', () => {
        it('is written at the top of the JavaScript file', () => {
            const header = SOURCE_JS.slice(0, SOURCE_JS.indexOf('import '));
            ['@api recordId', '@api sessionId', '@api focusComposer()', 'sessionchange'].forEach((part) => {
                expect(header).toContain(part);
            });
        });

        it('recordId: resolves the account and names it in the empty state', async () => {
            const el = await mountOnAccount();
            expect(resolve).toHaveBeenCalledWith({ accountName: null, recordId: ACME });
            expect($(el, '.abp-empty-title').textContent).toBe('Ask Northwind Assist about Acme');
            expect($(el, '.abp-empty').textContent).toContain('Northwind Health');
        });

        it('recordId: a question runs with it as context', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mountOnAccount();
            await ask(el, 'Who owns it?');
            expect(explore).toHaveBeenCalledWith(expect.objectContaining({ question: 'Who owns it?', contextRecordId: ACME }));
        });

        it('sessionId: fires sessionchange with a new id on the first request only', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount();
            const handler = jest.fn();
            el.addEventListener('sessionchange', handler);
            expect(el.sessionId).toBeFalsy();
            await ask(el, 'one');
            expect(handler).toHaveBeenCalledTimes(1);
            const id = handler.mock.calls[0][0].detail.sessionId;
            expect(id).toBeTruthy();
            expect(el.sessionId).toBe(id);
            await ask(el, 'two');
            expect(handler).toHaveBeenCalledTimes(1);
        });

        it('sessionId: keeps an id the host sets and fires no event for it', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount({ sessionId: 'host-session' });
            const handler = jest.fn();
            el.addEventListener('sessionchange', handler);
            await ask(el, 'one');
            expect(el.sessionId).toBe('host-session');
            expect(handler).not.toHaveBeenCalled();
        });

        it('focusComposer() moves focus to the composer', async () => {
            const el = await mount();
            el.focusComposer();
            expect(el.shadowRoot.activeElement).toBe(composer(el));
        });

        it('ask() and summarize() run a question and a brief for the host', async () => {
            explore.mockResolvedValue(exploreResult('Asked.'));
            const el = await mount();
            await el.ask('Open deals?', DEAL);
            await flush();
            expect(explore).toHaveBeenCalledWith(expect.objectContaining({ question: 'Open deals?', contextRecordId: DEAL }));

            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(briefResult());
            await el.summarize(ACME);
            await flush();
            expect(getBrief).toHaveBeenCalledWith(expect.objectContaining({ accountId: ACME }));
        });
    });

    describe('thread', () => {
        it('renders one exchange per request: a YOU note and the agent turn labelled with its name', async () => {
            explore.mockResolvedValue(exploreResult('Two contacts.'));
            const el = await mount({ brand: BRAND });
            await ask(el, 'How many contacts?');

            const turns = $$(el, '[data-turn]');
            expect(turns).toHaveLength(1);
            const you = turns[0].querySelector('.abp-you');
            expect(you.querySelector('.abp-label').textContent).toBe('You');
            expect(you.querySelector('.abp-question').textContent).toBe('How many contacts?');
            const reply = turns[0].querySelector('.abp-reply');
            expect(reply.querySelector('.abp-label').textContent).toBe('Northwind Assist');
            expect(reply.dataset.kind).toBe('explore');
            expect(reply.textContent).toContain('Two contacts.');
        });

        it('shows a pulsing pending turn at once, announced politely, then replaces it with the answer', async () => {
            const slow = deferred();
            explore.mockReturnValueOnce(slow.promise);
            const el = await mount({ brand: BRAND });
            await ask(el, 'Slow one');

            const pending = $(el, '[data-testid="abp-spinner"]');
            expect(pending).not.toBeNull();
            expect(pending.classList.contains('abp-pulse') || !!pending.querySelector('.abp-pulse')).toBe(true);
            expect(pending.textContent).toContain('Slow one');
            expect(pending.hasAttribute('data-turn')).toBe(false);
            expect($(el, '[aria-live="polite"]').textContent).toBe('Loading answer');

            slow.resolve(exploreResult('Done.'));
            await flush();
            expect($(el, '[data-testid="abp-spinner"]')).toBeNull();
            expect($$(el, '[data-turn]')).toHaveLength(1);
            expect($(el, '.abp-reply').textContent).toContain('Done.');
        });

        it('a superseded request leaves nothing behind', async () => {
            const first = deferred();
            explore.mockReturnValueOnce(first.promise).mockResolvedValueOnce(exploreResult('Second.'));
            const el = await mount();
            await ask(el, 'first question');
            await ask(el, 'second question');
            first.resolve(exploreResult('First.'));
            await flush();
            expect($$(el, '[data-turn]')).toHaveLength(1);
            expect(el.shadowRoot.textContent).not.toContain('first question');
        });

        it('shows an error turn with the fixed text, an Error label and no platform text', async () => {
            explore.mockRejectedValueOnce(new TypeError('Cannot read properties of undefined'));
            const el = await mount();
            await ask(el, 'q');
            const reply = $(el, '.abp-reply');
            expect(reply.classList.contains('abp-reply-error')).toBe(true);
            expect(reply.querySelector('.abp-label').textContent).toBe('Error');
            expect(reply.querySelector('[data-error="true"]').textContent).toBe(FIXED_ERROR);
            expect(el.shadowRoot.textContent).not.toContain('Cannot read properties');
        });

        it('speaks the fixed sentence in the live region and the error turn when the platform rejects with its own text', async () => {
            explore.mockRejectedValueOnce({ body: { message: 'Disconnected or Canceled' } });
            const el = await mount();
            await ask(el, 'q');
            expect($(el, '[data-testid="abp-live-region"]').textContent).toBe(FIXED_ERROR);
            expect($(el, '.abp-reply [data-error="true"]').textContent).toBe(FIXED_ERROR);
            expect(el.shadowRoot.textContent).not.toContain('Disconnected or Canceled');
        });

        it('renders rich text by runs: strong, em and plain spans, never as HTML', async () => {
            explore.mockResolvedValue(exploreResult('**Acme** is *growing* <b>fast</b>'));
            const el = await mount();
            await ask(el, 'q');
            const answer = $(el, '.abp-answer');
            expect(answer.querySelector('strong').textContent).toBe('Acme');
            expect(answer.querySelector('em').textContent).toBe('growing');
            expect(answer.querySelector('b')).toBeNull();
            expect(answer.textContent).toBe('Acme is growing <b>fast</b>');
            expect(SOURCE_HTML).not.toContain('inner-html');
        });

        it('auto-scrolls to the newest turn unless the user has scrolled up', async () => {
            const slow = deferred();
            explore.mockResolvedValueOnce(exploreResult('One.')).mockReturnValueOnce(slow.promise);
            const el = await mount();
            const body = $(el, '.abp-body');
            let top = 300;
            Object.defineProperty(body, 'scrollTop', { get: () => top, configurable: true });
            Object.defineProperty(body, 'scrollHeight', { get: () => 1000, configurable: true });
            Object.defineProperty(body, 'clientHeight', { get: () => 200, configurable: true });

            await ask(el, 'one');
            const scrolled = Element.prototype.scrollIntoView.mock.instances.pop();
            expect(scrolled).toBe($$(el, '[data-turn]').pop());

            await ask(el, 'two');
            Element.prototype.scrollIntoView.mockClear();
            top = 20;
            body.dispatchEvent(new CustomEvent('scroll'));
            slow.resolve(exploreResult('Two.'));
            await flush();
            expect(Element.prototype.scrollIntoView).not.toHaveBeenCalled();
        });
    });

    describe('cards', () => {
        it('titles a capped table "Showing 50 of N rows", collapses the query trail and sends a follow-up chip', async () => {
            const rows = Array.from({ length: 50 }, (_, i) => ({ Id: DEAL, Name: 'Deal ' + i }));
            explore
                .mockResolvedValueOnce(
                    exploreResult('Many deals.', {
                        resultSets: [{ objectName: 'Opportunity', columns: ['Name'], rows, total: 120, shown: 50 }],
                        trail: ['Opportunity | 120 rows'],
                        followups: ['Which close this quarter?']
                    })
                )
                .mockResolvedValueOnce(exploreResult('Three.'));
            const el = await mount();
            await ask(el, 'deals?');

            expect($(el, '.abp-table-title').textContent).toBe('Opportunity · Showing 50 of 120 rows');
            const trail = $(el, 'lightning-accordion-section.abp-trail');
            expect(trail.label).toBe('Ran 1 query');
            $(el, '.abp-chip').click();
            await flush();
            expect(explore).toHaveBeenLastCalledWith(expect.objectContaining({ question: 'Which close this quarter?' }));
        });

        it('marks each agent turn with its kind for the card renderers', async () => {
            resolve.mockResolvedValueOnce({ status: 'NOT_FOUND', message: 'No match.' });
            const el = await mount();
            await ask(el, '/brief Zed');
            expect($(el, '.abp-reply').dataset.kind).toBe('text');
            ['actionDraft', 'actionResult'].forEach((kind) => expect(SOURCE_JS).toContain("'" + kind + "'"));
        });
    });

    describe('composer', () => {
        it('Enter sends, Shift-Enter does not, and the draft clears', async () => {
            explore.mockResolvedValue(exploreResult('Answer.'));
            const el = await mount();
            await type(el, 'hello');
            key(composer(el), { key: 'Enter', shiftKey: true });
            await flush();
            expect(explore).not.toHaveBeenCalled();
            key(composer(el), { key: 'Enter' });
            await flush();
            expect(explore).toHaveBeenCalledTimes(1);
            expect(composer(el).value).toBe('');
        });

        it('stops key propagation while typing, except Esc and the hotkey for the host', async () => {
            const el = await mount();
            const seen = jest.fn();
            document.addEventListener('keydown', seen);
            key(composer(el), { key: 'g' });
            key(composer(el), { key: 'Enter', shiftKey: true });
            expect(seen).not.toHaveBeenCalled();
            key(composer(el), { key: 'Escape' });
            expect(seen).toHaveBeenCalledTimes(1);
            document.removeEventListener('keydown', seen);
        });

        it('keeps Esc inside while an IME composition is open', async () => {
            const el = await mount();
            const seen = jest.fn();
            document.addEventListener('keydown', seen);
            const event = key(composer(el), { key: 'Escape', isComposing: true });
            expect(seen).not.toHaveBeenCalled();
            expect(event.defaultPrevented).toBe(false);
            document.removeEventListener('keydown', seen);
        });

        it('puts the mic on the composer row, named for the agent, and its transcript fills the composer without sending', async () => {
            const el = await mount({ brand: BRAND });
            const mic = $(el, '.abp-composer-row c-customer-summary-voice-input');
            expect(mic).not.toBeNull();
            expect(mic.agentName).toBe('Northwind Assist');

            await type(el, 'About');
            mic.dispatchEvent(new CustomEvent('recordingstate', { detail: { recording: true } }));
            mic.dispatchEvent(new CustomEvent('transcriptupdate', { detail: { transcript: 'open deals' } }));
            await flush();
            expect(composer(el).value).toBe('About open deals');
            mic.dispatchEvent(new CustomEvent('transcriptfinal', { detail: { transcript: 'open deals' } }));
            await flush();
            expect(composer(el).value).toBe('About open deals');
            expect(explore).not.toHaveBeenCalled();
            expect($(el, '.abp-send').disabled).toBe(false);
        });

        it('lets the composer shrink: min-width 0', () => {
            expect(SOURCE_CSS).toMatch(/\.abp-composer\s*\{[^}]*min-width:\s*0/);
        });

        it('uses the short placeholder that matches its accessible name', async () => {
            const el = await mount();
            expect(composer(el).getAttribute('placeholder')).toBe('Ask or /brief an account');
            expect(composer(el).getAttribute('aria-label')).toBe('Ask or /brief an account');
        });

        it('drops the brand fill from Send while it is disabled', async () => {
            const el = await mount();
            expect($(el, '.abp-send').disabled).toBe(true);
            const rule = SOURCE_CSS.match(/\.abp-send\.slds-button_brand:disabled[^{]*\{([^}]*)\}/);
            expect(rule).not.toBeNull();
            const body = rule[1];
            expect(body).toMatch(/background-color:\s*var\(--cs-color-surface, #ffffff\)/);
            expect(body).toMatch(/border:\s*1px solid color-mix\(in srgb, var\(--cs-color-ink, #181818\) 18%, transparent\)/);
            expect(body).toMatch(/color:\s*color-mix\(in srgb, var\(--cs-color-ink, #181818\) 50%, var\(--cs-color-surface, #ffffff\)\)/);
            expect(body).toMatch(/cursor:\s*default/);
            expect(body).not.toMatch(/--cs-color-primary/);
        });
    });

    describe('quick actions', () => {
        it('on an account: Summarize, Open deals and Recent activity, then the write actions (FE-14)', async () => {
            const el = await mountOnAccount();
            expect(chipLabels(el)).toEqual(['Summarize', 'Open deals', 'Recent activity', 'Create a follow-up', 'Log a call']);
        });

        it('on an account the chips brief it and ask about it', async () => {
            const el = await mountOnAccount();
            getBrief.mockResolvedValueOnce(briefResult());
            $$(el, '.abp-quick')[0].click();
            await flush();
            expect(getBrief).toHaveBeenCalledWith(expect.objectContaining({ accountId: ACME }));

            explore.mockResolvedValueOnce(exploreResult('Deals.'));
            $$(el, '.abp-quick')[1].click();
            await flush();
            expect(explore).toHaveBeenLastCalledWith(expect.objectContaining({ question: 'Which open deals does Acme have?', contextRecordId: ACME }));
        });

        it("off an account: Ask anything, then the last account's summary", async () => {
            const el = await mount();
            expect(chipLabels(el)).toEqual(['Ask anything']);
            $(el, '.abp-quick').click();
            expect(el.shadowRoot.activeElement).toBe(composer(el));

            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(briefResult());
            await ask(el, '/brief Acme');
            expect(chipLabels(el)).toEqual(['Ask anything', 'Summarize Acme']);
        });
    });

    describe('brand', () => {
        it('shows the logo beside the agent name in the header, and no image without a logo', async () => {
            const el = await mount({ brand: BRAND });
            const row = $(el, '.abp-bar .abp-bar-row');
            expect(row.querySelector('img.abp-logo').getAttribute('src')).toBe('/resource/BrandLogo');
            expect(row.querySelector('.abp-agent-name').textContent).toBe('Northwind Assist');

            el.brand = { ...BRAND, logoUrl: '' };
            await flush();
            expect($$(el, 'img')).toHaveLength(0);
            expect($(el, '.abp-agent-name').textContent).toBe('Northwind Assist');
        });

        it('keeps the mic round through --cs-radius, and turns motion off for reduced motion', () => {
            expect(SOURCE_CSS).toMatch(/c-customer-summary-voice-input\s*\{[^}]*--cs-radius:\s*50%/);
            expect(SOURCE_CSS).toMatch(/@media\s*\(prefers-reduced-motion:\s*reduce\)/);
        });

        it('takes every border-radius from --cs-radius, apart from 50% shapes', () => {
            const values = [...SOURCE_CSS.matchAll(/border-radius:\s*([^;]+);/g)].map((m) => m[1].trim());
            expect(values.length).toBeGreaterThan(0);
            values.forEach((value) => expect(value).toMatch(/^(var\(--cs-radius\b.*\)|50%)$/));
        });

        it('the header button shows "Summarize" and is named for the account', async () => {
            const el = await mountOnAccount();
            const brief = $(el, '.abp-bar .abp-brief');
            expect(brief.textContent).toBe('Summarize');
            expect(brief.getAttribute('aria-label')).toBe('Summarize Acme');
            expect(brief.getAttribute('title')).toBe('Summarize Acme');
        });
    });

    describe('panel limits', () => {
        const threeRows = () =>
            exploreResult('Three deals.', {
                resultSets: [
                    {
                        objectName: 'Opportunity',
                        columns: ['Name'],
                        rows: [
                            { Id: DEAL, Name: 'A' },
                            { Id: DEAL2, Name: 'B' },
                            { Id: DEAL3, Name: 'C' }
                        ],
                        total: 3,
                        shown: 3
                    }
                ]
            });

        it('a result table is one Tab stop and the arrow keys move inside it', async () => {
            explore.mockResolvedValue(threeRows());
            const el = await mount();
            await ask(el, 'deals?');
            const buttons = $$(el, '.abp-row-button');
            expect(buttons.map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1', '-1']);

            buttons[0].focus();
            key(buttons[0], { key: 'ArrowDown' });
            expect(el.shadowRoot.activeElement).toBe(buttons[1]);
            expect(buttons.map((b) => b.getAttribute('tabindex'))).toEqual(['-1', '0', '-1']);
            key(buttons[1], { key: 'End' });
            expect(el.shadowRoot.activeElement).toBe(buttons[2]);
            key(buttons[2], { key: 'ArrowDown' });
            expect(el.shadowRoot.activeElement).toBe(buttons[2]);
            key(buttons[2], { key: 'Home' });
            expect(el.shadowRoot.activeElement).toBe(buttons[0]);
        });

        it("a brief section's drill lines are one Tab stop", async () => {
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(
                briefResult({
                    sections: [{ key: 'd', title: 'Open deals', status: 'OK', body: 'A — ' + DEAL + '\nB — ' + DEAL2, total: 2, shown: 2 }]
                })
            );
            const el = await mount();
            await ask(el, '/brief Acme');
            const lines = $$(el, '.abp-line-link');
            expect(lines.map((b) => b.getAttribute('tabindex'))).toEqual(['0', '-1']);
            key(lines[0], { key: 'ArrowDown' });
            expect(el.shadowRoot.activeElement).toBe(lines[1]);
        });

        it('gives every small button the 24 by 24 px target size', async () => {
            const rule = SOURCE_CSS.match(/([^{}]+)\{[^}]*min-height:\s*24px;[^}]*min-width:\s*24px;[^}]*\}/);
            expect(rule).not.toBeNull();
            const selectors = rule[1];
            ['.abp-line-link', '.abp-row-button', '.abp-summary-toggle', '.abp-quick', '.abp-chip', '.abp-candidate', '.abp-suggestion'].forEach((cls) =>
                expect(selectors).toContain(cls)
            );
        });

        it('never makes an Id-shaped number a drill, at the end of a line or inside it', async () => {
            const NUMBER = '123456789012345678';
            resolve.mockResolvedValueOnce({ status: 'RESOLVED', accountId: ACME, accountName: 'Acme' });
            getBrief.mockResolvedValueOnce(
                briefResult({
                    sections: [
                        {
                            key: 'calls',
                            title: 'Calls',
                            status: 'OK',
                            body: '- Order — ' + NUMBER + '\n notes: ref ' + NUMBER + ' kept\n- Real — ' + DEAL,
                            total: 1,
                            shown: 1
                        }
                    ]
                })
            );
            const el = await mount();
            await ask(el, '/brief Acme');
            const drills = $$(el, '.abp-line-link');
            expect(drills.map((b) => b.dataset.id)).toEqual([DEAL]);
            expect(el.shadowRoot.textContent).toContain('- Order — ' + NUMBER);
        });

        it('a drill that fails shows the fixed sentence, never platform text', async () => {
            explore.mockResolvedValue(threeRows());
            drill.mockRejectedValueOnce({ body: { message: 'Invalid id: 123456789012345678' } });
            const el = await mount();
            await ask(el, 'deals?');
            $(el, '.abp-row-button').click();
            await flush();
            const alert = $(el, '[role="alert"]');
            expect(alert.textContent).toBe(FIXED_ERROR);
            expect(el.shadowRoot.textContent).not.toContain('Invalid id');
        });
    });

    describe('accessibility', () => {
        it('is accessible empty on an account', async () => {
            const el = await mountOnAccount();
            await expect(el).toBeAccessible();
        });

        it('is accessible with an answer, a table and a pending turn', async () => {
            const slow = deferred();
            explore
                .mockResolvedValueOnce(
                    exploreResult('**One** deal.', {
                        resultSets: [{ objectName: 'Opportunity', columns: ['Name'], rows: [{ Id: DEAL, Name: 'A' }], total: 1, shown: 1 }],
                        followups: ['More?']
                    })
                )
                .mockReturnValueOnce(slow.promise);
            const el = await mount({ brand: BRAND });
            await ask(el, 'deals?');
            await ask(el, 'more?');
            await expect(el).toBeAccessible();
        });

        it('is accessible with an error turn', async () => {
            explore.mockRejectedValueOnce({});
            const el = await mount({ brand: BRAND });
            await ask(el, 'q');
            await expect(el).toBeAccessible();
        });
    });
});
