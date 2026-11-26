# How AI coding tools were used

This repository was built with **Claude Code** (an AI coding agent) working autonomously from `CLAUDE.md` and `SPECS.md`.

**What the agent did:** scaffolded the Rails 8 / React / Next.js / Terraform code, wrote the tests, ran the stack in Docker, debugged failures
from logs and traces, captured the proof, and wrote the docs.

**How the output was reviewed and tested** (nothing is accepted because "the model wrote it"):

- **Executable specs first-class:** RSpec (tenancy isolation, RAG answer with citations, signed workflow-tool call, handoff, metrics rollup, Action Cable channel),
  Vitest + React Testing Library, Playwright end-to-end (chat → escalate → operator takeover → resolve → metrics; fake-microphone voice/avatar; phone simulator; SSR curl check) and a k6 latency test.
  `scripts/test-all.sh` runs all of them; CI runs the cloud-free ones.
- **Failures were debugged, not papered over.** Examples from this build: a lambda-arity bug in the Action Cable tenant wrapper found by the browser test (the unit tests did not cover the trace-context path);
  a 5× latency problem found by k6 and traced to dev logging, per-token broadcasts and a single Ruby process (fixed with token coalescing, YJIT, puma cluster mode and a realistic per-user k6 scenario).
- **Evidence over claims:** `docs/db-performance.md` contains real `EXPLAIN ANALYZE` output from a generated dataset; the experiment write-up states that its history is simulated.
- **Security review points checked by hand:** tenant scoping (`acts_as_tenant` with `require_tenant`), Pundit role checks, HMAC-signed tool calls, encrypted secrets (Active Record encryption), PII redaction in logs/spans, the ingestion host allow-list, rate limits.
- **Infrastructure:** Terraform is applied only through scripts; destroy is verified by `scripts/verify-destroyed.sh` against the tagging API and direct describe calls.
- **Limits of this approach:** the model can be confidently wrong about library APIs (e.g. SDK event-stream handlers); anything touching real AWS services was only trusted after it ran against AWS in Phase 2.
