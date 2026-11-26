# PROGRESS

Resume from the first unticked item. Phases in order: 0 scaffold → 1 local → 2 AWS → 3 destroy → 4 write-up.
Status: **all phases done**; CI is green on main.

## Phase 0: scaffold
- [x] Repo layout, README, PROGRESS, DECISIONS, .gitignore, .gitattributes, .env.example, CI workflow

## Coverage matrix (SPECS §2)
- [x] End-to-end ownership: Rails + React console + Next.js + Postgres/Redis
- [x] Architecture ADRs in docs/adr/
- [x] Scalability/performance: stateless web ×2, Sidekiq, Redis cache, latency budget (k6 + dashboard)
- [x] Rails 8 API, Action Cable, Sidekiq (RSpec)
- [x] React + TS console and widget (Vitest/Playwright)
- [x] DB optimisation: docs/db-performance.md, strict loading, Bullet, HNSW + composite indexes
- [x] CI/CD: GitHub Actions test + OIDC deploy workflow with rollback (OIDC assume-role was denied by the account; deployment ran from the PC, see DECISIONS)
- [x] Observability: OTel traces, lograge, Prometheus/Grafana, CloudWatch alarms, latency dashboard
- [x] Security: Rails auth + JWT, Pundit, AR encryption, PII redaction, rack-attack
- [x] greeting_v2 experiment with measured delta
- [x] Japanese: ja-first UI, prompts, seed data, voices
- [x] SSR (Next.js), TanStack Query, HA ops + runbooks + drill postmortem, docs/AI_USAGE.md
- [x] Channels F3–F6, latency F8, knowledge + workflow tools F2

## Phase 1: local (SPECS §9)
- [x] tests/: RSpec JUnit, Vitest, Playwright report, k6 summary
- [x] screenshots 01-chat-ja-streaming-citation
- [x] 02-tool-call-order-status
- [x] 03-voice-widget
- [x] 04-avatar-interview
- [x] 05-phone-sim
- [x] 06-console-inbox
- [x] 07-operator-takeover
- [x] 08-latency-dashboard
- [x] 09-metrics-experiment
- [x] 10-help-center-ssr
- [x] 11-jaeger-trace
- [x] 12-knowledge-sources
- [x] logs/drill-kill-web.log
- [x] logs/curl-help-center-ssr.html
- [x] docs/db-performance.md (real EXPLAIN)
- [x] docs/experiments/greeting-v2.md
- [x] scripts/test-all.sh green locally (16 RSpec, 2 Vitest, 6 Playwright, k6 p95 143 ms)
- [x] CI green on main (RSpec, web, Terraform and the Docker + Playwright + k6 e2e job) after fixing the Action Cable ordering and handoff-draft races found by the first CI runs

## Phase 2: AWS (SPECS §10)
- [x] aws sts get-caller-identity OK
- [x] logs/gh-actions-deploy-run.txt (the run is the denied OIDC attempt)
- [x] logs/ecs-deployment-rollback-demo.txt (circuit breaker rollback)
- [x] screenshots 01-cloud-chat-bedrock
- [x] 02-cloud-voice-transcribe-polly
- [x] 03-cloud-avatar-visemes
- [x] 04-cloud-operator
- [x] 05-cloud-latency
- [x] 06-cloudwatch-alarms
- [x] 07-xray-trace-summary
- [x] tests/playwright-cloud/, tests/k6-cloud.txt, resources.txt
- [x] logs/drill-kill-web-aws.log

## Phase 3: destroy (SPECS §11)
- [x] scripts/destroy.sh run (proof/phase3-destroy/destroy.log)
- [x] scripts/verify-destroyed.sh output in proof/phase3-destroy/verify-destroyed.txt — nothing billable remains

## Phase 4: write-up
- [x] docs/PORTFOLIO.md, README.md final, pushed
