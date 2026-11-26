#!/usr/bin/env bash
# Rolls the application tier to an image tag: new task-definition revision per service + rolling update.
# Used by scripts/deploy.sh and by .github/workflows/deploy.yml (so both deploy paths behave the same).
#   scripts/ecs-deploy-image.sh <tag> [web worker help-center company-backend]
# The ECS deployment circuit breaker rolls a failing deployment back automatically.
set -euo pipefail
cd "$(dirname "$0")/.."
export AWS_PAGER=""
TAG="${1:?usage: ecs-deploy-image.sh <tag> [services...]}"; shift || true
SERVICES=("$@"); [ ${#SERVICES[@]} -gt 0 ] || SERVICES=(web worker help-center company-backend)
CLUSTER="${CLUSTER:-ai-agent-desk}"
mkdir -p .local

for svc in "${SERVICES[@]}"; do
  name="ai-agent-desk-$svc"
  current=$(aws ecs describe-services --cluster "$CLUSTER" --services "$name" --query 'services[0].taskDefinition' --output text)
  aws ecs describe-task-definition --task-definition "$current" --query taskDefinition --output json \
    | node scripts/ecs-new-taskdef.mjs "$TAG" > ".local/taskdef-$svc.json"
  new=$(aws ecs register-task-definition --cli-input-json "file://.local/taskdef-$svc.json" --query 'taskDefinition.taskDefinitionArn' --output text)
  echo "[$svc] $current -> $new"
  echo "$new" > ".local/new-$svc.arn"
  aws ecs update-service --cluster "$CLUSTER" --service "$name" --task-definition "$new" >/dev/null
done

for svc in "${SERVICES[@]}"; do
  name="ai-agent-desk-$svc"
  echo "[$svc] waiting for the rolling deployment ..."
  for _ in $(seq 1 60); do
    state=$(aws ecs describe-services --cluster "$CLUSTER" --services "$name" \
      --query 'services[0].deployments[?status==`PRIMARY`]|[0].rolloutState' --output text)
    case "$state" in
      COMPLETED)
        live=$(aws ecs describe-services --cluster "$CLUSTER" --services "$name" --query 'services[0].taskDefinition' --output text)
        if [ "$live" = "$(cat ".local/new-$svc.arn")" ]; then echo "[$svc] COMPLETED"; else echo "[$svc] ROLLED BACK by the circuit breaker (live task definition is $live)"; exit 1; fi
        break ;;
      FAILED) echo "[$svc] FAILED -> circuit breaker rolled back"; aws ecs describe-services --cluster "$CLUSTER" --services "$name" --query 'services[0].events[:5].message' --output text; exit 1 ;;
    esac
    sleep 15
  done
done
