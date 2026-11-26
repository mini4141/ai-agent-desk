# Decisions

One line each: date, decision, reason.

- 2026-11-26 — Ruby/Rails run in Docker (`ruby:3.4-slim`) rather than a host Ruby install — host has no Ruby; Docker Desktop is available and matches the ECS image.
- 2026-11-26 — Mock company backend is a small Sinatra app — SPECS allows "small Sinatra or Rails app"; keeps the demo free of external calls.
- 2026-11-26 — Reuse one Rails image for puma, sidekiq, tests — one build, parity with ECS.
- 2026-11-26 — Authentication is hand-written in the Rails 8 generator's shape (`Session` model, `has_secure_password`, signed cookie) plus HS256 JWT — the generator targets full-stack apps; this API-only app needs the cookie middleware added explicitly.
- 2026-11-26 — Phone channel is the same Action Cable server mounted at `/phone-sim/stream` (`PhoneStreamChannel`) rather than a raw WebSocket library — keeps auth/tenancy and avoids a second server; events inside are Twilio-Media-Streams-shaped JSON.
- 2026-11-26 — Mock STT returns a caller-supplied transcript hint (Web Speech API result or test hook) — headless Chromium has no speech recognition; the audio path (frames over Action Cable, ordering, buffering) still runs for real.
- 2026-11-26 — Mock embeddings are hashed word/CJK-bigram vectors (1024 dims) — deterministic offline retrieval that behaves sensibly for the demo FAQ; confidence threshold 0.25 (mock) / 0.30 (Titan).
- 2026-11-26 — Demo sites are served by the same Sinatra service as the mock company backend — one fewer ECS service/image; ingestion is restricted to its host (`INGEST_ALLOWED_HOSTS`).
- 2026-11-26 — Frontends run on the host in local dev (Vite/Next dev servers), Rails/Sidekiq/data/observability in Docker — avoids slow node_modules bind mounts on Windows; ports 5173/5175/3001.
- 2026-11-26 — Puma cluster mode (3 workers) + YJIT + coalesced token broadcasts locally; prometheus-client DirectFileStore for multi-process metrics — single MRI process could not hold k6 TTFT p95 < 400 ms (see ADR 0004).
- 2026-11-26 — k6 scenario models one chatting customer per VU (one session + WebSocket, new question every 1–2 s) instead of a session per request — matches real chat and avoids measuring session-creation overhead.
- 2026-11-26 — Rolled-up business metrics exclude synthetic visitors (`k6-*`, `drill-*`, `smoke-*`) — load tests must not distort deflection; seed history is flagged `simulated=true` and documented as such.
- 2026-11-26 — Cloud: Terraform state stays local, so the GitHub OIDC workflow deploys the application tier (build → ECR → new task-definition revisions → rolling update with circuit breaker) via `scripts/ecs-deploy-image.sh`; infrastructure is applied from the PC by `scripts/deploy.sh`. ECS services use `ignore_changes = [task_definition]` so both paths coexist.
- 2026-11-26 — Cloud: ECS tasks run in public subnets with public IPs (no NAT gateway, per cost rules); RDS/ElastiCache sit in private subnets with no internet route and security groups admitting only the app tier.
- 2026-11-26 — Cloud: CloudFront serves the console (S3 + OAC) and also proxies `/api`, `/cable`, `/widget`, `/phone-sim` to the ALB, so the HTTPS console never makes mixed-content calls to an HTTP ALB (no custom domain/ACM, per cost rules). Phone simulator is published at `/phone/` in the same bucket.
- 2026-11-26 — Cloud LLM is Claude Haiku 5.5 through the `au.` inference profile (cheap, fast) with Titan Text Embeddings v2; Transcribe streaming and Polly neural (Tomoko ja-JP, Joanna en-US).
- 2026-11-26 — Rails production image gets the widget bundle from `pnpm build:widget` run before `docker build` (no Node stage in the Rails Dockerfile); help-center reads its API URL at runtime so one image fits every environment.
