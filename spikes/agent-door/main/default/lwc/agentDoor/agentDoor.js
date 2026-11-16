import { LightningElement, api } from 'lwc';
import sendMessage from '@salesforce/apex/AgentDoorController.sendMessage';
import endSession from '@salesforce/apex/AgentDoorController.endSession';

const MAX_TURNS = 2;

export default class AgentDoor extends LightningElement {
    @api recordId;

    draft = '';
    turns = [];
    errorText = '';
    ended = false;
    endNote = '';
    busy = false;
    // Held here between turns. Never shown, never logged.
    sessionId;

    get hasTurns() {
        return this.turns.length > 0;
    }
    get turnsDone() {
        return this.turns.length >= MAX_TURNS;
    }
    get sendLabel() {
        return this.busy ? 'Waiting for the agent...' : 'Send turn ' + (this.turns.length + 1);
    }
    get inputDisabled() {
        return this.busy || this.ended || this.turnsDone;
    }
    get sendDisabled() {
        return this.inputDisabled || !this.draft.trim();
    }
    get endDisabled() {
        return this.busy || this.ended || !this.sessionId;
    }

    handleChange(event) {
        this.draft = event.target.value;
    }

    async handleSend() {
        const message = this.draft.trim();
        if (!message || this.busy) {
            return;
        }
        this.busy = true;
        this.errorText = '';
        try {
            const r = await sendMessage({ message, sessionId: this.sessionId, accountId: this.recordId });
            this.sessionId = r.sessionId;
            this.turns = [
                ...this.turns,
                {
                    key: 'turn-' + (this.turns.length + 1),
                    number: this.turns.length + 1,
                    message,
                    reply: r.reply,
                    seconds: r.seconds
                }
            ];
            this.draft = '';
        } catch (e) {
            this.errorText = (e && e.body && e.body.message) || 'The agent did not answer.';
        } finally {
            this.busy = false;
        }
    }

    async handleEnd() {
        this.busy = true;
        try {
            const r = await endSession({ sessionId: this.sessionId });
            this.endNote = r.note;
            this.ended = true;
            this.sessionId = undefined;
        } catch (e) {
            this.errorText = (e && e.body && e.body.message) || 'Could not end the session.';
        } finally {
            this.busy = false;
        }
    }
}
