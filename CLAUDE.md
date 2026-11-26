# CLAUDE.md — ai-agent-desk

These are the engineering rules for Claude Code on this repository. You work **fully autonomously**. Don't stop to ask the user questions. When something is ambiguous, pick the simplest option that keeps every stack item in §2 covered. Record it in `docs/DECISIONS.md` (one line: date, decision, reason) and keep going. Read `SPECS.md` end to end before writing any code. It is the source of truth for features, architecture and proof.

## 1. Project at a glance

| | |
|---|---|
| Project | AI Agent Desk: a multi-channel AI customer-support platform (Rails, React, Postgres, Redis, ECS) with web chat, voice, avatar and phone channels |
| Repo | public GitHub repo `ai-agent-desk`. `origin` is already configured and the default branch is `main` |
| Target role | Full Stack Engineer, AI agent platform (Ruby on Rails, React/TypeScript, PostgreSQL/Redis, AWS ECS) |
| Pitch | Companies plug their own knowledge and workflows into one Rails platform. AI agents then answer customers over web chat, browser voice, a talking avatar and a simulated phone line, fast enough to feel natural, handing off to human operators when needed. Every conversation feeds latency budgets and business metrics such as deflection and CSAT, and an experiment framework proves which changes improved them. |
| Priority | **Breadth of the tech stack beats depth of business logic.** Every technology in §2 must appear in running code and be visible in the proof. Full validation, edge cases and complete domain rules are out of scope. |

## 2. Mandatory tech stack

| Area | Technology |
|---|---|
| Backend | **Ruby 3.4 + Rails 8** (API + Hotwire-free JSON API, **Action Cable** with the Redis adapter for real-time text/voice/operator channels), **Sidekiq** on Redis (ingestion, embeddings, webhooks, metrics rollups), `acts_as_tenant` (multi-tenancy), **Pundit** (authorisation), Rails 8 authentication generator + JWT for the API, Active Record encryption, `rack-attack` rate limiting, Flipper feature flags/experiments |
| Data | **PostgreSQL 17** with **pgvector** (`neighbor` gem) for per-company knowledge retrieval; **Redis 7** for caching (Rails cache store, answer cache), Action Cable, Sidekiq |
| Frontend | **React 19 + TypeScript** + Vite operator & admin console with **TanStack Query** (server-state caching, optimistic updates) and React Router; embeddable chat/voice/avatar widget (React, Shadow DOM) |
| SSR | **Next.js** (App Router) public **help-center** site per company: server-rendered knowledge articles (SEO) with the widget embedded |
| AI | **Amazon Bedrock** (Claude via the streaming Converse API with tool use; Titan Text Embeddings v2), plus a deterministic **mock** provider for tests/offline. Locale-aware: Japanese first, English second |
| Voice / avatar | Browser mic → Action Cable audio frames → **Amazon Transcribe streaming** (ja-JP / en-US) → agent → **Amazon Polly** neural TTS with **viseme speech marks** driving an SVG talking avatar; local fallback: browser Web Speech API + `speechSynthesis` |
| Phone channel (simulated) | A phone-line simulator page that streams 8 kHz μ-law audio over WebSocket using a Twilio-Media-Streams-shaped protocol, handled by a channel adapter in Rails. No real phone numbers |
| Observability | **OpenTelemetry** (Ruby + browser) with distributed tracing across widget → Rails → Sidekiq → Bedrock; Jaeger + Prometheus + Grafana locally; **AWS X-Ray** (ADOT sidecar) + CloudWatch metrics/alarms in AWS; Rails structured JSON logs (lograge) |
| Containers / AWS | Docker, **Amazon ECS on Fargate** (web ×2 across 2 AZs, Sidekiq worker, Next.js), ALB (WebSockets), RDS PostgreSQL, ElastiCache Redis, S3, Secrets Manager, ECR, CloudFront (console SPA), Bedrock, Transcribe, Polly |
| CI/CD | **GitHub Actions**: test on every push; **automated deployment** via GitHub OIDC → AWS (manual `workflow_dispatch` + on tag), ECS rolling deploy with deployment circuit breaker + automatic rollback |
| IaC | **Terraform** |
| Tests | RSpec (models, requests, channels, jobs), Vitest + React Testing Library, Playwright e2e, k6 latency/load smoke |

Don't swap an item for an alternative. If a library is unavailable or broken, use the closest equivalent and log the swap in `docs/DECISIONS.md`.

## 3. Environment

