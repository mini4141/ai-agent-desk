# Runbook: web 5xx rate or p95 latency alarm

**Alarms:** `ai-agent-desk-alb-5xx`, `ai-agent-desk-alb-p95-latency` (CloudWatch, ALB metrics). **Impact:** chat/voice/console degraded.

1. **Scope it.** CloudWatch dashboard `ai-agent-desk`: is it one target or both? `aws ecs describe-services --cluster ai-agent-desk --services ai-agent-desk-web` — running vs desired, recent events.
2. **One task unhealthy:** ECS replaces it (ALB health check on `/up`). Confirm a new task reaches RUNNING. Customers reconnect automatically (widget Action Cable backoff + `history` replay).
3. **Both tasks erroring:** check logs (`/ecs/ai-agent-desk-web`, structured JSON; filter `"status":500`). Common causes: DB/Redis unreachable (security groups, RDS failover), Bedrock throttling (see *bedrock-throttling.md*), bad deploy.
4. **Bad deploy:** the ECS deployment circuit breaker rolls back automatically; verify with `describe-services` events. Manual: `aws ecs update-service --task-definition <previous>`.
5. **Capacity:** if CPU > 70 % sustained, raise `desired_count` (Terraform var `web_desired_count`) — Action Cable work is CPU-bound.
6. **After:** note timeline in `docs/postmortems/`.
