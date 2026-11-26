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

Deployed with `scripts/deploy.sh` (Terraform + ECR + ECS rolling deploys). Real services: Amazon Titan embeddings, Bedrock Converse streaming
(Claude is configured first; **this account could not invoke Claude** — "use case details not submitted" — so Amazon Nova Lite served the answers through
the built-in fallback, visible as `bedrock.converse_stream` spans in X-Ray), Transcribe streaming (ja-JP) and Polly neural (Tomoko).

| File | Proves |
|---|---|
| `resources.txt` | Everything deployed: Fargate services (web ×2 in two AZs), RDS PostgreSQL 17, ElastiCache Redis 7.1, ALB, CloudFront, S3, ECR, Secrets Manager, IAM roles, alarms, 1-day log groups, **0 NAT gateways** |
| `screenshots/01-cloud-chat-bedrock.png` | Chat answer in the cloud help center (served over CloudFront https) with tool call and citation |
| `screenshots/02-cloud-voice-transcribe-polly.png` | Voice: Polly-synthesised Japanese utterance → fake microphone → **Amazon Transcribe** transcript ("返品はできますか？…") → answer spoken with **Polly** |
| `screenshots/03-cloud-avatar-visemes.png` | Avatar tab with Polly viseme speech marks driving the SVG mouth |
| `screenshots/04-cloud-operator.png` | Operator console (CloudFront) taking over an escalated conversation |
| `screenshots/05-cloud-latency.png` | Latency dashboard (includes the 400 seeded *simulated* conversations plus real cloud turns) |
| `screenshots/06-cloudwatch-alarms.png` | CloudWatch alarms and metric graphs rendered with `get-metric-widget-image`, including custom EMF latency metrics |
| `screenshots/07-xray-trace-summary.png` | X-Ray trace from the ADOT sidecar: `agent.run` → retrieval → `llm.stream` → `bedrock.converse_stream` (primary refused, fallback served) → `tool.call`, plus RDS/ElastiCache spans |
| `tests/playwright-cloud.log`, `tests/playwright-cloud/` | e2e against the cloud: chat → escalate → operator → resolve → metrics; Transcribe/Polly voice and avatar (two **flaky on first attempt, pass on retry**); phone simulator with real Transcribe; SSR check; sticky experiment |
| `tests/k6-cloud.txt`, `tests/k6-cloud-summary.json` | 5 virtual users, time-to-first-token p50/p95 with Bedrock in the loop (recorded as measured) |
| `logs/smoke-chat-bedrock.log` | Streamed answer with tool call, citation and per-stage timings from the cloud |
| `logs/drill-kill-web-aws.log` | One of two ECS web tasks stopped mid-chat: reconnect in ~2 s, history replayed, conversation continued |
| `logs/ecs-deployment-rollback-demo.txt` | Deploy of a non-existent image tag: tasks fail to start → **deployment circuit breaker rolls back automatically** |
| `logs/gh-actions-deploy-run.txt` | The GitHub Actions OIDC deploy attempt — denied at `sts:AssumeRoleWithWebIdentity` by the account (see `docs/DECISIONS.md`); deployment ran from the PC instead |
| `logs/terraform-apply.log`, `logs/migrate-seed.log`, `logs/cloudwatch-alarms.txt`, `logs/xray-trace-summary.txt` | Infrastructure apply, one-off migrate+seed task, alarm states, X-Ray span list |

## Phase 3: destroy (`phase3-destroy/`)

| File | Proves |
|---|---|
| `verify-destroyed.txt` | `scripts/verify-destroyed.sh` after `scripts/destroy.sh`: no ECS cluster, ALB, RDS, ElastiCache, CloudFront, S3 buckets, ECR repos, secrets, IAM roles, VPC or log groups remain |
| `destroy.log` | Output of `scripts/destroy.sh` |