- The host is a **Windows 11 PC**. Claude Code's shell is Git Bash, and the container runtime is Docker Desktop (WSL2 backend). Write automation as POSIX `bash` scripts under `scripts/` and use forward-slash paths. Add a `.gitattributes` with `* text=auto eol=lf` so scripts keep LF line endings.
- Prerequisites: Ruby 3.4 + Bundler, Node.js 24 + pnpm, Docker Desktop, Terraform, AWS CLI v2, k6. If one is missing, install it with `winget` or the official installer and record the version in `docs/DECISIONS.md`.
- The `gh` CLI is logged in to the owner's GitHub account, and AWS CLI v2 is installed.
- Don't use Bitnami charts or images (their free catalogue has been retired). Use official upstream images and charts.

## 4. AWS account rules

- Profile: **`ai-agent-desk-deployer`**. Always pass it explicitly, either as `--profile ai-agent-desk-deployer` or by exporting `AWS_PROFILE=ai-agent-desk-deployer` inside the scripts. Never use the default profile or any other profile.
- Region: **`ap-southeast-2`** for everything except global services such as CloudFront and IAM.
- The profile has `PowerUserAccess` + `IAMFullAccess`. Start Phase 2 with `aws sts get-caller-identity --profile ai-agent-desk-deployer`. If that fails, stop and write the reason at the top of `PROGRESS.md`.
- Use AWS only. Where a requirement names Azure, GCP or another hyperscaler, use the AWS equivalent stated in `SPECS.md`.
- IaC: Terraform (`infra/`). Don't create resources by hand in the console: every cloud resource comes from code in `infra/`. Keep IaC state local and gitignored.
- Tag every resource with `Project=ai-agent-desk`, `Ephemeral=true`, `ManagedBy=<tool>` and `Owner=alvieirvansyah`.
- Deployment runs **from this PC via scripts** (`scripts/deploy.sh`, `scripts/destroy.sh`). GitHub Actions only builds and tests, and never holds AWS credentials. **Exception for this project:** the job post asks for GitHub-based workflows with automated deployment, so `.github/workflows/deploy.yml` deploys through **GitHub OIDC** (no stored keys). Terraform module `infra/github-oidc/` creates the IAM role trusted only by `repo:<owner>/ai-agent-desk:*`. The account-wide OIDC provider `token.actions.githubusercontent.com` may already exist (other projects share the account). Detect it with `aws iam list-open-id-connect-providers` and reference the existing one with a data source instead of creating a duplicate. Only destroy it in Phase 3 if this project created it (record that in `infra/.oidc-created`, gitignored). If the account's SCP blocks the OIDC setup, fall back to `scripts/deploy.sh` from this PC, log it in `docs/DECISIONS.md` and keep the workflow file as documentation.

## 5. Phases and gates

Work strictly in order. A phase is done only when its proof exists (§8) and its items are ticked in `PROGRESS.md`. Commit and push at the end of every phase.

1. **Phase 0, scaffold.** Set up the repo layout from `SPECS.md` §4. Create `README.md`, `PROGRESS.md` (copy every checklist item from `SPECS.md` §2 and §9–§11 into it), `docs/DECISIONS.md`, `.gitignore`, `.gitattributes`, `.env.example` and the CI workflow.
2. **Phase 1, local.** Build every feature in `SPECS.md` §5. Everything runs on this PC with Docker and local tooling, and makes **no AWS calls**: use the local stand-ins listed in `SPECS.md`. Run the full test suite, then capture proof into `proof/phase1-local/`. Phase 1 counts as "ready for next" only when `scripts/test-all.sh` is green, the CI run on `main` is green, and the proof index is complete.
3. **Phase 2, AWS showcase.** Deploy with `scripts/deploy.sh`, run the smoke/e2e tests against the cloud endpoints and capture proof into `proof/phase2-cloud/`. Keep the stack alive only as long as capturing takes, with a target of **under 2 hours**.
4. **Phase 3, destroy.** Right after capturing, run `scripts/destroy.sh` and then `scripts/verify-destroyed.sh`, and save the output to `proof/phase3-destroy/`. This phase is **mandatory even if Phase 2 partly failed**. Never end a session with cloud resources running.
5. **Phase 4, write-up.** Write `docs/PORTFOLIO.md`. It needs the problem, an architecture diagram (Mermaid), a stack → requirement table, the key screenshots (relative links into `proof/`), what was hard, the approximate AWS cost and how to reproduce. This file becomes a technical page on alvieirvansyah.com.

## 6. Engineering rules

