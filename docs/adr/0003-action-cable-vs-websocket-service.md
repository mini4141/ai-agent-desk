# ADR 0003: Action Cable (Redis adapter) instead of a separate WebSocket service

**Status:** accepted · **Date:** 2026-11-26

## Context
Real-time needs: streamed chat tokens, operator inbox/transcripts, voice audio frames, phone media frames. Alternatives: Node/Go WebSocket gateway, AnyCable, API Gateway WebSockets.

## Decision
Use Rails Action Cable with the Redis adapter, in the same web tasks as the REST API. The ALB supports WebSockets and stickiness is not required:
any web task can serve any connection because state lives in PostgreSQL and Redis. `/cable` serves browsers and the console; `/phone-sim/stream` is the same server mounted at a telephony-style path.

## Why
- Auth, tenancy (`acts_as_tenant`), Pundit and the models are reused as is; a second service would duplicate them or call back over HTTP on every frame.
- **Reconnect is the failure story:** the widget re-subscribes and `ConversationChannel#subscribed` replays `history`, so killing a task mid-chat loses nothing (drill in `scripts/drill-kill-web-task.sh`, postmortem in `docs/postmortems/`).
- Voice/phone frames are ~200 ms chunks, well within Action Cable's throughput for this workload; frames carry sequence numbers because the worker pool can reorder them (`UtteranceBuffer`).

## Consequences
- Action Cable worker threads are CPU-bound in MRI. We scale out with puma cluster mode + more tasks and keep the per-turn CPU low (token coalescing, YJIT).
- A dedicated gateway (AnyCable/Go) is the escape hatch if concurrency grows past what 2–4 small tasks can serve; channels are thin, so the move is mechanical.
