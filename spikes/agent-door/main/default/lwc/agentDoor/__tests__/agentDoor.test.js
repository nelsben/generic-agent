import { createElement } from 'lwc';
import AgentDoor from 'c/agentDoor';
import sendMessage from '@salesforce/apex/AgentDoorController.sendMessage';
import endSession from '@salesforce/apex/AgentDoorController.endSession';

jest.mock('@salesforce/apex/AgentDoorController.sendMessage', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AgentDoorController.endSession', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
    const el = createElement('c-agent-door', { is: AgentDoor });
    el.recordId = '001000000000001AAA';
    document.body.appendChild(el);
    return el;
}
const textarea = (el) => el.shadowRoot.querySelector('lightning-textarea');
const buttons = (el) => el.shadowRoot.querySelectorAll('lightning-button');
async function type(el, text) {
    const ta = textarea(el);
    ta.value = text;
    ta.dispatchEvent(new CustomEvent('change'));
    await flush();
}
async function send(el) {
    buttons(el)[0].click();
    await flush();
    await flush();
}

describe('c-agent-door', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('sends turn 1 with no session and turn 2 with the session turn 1 returned', async () => {
        sendMessage
            .mockResolvedValueOnce({ reply: 'Brief text', sessionId: 'S1', seconds: 12, replyLength: 10 })
            .mockResolvedValueOnce({ reply: 'No open cases', sessionId: 'S1', seconds: 9, replyLength: 13 });
        const el = mount();
        await type(el, 'Give me a brief');
        await send(el);
        expect(sendMessage).toHaveBeenNthCalledWith(1, {
            message: 'Give me a brief',
            sessionId: undefined,
            accountId: '001000000000001AAA'
        });
        await type(el, 'What about its cases?');
        await send(el);
        expect(sendMessage).toHaveBeenNthCalledWith(2, {
            message: 'What about its cases?',
            sessionId: 'S1',
            accountId: '001000000000001AAA'
        });
        const replies = [...el.shadowRoot.querySelectorAll('.reply')].map((n) => n.textContent);
        expect(replies).toEqual(['Brief text', 'No open cases']);
    });

    it('stops after two turns', async () => {
        sendMessage.mockResolvedValue({ reply: 'ok', sessionId: 'S1', seconds: 1, replyLength: 2 });
        const el = mount();
        await type(el, 'one');
        await send(el);
        await type(el, 'two');
        await send(el);
        expect(textarea(el).disabled).toBe(true);
        expect(buttons(el)[0].disabled).toBe(true);
    });

    it('keeps End disabled until a session exists, then ends it and locks the form', async () => {
        sendMessage.mockResolvedValue({ reply: 'ok', sessionId: 'S1', seconds: 1, replyLength: 2 });
        endSession.mockResolvedValue({ released: true, endedOnPlatform: false, note: 'Released here.' });
        const el = mount();
        expect(buttons(el)[1].disabled).toBe(true);
        await type(el, 'hello');
        await send(el);
        expect(buttons(el)[1].disabled).toBe(false);
        buttons(el)[1].click();
        await flush();
        await flush();
        expect(endSession).toHaveBeenCalledWith({ sessionId: 'S1' });
        expect(el.shadowRoot.querySelector('[role="status"]').textContent).toBe('Released here.');
        expect(textarea(el).disabled).toBe(true);
        expect(buttons(el)[1].disabled).toBe(true);
    });

    it('shows the error and keeps the draft when the agent does not answer', async () => {
        sendMessage.mockRejectedValue({ body: { message: 'The agent did not answer: boom' } });
        const el = mount();
        await type(el, 'hello');
        await send(el);
        expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toBe('The agent did not answer: boom');
        expect(textarea(el).value).toBe('hello');
        expect(buttons(el)[1].disabled).toBe(true);
    });

    it('does not send a blank message', async () => {
        const el = mount();
        await type(el, '   ');
        expect(buttons(el)[0].disabled).toBe(true);
        expect(sendMessage).not.toHaveBeenCalled();
    });
});