- Keep it simple and conventional: idiomatic layout for each language, small modules, no premature abstraction, no dead code.
- Configure through environment variables, with a committed `.env.example`. Real `.env` files are gitignored.
- **Never commit secrets.** That includes credentials, IaC state, `.terraform/`, `cdk.out/`, kubeconfigs, private keys and certificates. Generate local dev keys and certs into a gitignored `.local/` folder.
- Every HTTP service exposes a health endpoint (`/healthz` or the framework idiom) and logs structured JSON to stdout.
- Pin versions: commit lockfiles and pin container images to at least a minor tag.
- Use one command for each job:
  - `scripts/dev-up.sh` starts everything locally and `scripts/dev-down.sh` stops it.
  - `scripts/seed.sh` loads demo data. Start-up may run it automatically so that demos never start empty.
  - `scripts/test-all.sh` runs every test layer.
  - `scripts/capture-proof.sh <phase>` captures the proof for a phase.
- Keep `README.md` current. It covers what the project is, the architecture diagram, a quickstart, deploy/destroy, a link to `proof/README.md` and `docs/PORTFOLIO.md`, and the CI badge.
- Don't put the hiring company's name anywhere in the repo. Describe the target role generically.
- `docs/AI_USAGE.md`: briefly note how AI coding tools were used and how their output was reviewed and tested.

## 7. Testing rules

- Tests are **shallow by design**: one happy-path test per feature or flow is enough. Don't write exhaustive validation or edge-case tests.
- Required layers: RSpec (one per feature: tenancy isolation, RAG answer with citations, workflow action call, handoff, metrics rollup, Action Cable chat channel), Vitest + RTL (inbox list with TanStack Query, live transcript), Playwright e2e (web chat answer → escalate → operator takes over → resolve → metrics update; voice/avatar via the fake-media Chromium flags), k6 (time-to-first-token p95 against the latency budget).
- `scripts/test-all.sh` runs every local layer and exits non-zero on failure. CI runs every layer that doesn't need the cloud.
- Save test output as files (JUnit XML, an HTML report or a plain log) under the current phase's `proof/.../tests/`.

## 8. Proof rules

Proof is the deliverable. Use this folder layout:

```
proof/
  README.md                 # index: each artifact on one line, with what it proves
  phase1-local/
    screenshots/            # PNG, named NN-what-it-shows.png
    logs/                   # captured service logs and CLI output
    tests/                  # test reports
  phase2-cloud/
    screenshots/  logs/  tests/
    resources.txt           # deployed AWS resources (from IaC outputs / describe calls)
  phase3-destroy/
    verify-destroyed.txt
```

- Capture screenshots with a script (`scripts/capture-proof.sh`, driving Playwright headless), never by hand, so they can be reproduced. The screenshots listed in `SPECS.md` are the minimum.
- There is no AWS console login, so render AWS-side visuals from the CLI. For example, `aws cloudwatch get-metric-widget-image` renders a metrics graph as a PNG. Otherwise save CLI `describe`/`get` output as logs.
- Before saving logs or CLI output, redact 12-digit AWS account IDs (`sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g'`), access keys, tokens, passwords and the deployer's public IP.
- Proof must show the system **working**, with real data flowing through it, and not just "deployed".

## 9. Cost and safety guardrails (AWS)

- Use the smallest viable sizes: Fargate web 0.5 vCPU / 1 GB × 2, worker 0.25 vCPU / 0.5 GB × 1, Next.js 0.25 vCPU / 0.5 GB × 1, RDS `db.t4g.micro` single-AZ, ElastiCache `cache.t4g.micro`, one ALB, CloudFront PriceClass_100, Bedrock/Transcribe/Polly on demand (cap demo usage at about 30 conversations and 10 voice minutes).
- **No NAT gateways.** Also no multi-AZ databases, provisioned IOPS, reserved capacity or Savings Plans, Route 53 domains, or Marketplace subscriptions.
- Databases: `deletion_protection = false`, skip the final snapshot and keep backup retention minimal. S3 buckets are force-destroyable and ECR repos force-deletable. CloudWatch log groups get 1-day retention and are created by IaC, so they get destroyed with it.
- Public app endpoints are fine for the showcase. Keep databases private: their security groups admit only the app tier. Don't open SSH or database ports to `0.0.0.0/0` and don't use SSH at all. Use SSM if you need a shell.
- Don't send real emails or SMS, and don't call paid third-party APIs. Anything external is mocked unless `SPECS.md` says otherwise.
- `scripts/destroy.sh` must be idempotent and safe to re-run. It first deletes anything that would block the IaC destroy: scale ECS services to 0, empty the S3 buckets and ECR repos; delete the GitHub OIDC role (and the provider only if `infra/.oidc-created` says this project made it).
- `scripts/verify-destroyed.sh` lists anything still tagged `Project=ai-agent-desk` (`aws resourcegroupstaggingapi get-resources`) and runs the specific checks in `SPECS.md` §11. It exits non-zero if anything billable remains. The tagging API can show resources for a few minutes after deletion, so confirm each hit with a direct describe call before failing.

