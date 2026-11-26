#!/usr/bin/env bash
# Runs a one-off command in the Rails image on Fargate (migrations, seeds). Prints the task's logs; non-zero if the command failed.
#   scripts/ecs-run-task.sh web "bin/rails db:prepare db:seed"
set -euo pipefail
cd "$(dirname "$0")/.."
export AWS_PAGER="" AWS_PROFILE="${AWS_PROFILE:-ai-agent-desk-deployer}" AWS_REGION=ap-southeast-2
family="ai-agent-desk-${1:?family}"; cmd="${2:?command}"
CLUSTER=ai-agent-desk
td=$(aws ecs describe-services --cluster $CLUSTER --services "$family" --query 'services[0].taskDefinition' --output text)
subnets=$(terraform -chdir=infra output -json public_subnets | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).join(","))')
sg=$(terraform -chdir=infra output -raw app_security_group)
overrides=$(node -e 'console.log(JSON.stringify({containerOverrides:[{name:"rails",command:["bash","-lc",process.argv[1]]}]}))' "$cmd")
task=$(aws ecs run-task --cluster $CLUSTER --launch-type FARGATE --task-definition "$td" \
  --network-configuration "awsvpcConfiguration={subnets=[$subnets],securityGroups=[$sg],assignPublicIp=ENABLED}" \
  --overrides "$overrides" --query 'tasks[0].taskArn' --output text)
echo "task ${task##*/} started"
aws ecs wait tasks-stopped --cluster $CLUSTER --tasks "$task"
code=$(aws ecs describe-tasks --cluster $CLUSTER --tasks "$task" --query "tasks[0].containers[?name=='rails'].exitCode|[0]" --output text)
aws logs get-log-events --log-group-name /ecs/ai-agent-desk-web --log-stream-name "web/rails/${task##*/}" --query 'events[].message' --output text 2>/dev/null | tail -40 || true
echo "exit code: $code"
[ "$code" = "0" ]
