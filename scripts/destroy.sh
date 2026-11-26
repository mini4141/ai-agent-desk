#!/usr/bin/env bash
# Tears the whole AWS stack down. Idempotent and safe to re-run.
#   1. scale ECS services to 0   2. empty S3 buckets + ECR repos   3. terraform destroy   4. delete the GitHub OIDC role
#   (and the OIDC provider only if this project created it: infra/.oidc-created)
source "$(dirname "$0")/_common.sh"
export AWS_PROFILE=ai-agent-desk-deployer AWS_REGION=ap-southeast-2 AWS_DEFAULT_REGION=ap-southeast-2 AWS_PAGER=""
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CLUSTER=ai-agent-desk

echo "== 1. scale services to 0"
for svc in web worker help-center company-backend; do
  aws ecs update-service --cluster $CLUSTER --service "ai-agent-desk-$svc" --desired-count 0 >/dev/null 2>&1 && echo "scaled $svc" || true
done
for t in $(aws ecs list-tasks --cluster $CLUSTER --query 'taskArns[]' --output text 2>/dev/null); do
  aws ecs stop-task --cluster $CLUSTER --task "$t" >/dev/null 2>&1 || true
done

echo "== 2. empty buckets and repositories"
for b in "ai-agent-desk-uploads-$ACCOUNT" "ai-agent-desk-console-$ACCOUNT"; do
  aws s3 rm "s3://$b" --recursive --only-show-errors 2>/dev/null && echo "emptied $b" || true
done
for r in rails help-center company-backend; do
  ids=$(aws ecr list-images --repository-name "ai-agent-desk/$r" --query 'imageIds[*]' --output json 2>/dev/null || echo '[]')
  [ "$ids" != "[]" ] && [ -n "$ids" ] && aws ecr batch-delete-image --repository-name "ai-agent-desk/$r" --image-ids "$ids" >/dev/null 2>&1 && echo "emptied ecr $r" || true
done

echo "== 3. terraform destroy (infra)"
if [ -f infra/terraform.tfstate ]; then
  terraform -chdir=infra init -input=false >/dev/null
  terraform -chdir=infra destroy -auto-approve -input=false
else
  echo "no infra state found (already destroyed?)"
fi

echo "== 4. GitHub OIDC role"
if [ -f infra/github-oidc/terraform.tfstate ]; then
  create=false; [ -f infra/.oidc-created ] && create=true
  terraform -chdir=infra/github-oidc destroy -auto-approve -input=false -var "create_provider=$create"
  rm -f infra/.oidc-created
fi
gh variable delete AWS_DEPLOY_ROLE_ARN >/dev/null 2>&1 || true
echo "destroy finished; run scripts/verify-destroyed.sh"