## 10. Git and CI

- Use Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `infra:`, `chore:`). Commit small and often, and push to `origin main` at least at the end of every phase.
- `.github/workflows/ci.yml` runs build, lint and the cloud-free tests on every push and pull request. Keep it green.
- Never force-push `main`. Never commit build output, dependency folders (`node_modules`, `target`, `bin`, `obj`, `.venv`) or state files.

## 11. Project-specific rules

- **One platform, many channels.** The core is `Conversation` + `Message` + `AgentRun`. Channels (`web_chat`, `voice_web`, `avatar`, `phone_sim`) are adapters that turn their input into text turns and render the agent output back (text, TTS audio, visemes, μ-law audio). Adding a channel must not touch the agent core.
- **Each company brings its own data and workflows.** Knowledge sources (Markdown/PDF/URL from the bundled demo sites only) are chunked, embedded and searched with pgvector, filtered by `company_id`. Workflow actions are company-configured HTTP tools (for example `check_order_status`, `book_callback`) with a JSON schema, called by the agent through tool use and signed with HMAC. Bundle a mock company backend so the demo never calls external systems.
- **Latency is a product requirement.** Track per turn: `stt_ms`, `retrieval_ms`, `llm_first_token_ms`, `llm_total_ms`, `tts_first_audio_ms`, `end_to_end_ms`. The budget is end-to-end first response under 1.5 s for chat and first audio under 2.5 s for voice (local mock targets are tighter). Stream tokens to the client, start TTS on the first sentence, and cache frequent answers in Redis. Show the budget on a dashboard.
- **Humans work alongside the AI.** Escalation triggers are low confidence, the customer asking for a human, or a sensitive intent. The operator console gets the conversation live (Action Cable), with an AI-drafted reply the operator can edit and send, and can hand the conversation back to the AI.
- **Business metrics and experiments.** Nightly and on-demand Sidekiq rollups compute deflection rate, handoff rate, CSAT (end-of-chat thumbs), average handle time and conversion to workflow action. Flipper runs one A/B experiment (`greeting_v2`: a proactive greeting with suggested questions) with sticky assignment, and the dashboard shows the metric delta with a sample-size note. Write the result up in `docs/experiments/greeting-v2.md`.
- **Japanese is the primary working language** of the target team: the console, help center and agent prompts support `ja` (default) and `en`; seed data includes one Japanese and one English company. Transcribe and Polly use ja-JP voices for the Japanese company.
- **Database performance as an artifact:** `config.active_record.strict_loading_by_default = true` in development, the Bullet gem in tests, and `docs/db-performance.md` with EXPLAIN ANALYZE before/after for the inbox query (composite index + counter cache) and the vector search (HNSW index + tenant filter).
- **High availability and incident response:** two web tasks in two AZs, ALB health checks on `/up`, graceful Action Cable reconnect, Sidekiq retries with a dead-set alarm, and CloudWatch alarms (5xx rate, p95 latency, Sidekiq queue latency). Write runbooks in `docs/runbooks/`, and a postmortem from a scripted drill (`scripts/drill-kill-web-task.sh`: stop one task mid-conversation; the conversation survives through reconnect).
- Security: tenant isolation is enforced by `acts_as_tenant` plus Pundit scopes. API keys and webhook secrets use Active Record encryption. Customer PII (emails, phone numbers) is redacted in logs and traces. The widget authenticates with a public key plus an allowed-origins check, and rate limits apply per IP and per company.

## 12. Definition of done

- [ ] Every stack item in §2 is used in running code. Cross-check with the coverage matrix in `SPECS.md` §2 and tick each row in `PROGRESS.md`.
- [ ] Phase 1 proof is complete, and all tests are green locally and in CI.
- [ ] Phase 2 proof is complete: cloud screenshots, a cloud test run and the resource list.
- [ ] Phase 3: everything is destroyed and `verify-destroyed.txt` shows nothing billable left.
- [ ] `docs/PORTFOLIO.md` and `README.md` are written, and everything is committed and pushed.
