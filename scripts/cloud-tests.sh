#!/usr/bin/env bash
# Runs the Playwright e2e suite and a small k6 latency test against the deployed AWS stack (reads .local/cloud.env).
source "$(dirname "$0")/_common.sh"
source .local/cloud.env
OUT="proof/phase2-cloud/tests"; mkdir -p "$OUT"
bash scripts/make-fake-speech.sh >/dev/null
export VOICE_HEARD="返品" VOICE_EXPECT="返品" FAKE_AUDIO="$ROOT_WIN/.local/speech-ja.wav" HOLD_MS=4500 PW_REPORT_DIR="$ROOT_WIN/$OUT/playwright-cloud"
status=0
(cd web/e2e && pnpm exec playwright test --retries=1 ) 2>&1 | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g' | tee "$OUT/playwright-cloud.log" || status=1
# cap demo usage: 5 virtual users, 40 s (~5 conversations)
k6 run -e BASE_URL="$API_URL" -e VUS=5 -e DURATION_S=40 -e TTFT_P95=1500 -e LOAD_TEST_TOKEN="$LOAD_TEST_TOKEN" -e SUMMARY_JSON="$ROOT_WIN/$OUT/k6-cloud-summary.json" scripts/k6-chat.js 2>&1 | grep -vE "^running|^chat +\[" | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g' | tee "$OUT/k6-cloud.txt" || status=1
exit $status
