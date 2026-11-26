# Proof index

Everything here is produced by scripts (`scripts/test-all.sh`, `scripts/capture-proof.sh <phase>`, `scripts/drill-kill-web-task.sh`) against the running system with real data flowing through it.

## Phase 1: local (`phase1-local/`)

### Tests (`tests/`)
| File | Proves |
|---|---|
| `rspec-junit.xml`, `rspec.log` | 13 RSpec examples: tenancy isolation, operator vs admin authorisation, RAG answer with citations, signed workflow-tool call, handoff (customer request + low confidence), answer cache, operator takeover flow, Bullet N+1 guard, metrics rollup, Action Cable chat channel |
| `vitest-junit.xml`, `vitest.log` | Inbox list with TanStack Query + live invalidation; live transcript (streamed tokens → final message, AI draft) |
| `playwright-junit.xml`, `playwright-report/`, `playwright.log` | e2e: chat answer (tool + citation) → escalate → inbox in < 2 s → operator takeover → resolve → metrics; fake-microphone voice + avatar (interview fields stored); phone simulator; SSR check; sticky experiment assignment |
| `k6.log`, `k6-summary.json` | 20 VUs × 2 min, time-to-first-token p95 vs the 400 ms local budget |
| `capture/` | Playwright report for the screenshot run |

### Screenshots (`screenshots/`)
| File | Proves |
|---|---|
| `01-chat-ja-streaming-citation.png` | Japanese chat answer streamed with a citation link to the help-center article |
| `02-tool-call-order-status.png` | Tool call chip + answer from `check_order_status` (HMAC-signed call to the mock backend) |
| `03-voice-widget.png` | Hold-to-talk voice tab with a spoken reply (fake mic; mock STT path) |
| `04-avatar-interview.png` | SVG avatar + scripted 3-question return interview |
| `05-phone-sim.png` | Phone simulator call over mu-law frames, caller/agent log |
| `06-console-inbox.png` | Operator inbox with the escalated (waiting_human) conversation at the top |
| `07-operator-takeover.png` | Live transcript, AI-drafted reply sent by the operator, status = human |
| `08-latency-dashboard.png` | p50/p95 per stage per channel against the budget, cache hit rate |
| `09-metrics-experiment.png` | KPIs, control vs `greeting_v2` table, delta + p-value + sample-size note |
| `10-help-center-ssr.png` | Next.js help center with the widget embedded |
| `11-jaeger-trace.png` | One trace spanning the browser widget and Rails (OpenTelemetry) |
| `12-knowledge-sources.png` | Knowledge sources with status and chunk counts (≥ 50 chunks ingested) |

### Logs (`logs/`)
| File | Proves |
|---|---|
| `drill-kill-web.log` | Web tier killed mid-chat; client reconnects, history replays, conversation continues |
| `curl-help-center-ssr.html` (+ `.check.txt`) | Article text is in the server-rendered HTML without JavaScript |
| `smoke-chat-order.log` | Streamed answer, tool call, citation URL and per-stage timings over Action Cable |
| `rails-structured-json.log`, `sidekiq.log` | Structured JSON logs (lograge), PII-redacted |
| `prometheus-agent-metrics.txt` | `agent_stage_ms` histograms, cache and handoff counters |

Related docs: [`docs/db-performance.md`](../docs/db-performance.md) (real EXPLAIN ANALYZE), [`docs/experiments/greeting-v2.md`](../docs/experiments/greeting-v2.md), [`docs/postmortems/`](../docs/postmortems/).

## Phase 2: cloud (`phase2-cloud/`)
_Filled in during Phase 2._

## Phase 3: destroy (`phase3-destroy/`)
_Filled in during Phase 3._
