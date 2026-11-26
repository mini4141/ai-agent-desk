#!/usr/bin/env bash
# Captures proof for a phase into proof/<phase>/ (screenshots via Playwright, logs via CLI/curl).
#   scripts/capture-proof.sh phase1-local
#   scripts/capture-proof.sh phase2-cloud     (needs infra outputs; see scripts/deploy.sh)
source "$(dirname "$0")/_common.sh"
phase="${1:?usage: capture-proof.sh phase1-local|phase2-cloud}"
mkdir -p "proof/$phase"/{screenshots,logs,tests}

redact() { sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g; s/(AKIA|ASIA)[A-Z0-9]{16}/<ACCESS_KEY>/g'; }

case "$phase" in
phase1-local)
  curl -s localhost:3001/mirai/help > "proof/$phase/logs/curl-help-center-ssr.html"
  grep -c "メールアドレスとパスワードで無料登録できます" "proof/$phase/logs/curl-help-center-ssr.html" > "proof/$phase/logs/curl-help-center-ssr.check.txt" || true
  node scripts/smoke-chat.mjs http://localhost:3000 pk_demo_mirai "注文 A-1023 はいつ届きますか？" 2>&1 | tee "proof/$phase/logs/smoke-chat-order.log"
  docker compose logs --no-color --tail 200 web 2>&1 | grep -E '"controller":"ConversationChannel"|"path":' | head -40 | redact > "proof/$phase/logs/rails-structured-json.log" || true
  docker compose logs --no-color --tail 60 worker 2>&1 | redact > "proof/$phase/logs/sidekiq.log" || true
  curl -s localhost:3000/metrics | grep -E "^agent_" > "proof/$phase/logs/prometheus-agent-metrics.txt" || true
  (cd web/e2e && CAPTURE_PROOF=1 PROOF_DIR="$ROOT_WIN/proof/$phase/screenshots" PW_REPORT_DIR="$ROOT_WIN/proof/$phase/tests/capture" pnpm exec playwright test tests/proof.spec.ts)
  ;;
phase2-cloud)
  : "${API_URL:?set API_URL (ALB)}" "${HELP_URL:?set HELP_URL}" "${CONSOLE_URL:?set CONSOLE_URL}"
  (cd web/e2e && CAPTURE_PROOF=1 PROOF_SET=cloud PROOF_DIR="$ROOT_WIN/proof/$phase/screenshots" PW_REPORT_DIR="$ROOT_WIN/proof/$phase/tests/capture" pnpm exec playwright test tests/proof.spec.ts)
  ;;
esac
echo "proof captured in proof/$phase"
