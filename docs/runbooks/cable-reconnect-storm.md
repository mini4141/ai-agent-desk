# Runbook: reconnect storm after a deploy or task loss

When a web task dies, every WebSocket on it reconnects at once (Action Cable client backoff, ~3 s jitter).

1. **Expect it.** After a rolling deploy the surviving task absorbs reconnects; CPU spikes briefly. The `history` replay on `subscribed` is one indexed query (`idx_messages_conversation_created`).
2. **If it does not settle:** check ALB `ActiveConnectionCount`, web CPU and DB connections (`DB_POOL` × tasks must stay below RDS `max_connections`).
3. **Mitigations:** raise `desired_count`; temporarily raise `CABLE_WORKERS`; keep the deployment `minimum_healthy_percent=100` so a new task is healthy before an old one stops (already set in Terraform).
4. **Verify recovery:** `scripts/drill-kill-web-task.sh` (local or `MODE=aws`) proves a conversation resumes with its history.
