Status: placeholder, not built

# Embedded surface (call centre)

The idea: a service rep accepts a call and the agent is already on the page, with the customer briefed. Nothing here is built,
and nothing on this page is a setup guide.

> [!WARNING]
> **Placeholder only.** This page records a vision so it is not lost. No code, metadata or configuration exists for it in
> this repo. The platform pieces below are named from public Salesforce documentation, to say what a real build would
> have to fit. They are not claimed to work with this agent. A later spike decides that. Do not follow this page as a
> procedure.

## The story, in the product owner's words

The request was to put the agent "embedding on a page directly". Taking CTI as the example: "you would accept the call,
that customer's information would populate your screen and an agentic prompt or conversation would potentially start
... embedded on the screen as a component".

The service rep is "briefed on their customer as soon as they accept the call", with the "account map, and variables
and fields", "access to things like knowledge articles or support", and the ability to "take action to follow up".

The same request said to "table this as a much larger spike", to be "true and realistic to how Salesforce will actually
provision and be used for call center workflows", and to "put a placeholder in and keep it safe". This page is that
placeholder.

## What the rep would see

1. The service rep accepts an incoming call.
2. The customer's record opens, and the agent starts a brief on its own, without a prompt.
3. The brief shows next to an account map and the key fields of the account.
4. The rep can chat with the agent, as in the compact window and the rail.
5. Knowledge articles that fit the call are offered.
6. The rep takes a follow-up action: a task, a logged call, a case, each shown as a draft first.

## Platform pieces a real build would have to fit

Named from public Salesforce documentation. Whether and how each one works with this agent is not known.

| Piece | Why it matters here |
|---|---|
| Telephony: Service Cloud Voice, or a partner CTI adapter through Open CTI | Decides who owns the call and which events the page can hear |
| Omni-Channel work item and its call-accepted event | The likely moment the brief would start, if the page can listen for it |
| Console record page (Lightning app with the Service Console) | The page region where a component would sit |
| Knowledge | The source of the articles the rep is offered, with its own access rules |

## How it would reuse what exists

- **The conversation component.** The embedded surface would be a third frame around the one conversation component
  (`customerSummaryConversation`) that the compact window and the rail use. The thread, composer, cards and history stay
  the same; only the frame differs ([fr2-design.md](../plans/fr2-design.md#surfaces)).
- **The summary skill.** The brief is the same one-ask summary, started by an event, not a typed request.
- **The context call.** The record in front of the rep supplies the context, so nobody passes it back by hand.
- **The write actions.** Follow-ups use the same actions, with the same draft and confirm step. Nothing is written
  until the rep confirms.
- **The same access.** The agent would run as the signed-in service rep and see what the rep sees.

## Questions the later spike must answer

- **Telephony:** which products would a team actually use (Service Cloud Voice, a partner CTI through Open CTI, or
  none), and what does each hand to a page when a call arrives?
- **The event:** which event starts the brief, and can a component hear it on a console page?
- **Access:** what is a service rep allowed to see about a caller, and what should a brief leave out?
- **Latency:** how long can a caller wait while the brief builds, and what shows in the meantime?
- **Licences:** which licences does the rep need, and which does the build add?
- **Knowledge:** which articles may the agent read as the rep, and how are they chosen for a call?
- **Unknown callers:** what happens when the number matches no account, or several?

## What is deliberately not done

- No code, no metadata, no component and no test for this surface.
- No telephony set-up, no CTI adapter and no Omni-Channel configuration.
- No claim that any platform piece above works with the agent.
- No change to the compact window or the rail on account of this page.
- No estimate of effort or date. The spike is parked until the product owner says go.

[Back to the architecture page](../ARCHITECTURE.md) | [Back to the README](../../README.md)
