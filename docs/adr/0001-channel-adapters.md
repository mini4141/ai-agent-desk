# ADR 0001: Channels are adapters around one agent core

**Status:** accepted · **Date:** 2026-11-26

## Context
The platform serves web chat, browser voice, a talking avatar and a (simulated) phone line. The temptation is one controller/channel per
surface, each with its own copy of retrieval, prompting and tool handling. That multiplies the places latency and quality bugs can hide.

## Decision
The core is `Conversation` + `Message` + `AgentRun`. A channel does two things only:

1. **In:** turn its input into a text turn (`ConversationChannel#ask`, `VoiceChannel#audio_end` after STT, `PhoneStreamChannel` `mark utterance_end` after STT).
2. **Out:** render agent output through a `ChannelAdapter` (`WebChatAdapter`, `VoiceWebAdapter`, `AvatarAdapter`, `PhoneSimAdapter`): text tokens, sentence-level TTS audio + visemes, or 8 kHz mu-law frames.

`AgentRun` only knows the adapter interface (`on_token`, `on_tool`, `finish`, `speaks?`, `first_audio_ms`). Adding a channel means a new adapter and an input class;
`AgentRun` is untouched. The phone adapter was added last and needed no change to the core.

## Consequences
- One place to enforce escalation, caching, citations and timing (`stt_ms`, `retrieval_ms`, `llm_first_token_ms`, `llm_total_ms`, `tts_first_audio_ms`, `end_to_end_ms`).
- Adapters run inside the Action Cable worker thread, so TTS for each sentence runs in its own thread and is sequenced client-side by `seq`.
- Token events are coalesced (30 ms) in the base adapter, which cut CPU per turn enough to meet the TTFT budget on a laptop (see `scripts/k6-chat.js`).
