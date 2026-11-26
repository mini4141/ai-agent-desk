#!/usr/bin/env bash
# Reliability drill (SPECS F11): stop the web tier mid-conversation and prove the chat survives via reconnect.
#   MODE=local scripts/drill-kill-web-task.sh              kills the web container (docker compose)
#   MODE=aws   API_URL=http://<alb> scripts/drill-kill-web-task.sh   stops ONE of the two ECS web tasks
source "$(dirname "$0")/_common.sh"
MODE="${MODE:-local}"
OUT="${DRILL_LOG:-proof/phase1-local/logs/drill-kill-web.log}"
mkdir -p "$(dirname "$OUT")"
CLIENT_LOG=".local/drill-client.log"; mkdir -p .local; : > "$CLIENT_LOG"

{
  echo "# drill: kill web task mid-conversation  mode=$MODE  $(date -u +%FT%TZ)"
  node scripts/drill-client.mjs "${API_URL:-http://localhost:3000}" "${PUBLIC_KEY:-pk_demo_mirai}" > "$CLIENT_LOG" 2>&1 &
  client=$!
  for _ in $(seq 1 60); do grep -q READY_FOR_KILL "$CLIENT_LOG" && break; sleep 0.5; done

  if [ "$MODE" = "local" ]; then
    echo "[drill] docker kill web container"
    docker kill "$(docker compose ps -q web)" >/dev/null
    sleep 3
    echo "[drill] restarting web (stands in for the ECS service replacing the task)"
    docker compose up -d web >/dev/null 2>&1
  else
    export AWS_PROFILE=ai-agent-desk-deployer AWS_REGION=ap-southeast-2
    cluster=$(aws ecs list-clusters --query "clusterArns[?contains(@, 'ai-agent-desk')]|[0]" --output text)
    task=$(aws ecs list-tasks --cluster "$cluster" --service-name ai-agent-desk-web --query 'taskArns[0]' --output text)
    echo "[drill] stopping ECS task ${task##*/}"
    aws ecs stop-task --cluster "$cluster" --task "$task" --reason "reliability drill" >/dev/null
  fi

  wait "$client" && rc=0 || rc=$?
  cat "$CLIENT_LOG"
  echo "# client exit code: $rc"
  exit "$rc"
} 2>&1 | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g' | tee "$OUT"
