# PROGRESS

Resume from the first unticked item. Phases in order: 0 scaffold → 1 local → 2 AWS → 3 destroy → 4 write-up.

## Phase 0: scaffold
- [x] Repo layout, README, PROGRESS, DECISIONS, .gitignore, .gitattributes, .env.example, CI workflow

## Coverage matrix (SPECS §2)
- [x] End-to-end ownership: Rails + React console + Next.js + Postgres/Redis
- [x] Architecture ADRs in docs/adr/
- [x] Scalability/performance: stateless web ×2, Sidekiq, Redis cache, latency budget (k6 + dashboard)
- [x] Rails 8 API, Action Cable, Sidekiq (RSpec)
- [x] React + TS console and widget (Vitest/Playwright)
- [x] DB optimisation: docs/db-performance.md, strict loading, Bullet, HNSW + composite indexes
- [ ] CI/CD: GitHub Actions test + OIDC deploy with rollback
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
- [ ] scripts/test-all.sh green, CI green on main, proof index complete

## Phase 2: AWS (SPECS §10)
- [ ] aws sts get-caller-identity OK
- [ ] logs/gh-actions-deploy-run.txt
- [ ] logs/ecs-deployment-rollback-demo.txt
- [ ] screenshots 01-cloud-chat-bedrock
- [ ] 02-cloud-voice-transcribe-polly
- [ ] 03-cloud-avatar-visemes
- [ ] 04-cloud-operator
- [ ] 05-cloud-latency
- [ ] 06-cloudwatch-alarms
- [ ] 07-xray-trace-summary
- [ ] tests/playwright-cloud/, tests/k6-cloud.txt, resources.txt

## Phase 3: destroy (SPECS §11)
- [ ] scripts/destroy.sh run
- [ ] scripts/verify-destroyed.sh output in proof/phase3-destroy/verify-destroyed.txt

## Phase 4: write-up
- [ ] docs/PORTFOLIO.md, README.md final, pushed
