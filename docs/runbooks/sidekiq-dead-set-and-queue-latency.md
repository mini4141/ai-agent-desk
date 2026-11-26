# Runbook: Sidekiq dead set or queue latency alarm

**Alarms:** `ai-agent-desk-sidekiq-queue-latency`, `ai-agent-desk-sidekiq-dead-set` (CloudWatch metrics emitted by `QueueHealthJob` as EMF every minute).

1. **Is the worker alive?** `aws ecs describe-services ... ai-agent-desk-worker`; logs `/ecs/ai-agent-desk-worker`. No `queue_health` log line for 3 minutes = worker down.
2. **Latency high, worker alive:** a slow job is hogging threads. Look for ingestion jobs (`IngestSourceJob`) embedding a large source; Bedrock Titan throttling shows as retries.
3. **Dead set growing:** jobs exhausted retries (`ingest` 3, `webhook` 5, `rollup` 3). Inspect via Sidekiq console task: `Sidekiq::DeadSet.new.first.item` — read `error_message`.
   - Webhook failures: customer endpoint down. Retry later with `Sidekiq::DeadSet.new.retry_all` once fixed.
   - Ingest failures: source URL outside the allow-list (`INGEST_ALLOWED_HOSTS`) or parse error; fix, then `POST /api/v1/knowledge_sources/:id/reindex`.
4. **Never** clear the dead set without reading entries first.
