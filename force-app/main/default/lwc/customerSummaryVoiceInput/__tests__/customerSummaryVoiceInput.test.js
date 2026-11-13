import { createElement } from 'lwc';
import CustomerSummaryVoiceInput from 'c/customerSummaryVoiceInput';

let recognizers;

class MockRecognizer {
    constructor() {
        this.start = jest.fn(() => {
            this.started = true;
            if (this.onstart) this.onstart();
        });
        this.stop = jest.fn(() => {
            this.started = false;
            if (this.onend) this.onend();
        });
        recognizers.push(this);
    }
    emit(parts) {
        // parts: [{ text, final }]
        const results = parts.map((p) => {
            const r = [{ transcript: p.text }];
            r.isFinal = !!p.final;
            return r;
        });
        this.onresult({ resultIndex: 0, results });
    }
}

function build(props = {}) {
    const el = createElement('c-customer-summary-voice-input', { is: CustomerSummaryVoiceInput });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}
const button = (el) => el.shadowRoot.querySelector('button');
const flush = () => Promise.resolve();
const text = (el, sel) => {
    const n = el.shadowRoot.querySelector(sel);
    return n ? n.textContent.trim() : null;
};

describe('c-customer-summary-voice-input', () => {
    beforeEach(() => {
        recognizers = [];
        jest.useFakeTimers();
        window.SpeechRecognition = MockRecognizer;
        delete window.webkitSpeechRecognition;
    });
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        delete window.SpeechRecognition;
        delete window.webkitSpeechRecognition;
        jest.useRealTimers();
    });

    it('configures a continuous, interim recognizer in en-US', async () => {
        const el = build();
        button(el).click();
        await flush();
        const r = recognizers[0];
        expect(r.continuous).toBe(true);
        expect(r.interimResults).toBe(true);
        expect(r.lang).toBe('en-US');
        expect(r.start).toHaveBeenCalledTimes(1);
    });

    it('falls back to webkitSpeechRecognition', async () => {
        delete window.SpeechRecognition;
        window.webkitSpeechRecognition = MockRecognizer;
        const el = build();
        button(el).click();
        await flush();
        expect(recognizers).toHaveLength(1);
    });

    it('toggles label, pressed state, recording class and live region', async () => {
        const el = build();
        const btn = button(el);
        expect(btn.getAttribute('aria-label')).toBe('Talk');
        expect(btn.getAttribute('aria-pressed')).toBe('false');
        const states = [];
        el.addEventListener('recordingstate', (e) => states.push(e.detail.recording));
        btn.click();
        await flush();
        expect(btn.getAttribute('aria-label')).toBe('Stop');
        expect(btn.getAttribute('aria-pressed')).toBe('true');
        expect(btn.classList.contains('recording')).toBe(true);
        const live = el.shadowRoot.querySelector('[aria-live="polite"]');
        expect(live.textContent).toMatch(/listening/i);
        btn.click();
        await flush();
        expect(btn.getAttribute('aria-label')).toBe('Talk');
        expect(btn.classList.contains('recording')).toBe(false);
        expect(live.textContent).toMatch(/stopped/i);
        expect(states).toEqual([true, false]);
    });

    it('emits interim then final transcript and never sends', async () => {
        const el = build();
        const updates = [];
        const finals = [];
        const other = jest.fn();
        el.addEventListener('transcriptupdate', (e) => updates.push(e.detail.transcript));
        el.addEventListener('transcriptfinal', (e) => finals.push(e.detail.transcript));
        el.addEventListener('send', other);
        el.addEventListener('submit', other);
        button(el).click();
        await flush();
        const r = recognizers[0];
        r.emit([{ text: 'show me' }]);
        expect(updates).toEqual(['show me']);
        expect(finals).toEqual([]);
        r.emit([{ text: 'show me acme', final: true }]);
        expect(updates[1]).toBe('show me acme');
        expect(finals).toEqual(['show me acme']);
        r.emit([{ text: 'show me acme', final: true }, { text: 'renewals' }]);
        expect(updates[2]).toBe('show me acme renewals');
        expect(other).not.toHaveBeenCalled();
    });

    it('stops after 3 s of silence and resets the timer on each result', async () => {
        const el = build();
        button(el).click();
        await flush();
        const r = recognizers[0];
        jest.advanceTimersByTime(2900);
        r.emit([{ text: 'hello' }]);
        jest.advanceTimersByTime(2900);
        expect(r.stop).not.toHaveBeenCalled();
        jest.advanceTimersByTime(200);
        expect(r.stop).toHaveBeenCalledTimes(1);
        await flush();
        expect(button(el).getAttribute('aria-pressed')).toBe('false');
    });

    it('stops manually through the button and the public api', async () => {
        const el = build();
        el.start();
        await flush();
        expect(recognizers[0].start).toHaveBeenCalled();
        el.stop();
        expect(recognizers[0].stop).toHaveBeenCalledTimes(1);
        // idempotent: stop when idle does nothing
        el.stop();
        expect(recognizers[0].stop).toHaveBeenCalledTimes(1);
    });

    it('shows the permission message for not-allowed using the agent name', async () => {
        const el = build({ agentName: 'Acme Helper' });
        const errors = [];
        el.addEventListener('voiceerror', (e) => errors.push(e.detail.error));
        button(el).click();
        await flush();
        recognizers[0].onerror({ error: 'not-allowed' });
        await flush();
        expect(text(el, '[role="alert"]')).toBe('Acme Helper needs microphone permission to listen.');
        expect(errors).toEqual(['not-allowed']);
        expect(button(el).getAttribute('aria-pressed')).toBe('false');
    });

    it('defaults the agent name to Customer Summary', async () => {
        const el = build();
        button(el).click();
        await flush();
        recognizers[0].onerror({ error: 'not-allowed' });
        await flush();
        expect(text(el, '[role="alert"]')).toBe('Customer Summary needs microphone permission to listen.');
    });

    it('shows a generic message for other errors', async () => {
        const el = build();
        button(el).click();
        await flush();
        recognizers[0].onerror({ error: 'network' });
        await flush();
        expect(text(el, '[role="alert"]')).toBe('Voice input had an issue. Try again or type instead.');
    });

    it('ignores no-speech and aborted without an error', async () => {
        const el = build();
        const errors = jest.fn();
        el.addEventListener('voiceerror', errors);
        button(el).click();
        await flush();
        recognizers[0].onerror({ error: 'aborted' });
        await flush();
        expect(errors).not.toHaveBeenCalled();
    });

    it('hides the button and shows a note when unsupported', async () => {
        delete window.SpeechRecognition;
        const el = build();
        expect(button(el)).toBeNull();
        expect(text(el, '.unsupported')).toMatch(/not available in this browser/i);
        el.start();
        expect(recognizers).toHaveLength(0);
    });

    it('stops recognition on disconnect', async () => {
        const el = build();
        button(el).click();
        await flush();
        document.body.removeChild(el);
        expect(recognizers[0].stop).toHaveBeenCalled();
        jest.advanceTimersByTime(5000);
        expect(recognizers[0].stop).toHaveBeenCalledTimes(1);
    });

    it('has no accessibility violations idle, recording, errored or unsupported', async () => {
        jest.useRealTimers();
        const el = build();
        await expect(el).toBeAccessible();
        button(el).click();
        await flush();
        await expect(el).toBeAccessible();
        recognizers[0].onerror({ error: 'network' });
        await flush();
        await expect(el).toBeAccessible();
        delete window.SpeechRecognition;
        const el2 = build();
        await expect(el2).toBeAccessible();
    });
});
