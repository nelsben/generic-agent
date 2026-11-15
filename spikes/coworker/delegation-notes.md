# OPS-63 delegation notes (connect-24h, 2026-11-15)

How each number in `results/delegation.jsonl` was read. Counts and timings only; no Ids, names or hostnames.

- **Set-up.** Coworker's Ask page in a new Chrome tab, as the org's existing admin user (the CLI user). Each turn was a new chat,
  so no turn saw an earlier one. Three questions, three turns each, nine turns in all: `Summarize Edge Communications`
  (the seed account); `List the 30 opportunities with the earliest close dates, with their name, stage and amount.` (BE-32 rung e2);
  `List all opportunities, with their name, stage, amount, close date and account name, sorted by close date.` (BE-32 rung e4).
  No agent or topic description was changed.
- **delegated.** Read from the thinking steps Coworker streams above its answer. A delegation would show the `Customer_Summary`
  agent or its actions. All nine turns showed only Coworker's own steps ("Finding Salesforce records (Opportunity)", "Get record
  content (Account)", and for the summary also Case and Contact searches), and none named `Customer_Summary`. So delegated is
  `false` in all nine. The Agentforce panel's agent picker in the same org does list `Customer Summary`, so the agent was visible
  to the user.
- **first_text_s.** Seconds from the question appearing in the chat to the first character of Coworker's reply text (its opening
  line, "Let me pull ..."), sampled every 250 ms by a script in the page, so each value is good to about 0.25 s. This is
  Coworker's own opening line, not the answer. Summary turn 1 was measured with a cruder sampler (whole-page text length) and its
  3.5 s is the first large text jump, not the opening line; read it as less exact.
- **finished_s.** Seconds from the question appearing to the moment the feedback controls (Like) appeared under the reply, which
  is when the stream ends. Same 250 ms sampling. Summary turn 1 uses the last text change (15.0 s) minus the send time (0.75 s).
- **labels_kept.** How many of the summary's six section labels (Account, Open deals, People & engagement, Service health, Deal
  history, Watch next) appear alone on their own line in the reply. Lines were rebuilt from the page's text with a break at each
  block element. 0 of 6 in all three. Coworker wrote its own layout (an account paragraph beginning "Account Overview", then
  opportunities, in turns 2 and 3 cases and contacts) and never used the product's labels.
- **rows_kept.** The number of table rows in Coworker's answer (table rows in the page, less the header and the two the page
  holds at rest). The answers were real tables with a row-number column. Counts were also checked against Coworker's own words
  ("30 results", "47 results").
- **panel_rows.** The rows the product's panel shows for the same question, read by running the panel's own Apex entry point
  (`CustomerSummaryPanelController.explore`) as the admin in `connect-24h`: 30 rows (30 of 47) for the 30-earliest question and
  47 rows (47 of 47) for the all-opportunities question. Counts only were printed.
- **timeout.** No turn timed out or showed an error.
- **What was not measured.** Whether Coworker would delegate if asked to use `Customer Summary` by name; the card did not ask for it.
  Section content was not compared word for word.
