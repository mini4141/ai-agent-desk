# Experiment: `greeting_v2`

**Hypothesis.** Opening the widget with a proactive greeting and three suggested questions (instead of a plain greeting) gets more
customers to a self-served answer, so deflection goes up and handoff goes down.

**Setup.** Flipper feature `greeting_v2`, `percentage_of_actors = 50`. The actor is the visitor id kept in `localStorage`, so assignment
is sticky across sessions (Flipper hashes the actor id; covered by the Playwright test *greeting_v2 assignment is sticky per visitor*).
The variant is stored on every conversation (`conversations.variant`) and rolled up per day, channel and variant by `MetricsRollupJob`
(nightly via sidekiq-cron, on demand from the Metrics page). Load-test traffic (`k6-*`, `drill-*`, `smoke-*` visitors) is excluded.

**Metric definitions.**

| Metric | Definition |
|---|---|
| Deflection | conversations resolved without a human ÷ all conversations |
| Handoff rate | conversations a human touched ÷ all conversations |
| CSAT | mean of the end-of-chat thumbs (up = 5, down = 1) |
| Tool conversion | conversations that triggered a workflow action ÷ all conversations |

## Result (Phase 1, local data)

> **Honesty note.** The history behind this table is **simulated**: `db/seeds.rb` generates 400 conversations over 14 days with a deliberately
> better outcome distribution for `greeting_v2` (seed `2026`), plus the handful of real conversations the end-to-end tests create.
> It demonstrates the *measurement pipeline* (assignment → rollup → z-test → dashboard); it is not evidence that a real greeting change moves
> real customers. The seed marks those rows `simulated = true`.

| | control | greeting_v2 |
|---|---|---|
| Conversations (n) | 237 | 237 |
| Deflection | 53.6 % | 63.3 % |
| Handoff rate | 29.5 % | 21.9 % |
| CSAT (responses) | 4.06 (119) | 4.10 (134) |
| Avg handle time | 292 s | 243 s |
| Tool conversion | 17.3 % | 27.9 % |

**Delta in deflection: +9.7 pp**, two-proportion z-test p = 0.032 (n = 237 / 237). The dashboard (`/metrics`, screenshot
`proof/phase1-local/screenshots/09-metrics-experiment.png`) shows the same numbers and a sample-size note: below 200 conversations per arm
it says "directional only"; above that it reports significance at the 5 % level.

**Decision.** Ship `greeting_v2` to 100 % (`Flipper.enable(:greeting_v2)`) after a week of real traffic confirms the direction with
n ≥ 1,000 per arm; keep the 50/50 split until then. CSAT is flat, so there is no sign that the proactive greeting annoys customers.

**Caveats.** One metric tested without multiple-comparison correction; novelty effect not separated; channel mix is not stratified
(the dashboard can filter by channel via `?channel=`).
