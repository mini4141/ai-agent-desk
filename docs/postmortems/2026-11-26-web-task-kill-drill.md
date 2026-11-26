# Postmortem (drill): web tier stopped mid-conversation

**Date:** 2026-11-26 · **Type:** scripted drill (`scripts/drill-kill-web-task.sh`) · **Severity:** none (no customer impact; this is a rehearsal)

## Summary
During an active chat the web tier was killed. The chat client lost its WebSocket, reconnected with back-off, received the replayed conversation `history`
(including the answer given before the kill) and completed a second question/answer on the new connection. **The conversation survived.**

## Timeline (local drill, one web container; log: `proof/phase1-local/logs/drill-kill-web.log`)
| t | Event |
|---|---|
| +1 s | Client opens a widget session, asks question 1, receives the streamed answer |
| +3 s | `docker kill` of the web container; socket closes |
| +3 s … +59 s | Client retries every second (connection refused while the single container boots in development mode) |
| +60 s | Reconnect succeeds; `history` replays 2 messages; earlier answer present |
| +61 s | Question 2 answered on the new connection — drill passed |

In AWS the same script (`MODE=aws`) stops **one of two** ECS web tasks; the ALB routes the reconnect to the surviving task within seconds, so recovery is bounded
by the client back-off, not by task start-up. That run is recorded in `proof/phase2-cloud/logs/`.

## What went well
- State lives in PostgreSQL and Redis, not in the web process, so any task can resume any conversation.
- `ConversationChannel#subscribed` replays history, and the widget de-duplicates by message id.

## What was slow / could be better
- Local recovery took ~57 s because there is a single development-mode container; production has ≥ 2 tasks and ECS replaces the stopped one.
- A turn that was *in flight* when the task died is lost (the customer must re-ask). Follow-up: persist the customer message first (already done) and let the widget auto-resend the last unanswered question after `history` shows no AI reply.

## Action items
1. Widget: after reconnect, if the last history message is from the customer, re-send it once. (Owner: widget, not done.)
2. Keep `minimum_healthy_percent = 100` on the web service (done in Terraform).
3. Add the reconnect runbook link to the web 5xx alarm description (done).
