# Voice input

A seller talks to the agent instead of typing, and the words land in the composer for the seller to check and send.

## The business problem

Sellers are between calls, in a car park or walking to a meeting. Typing a question to the agent is slow on a phone-sized
window and easy to skip, so the agent goes unused at the moments it would help most.

With this pattern, every Customer Summary window carries a mic button. The seller taps it, speaks, and watches the words
appear in the composer. Nothing is sent until the seller sends it, so a misheard word costs one edit, not a wrong answer.

## The architecture in a few steps

1. The seller taps the mic. The browser asks for the microphone once.
2. The browser's own speech recognition turns the voice into text as the seller speaks.
3. The component hands that text to its host as events, and the host puts it in the composer.
4. Recording stops when the seller taps again or after three seconds of silence.
5. The seller edits the text if needed and sends it.

## How it works

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontFamily": "-apple-system, Segoe UI, Helvetica, Arial, sans-serif", "primaryColor": "#eef4fb", "primaryTextColor": "#181818", "primaryBorderColor": "#0176d3", "lineColor": "#5c5c5c", "noteBkgColor": "#fff8e6", "noteTextColor": "#181818"}}}%%
sequenceDiagram
    autonumber
    participant U as Seller
    participant V as Voice input
    participant B as Browser speech recognition
    participant C as Composer (host)
    rect rgb(238, 244, 251)
        Note over U,B: Listen
        U->>V: Tap the mic
        V->>B: start (continuous, interim results)
        B-->>V: recording started
        V-->>C: recordingstate
    end
    rect rgb(240, 248, 240)
        Note over B,C: Transcribe
        B-->>V: interim and final text
        V-->>C: transcriptupdate, transcriptfinal
    end
    rect rgb(255, 248, 230)
        Note over U,C: Stop and review
        U->>V: Tap again, or 3 s of silence
        V->>B: stop
        V-->>C: recordingstate
        U->>C: Edit, then send
    end
```

Steps 1 to 4: the button calls `start()` on a new recognizer. The component asks for continuous recognition with interim
results, in the user's locale with `en-US` as the fallback, and fires `recordingstate` when listening begins. Steps 5 and
6: each result arrives as the full text so far. The component fires `transcriptupdate` with the whole transcript
(finished words plus the words still being heard), and `transcriptfinal` when a finished phrase is added. Steps 7 to 9: a
stop (the button, `stop()`, three seconds with no result, an error or the component leaving the page) ends recognition
and fires `recordingstate`. Step 10: the seller sends from the composer, never from here.

The component's public surface:

| Part | What it does |
|---|---|
| `agentName` (property) | Name used in the permission message. Default `Customer Summary`. |
| `start()` and `stop()` | Begin or end listening. `stop()` when idle does nothing. |
| `transcriptupdate` | `detail.transcript`: all text so far, finished and interim. |
| `transcriptfinal` | `detail.transcript`: all finished text, fired when it grows. |
| `recordingstate` | `detail.recording`: true when listening starts, false when it stops. |
| `voiceerror` | `detail.error`: the recognizer's error code. |

Event names are lowercase because LWC rejects hyphens. A polite live region says "Listening started." and "Listening
stopped.". The button is a toggle (`aria-label` Talk or Stop, `aria-pressed`) with a visible recording style that does not
animate for people who ask for reduced motion.

### Errors and support

- `not-allowed`: "Customer Summary needs microphone permission to listen." (the agent name comes from the property).
- Any other error: "Voice input had an issue. Try again or type instead." Silence (`no-speech`) and `aborted` show nothing.
- No speech API in the browser: the button is hidden and a note says voice is not available in this browser. Typing
  always works.

### Browser support

| Browser | Support |
|---|---|
| Chrome and Edge | Full |
| Safari | Patchy |
| Firefox | None |

### Privacy

Chrome sends the audio to Google's servers to transcribe it. Say so to anyone who asks, and to a customer whose security
team will.

### Why it never auto-sends

Speech recognition mishears names, numbers and product words. The words go into the editable composer so the seller can
fix them first. The component has no send path at all: it fires events and the host decides what to do with them.

### Test it by hand

Automated Chromium cannot speak to the API (see [the surfaces spike](../research/fr2-surfaces-spike.md)), so Jest uses a
mocked recognizer and the real check is by hand, once per release.

1. Open the surface that embeds the mic in Chrome, signed in as a seller.
2. Tap the mic and allow the microphone. The button turns to its recording style and reads "Stop".
3. Say a sentence. Words appear in the composer while you speak.
4. Stay quiet for three seconds. Recording stops by itself and nothing is sent.
5. Tap the mic, then block the microphone for the site in Chrome and tap again. The permission message shows.
6. Open the page in Firefox. The mic is hidden and the note shows.

### Embed it

Place the component beside the composer and listen for its events. The component is not exposed on any page by itself.

```html
<c-customer-summary-voice-input
    agent-name={agentName}
    ontranscriptupdate={handleTranscript}
    onrecordingstate={handleRecordingState}
    onvoiceerror={handleVoiceError}
></c-customer-summary-voice-input>
```

Set the composer's text from `event.detail.transcript` in `handleTranscript`. Do not send from any of these handlers. Set
the `--cs-*` brand variables on the host, as in [brand and theming](10-brand-and-theming.md); the stylesheet reads only
those, each with a neutral fallback.

## See it

None yet. The component is not on any page until the conversation component embeds it, so there is no capture to show.

## Why you can trust it

Runs as the signed-in user: the component calls no Apex and reads no record; recognition runs in the user's own browser.

System context: none on this path.

- Start, interim and final text, silence stop, manual stop, permission and other errors, an unsupported browser, leaving
  the page, and zero accessibility violations are covered with a mocked recognizer:
  `customerSummaryVoiceInput.test.js`.
- The component never sends: no test or code path dispatches a send event, and the host owns the send button.
- It uses no blocked Lightning Web Security API and needs no CSP, trusted site or permission metadata.

## How it scales

- Each window runs its own recognizer in its own browser, so voice adds no server load: the audio goes from the browser
  to the browser vendor's speech service, not to Salesforce.
- A new surface embeds the same component and listens for the same four events.

## Adopt it

1. Grant access: assign the permission set group `Customer_Summary_User`.
2. Copy the `customerSummaryVoiceInput` component bundle.
3. Embed it as shown above and fill your composer from `transcriptupdate`.

## Limits and open items

- The recognizer is the browser's, so accuracy, language list and the audio privacy line are the browser vendor's.
- Only the user's locale is tried, with `en-US` as the fallback; there is no language picker.
- The real transcript is checked by hand, not in automation.
- Embedding it in the conversation composer is not done here; no card yet.

[Back to the architecture page](../ARCHITECTURE.md) | [Back to the README](../../README.md)
