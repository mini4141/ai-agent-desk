# Decisions

One line each: date, decision, reason.

- 2026-11-26 — Ruby/Rails run in Docker (`ruby:3.4-slim`) rather than a host Ruby install — host has no Ruby; Docker Desktop is available and matches the ECS image.
- 2026-11-26 — Mock company backend is a small Sinatra app — SPECS allows "small Sinatra or Rails app"; keeps the demo free of external calls.
- 2026-11-26 — Reuse one Rails image for puma, sidekiq, tests — one build, parity with ECS.
