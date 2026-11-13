import { LightningElement, api } from 'lwc';
import LOCALE from '@salesforce/i18n/locale';

const SILENCE_MS = 3000;
const IGNORED_ERRORS = ['no-speech', 'aborted'];

/**
 * Mic toggle using the browser's Web Speech API. It fills a composer through
 * events and never sends anything itself.
 */
export default class CustomerSummaryVoiceInput extends LightningElement {
    /** Name used in the microphone permission message. */
    @api agentName = 'Customer Summary';

    recording = false;
    errorMessage = '';
    announcement = '';

    recognizer;
    silenceTimer;
    lastFinal = '';

    get isSupported() {
        return !!this.recognizerClass();
    }

    get buttonLabel() {
        return this.recording ? 'Stop' : 'Talk';
    }

    get ariaPressed() {
        return this.recording ? 'true' : 'false';
    }

    get buttonClass() {
        return this.recording ? 'recording' : '';
    }

    @api
    start() {
        if (this.recording) return;
        const Recognizer = this.recognizerClass();
        if (!Recognizer) return;
        this.errorMessage = '';
        this.lastFinal = '';
        const r = new Recognizer();
        r.continuous = true;
        r.interimResults = true;
        r.lang = LOCALE || 'en-US';
        r.onstart = () => this.setRecording(true);
        r.onresult = (event) => this.handleResult(event);
        r.onerror = (event) => this.handleError(event);
        r.onend = () => this.setRecording(false);
        this.recognizer = r;
        try {
            r.start();
        } catch (e) {
            this.handleError({ error: 'start-failed' });
            return;
        }
        this.resetSilenceTimer();
    }

    @api
    stop() {
        this.clearSilenceTimer();
        const r = this.recognizer;
        this.recognizer = null;
        if (r) {
            r.onend = null;
            r.onresult = null;
            r.onerror = null;
            try {
                r.stop();
            } catch (e) {
                // already stopped
            }
        }
        this.setRecording(false);
    }

    disconnectedCallback() {
        this.stop();
    }

    handleToggle() {
        if (this.recording) {
            this.stop();
        } else {
            this.start();
        }
    }

    handleResult(event) {
        this.resetSilenceTimer();
        let finalText = '';
        let interimText = '';
        for (let i = 0; i < event.results.length; i++) {
            const piece = event.results[i][0].transcript;
            if (event.results[i].isFinal) {
                finalText += (finalText ? ' ' : '') + piece.trim();
            } else {
                interimText += (interimText ? ' ' : '') + piece.trim();
            }
        }
        const full = [finalText, interimText].filter(Boolean).join(' ');
        this.dispatchEvent(new CustomEvent('transcriptupdate', { detail: { transcript: full } }));
        if (finalText && finalText !== this.lastFinal) {
            this.lastFinal = finalText;
            this.dispatchEvent(new CustomEvent('transcriptfinal', { detail: { transcript: finalText } }));
        }
    }

    handleError(event) {
        const code = event && event.error;
        if (IGNORED_ERRORS.includes(code)) {
            return;
        }
        this.errorMessage =
            code === 'not-allowed'
                ? this.agentName + ' needs microphone permission to listen.'
                : 'Voice input had an issue. Try again or type instead.';
        this.dispatchEvent(new CustomEvent('voiceerror', { detail: { error: code } }));
        this.stop();
    }

    setRecording(value) {
        if (this.recording === value) return;
        this.recording = value;
        this.announcement = value ? 'Listening started.' : 'Listening stopped.';
        this.dispatchEvent(new CustomEvent('recordingstate', { detail: { recording: value } }));
    }

    resetSilenceTimer() {
        this.clearSilenceTimer();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.silenceTimer = setTimeout(() => this.stop(), SILENCE_MS);
    }

    clearSilenceTimer() {
        if (this.silenceTimer) {
            clearTimeout(this.silenceTimer);
            this.silenceTimer = null;
        }
    }

    recognizerClass() {
        return window.SpeechRecognition || window.webkitSpeechRecognition;
    }
}
