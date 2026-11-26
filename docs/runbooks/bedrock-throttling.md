# Runbook: Bedrock / Transcribe / Polly throttling or errors

**Symptoms:** answers slow or "sorry" fallbacks, `ThrottlingException` / `ModelNotReadyException` in web logs, `llm_first_token_ms` p95 up on the Latency page.

1. Confirm in logs (`/ecs/ai-agent-desk-web`): filter `Aws::BedrockRuntime::Errors`.
2. **Mitigate quickly:** set `LLM_PROVIDER=mock` is *not* acceptable for customers; instead lower load: the answer cache (Redis) already absorbs repeats. Check the cache hit rate on the Latency page.
3. Request a quota increase for the model in `ap-southeast-2` (Service Quotas → Bedrock), or switch `BEDROCK_MODEL_ID` to a cross-region inference profile.
4. Voice: Transcribe streaming has a concurrent-stream quota; Polly has a TPS quota. Voice degrades to the browser path (Web Speech API + `speechSynthesis`) if `SPEECH_PROVIDER=browser` is set — a config change + redeploy.
5. Escalations rise during outages (low confidence); operators see more `waiting_human` — warn the support lead.
