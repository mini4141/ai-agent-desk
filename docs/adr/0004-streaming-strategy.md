# ADR 0004: Streaming strategy and the latency budget

**Status:** accepted · **Date:** 2026-11-26

## Budget
First response under **1.5 s** for chat and first audio under **2.5 s** for voice (local mock targets are tighter: k6 TTFT p95 < 400 ms).
Per turn we store `stt_ms`, `retrieval_ms`, `llm_first_token_ms`, `llm_total_ms`, `tts_first_audio_ms`, `end_to_end_ms` on `messages.timings`,
export them to Prometheus (`agent_stage_ms`) and CloudWatch (EMF), and show p50/p95 against the budget on the Latency page.

## Decisions
1. **Stream everything.** Bedrock `converse_stream` tokens are pushed to the client as they arrive. Tool calls are executed mid-stream and the second model round streams too.
2. **Start TTS on the first sentence.** `SentenceSplitter` releases complete sentences while tokens are still arriving; each sentence is synthesised in its own thread and sequenced by `seq`.
3. **Cache frequent answers in Redis** (company + normalised question, tool-free answers only, 10 min). Cache hits skip retrieval and the LLM entirely.
4. **Coalesce token broadcasts** (first token immediately, then every 30 ms) so Redis/Action Cable work per turn stays small.
5. **Retrieval first, cheap.** One HNSW query (tenant-filtered) before the model call; low confidence escalates to a human instead of letting the model guess.
6. **Measure honestly.** `end_to_end_ms` is "turn start (including STT) to first user-visible output", not total duration.

## Consequences
The mock providers make local numbers a lower bound; the cloud run records the real Bedrock/Transcribe/Polly numbers as they are (`proof/phase2-cloud`).
