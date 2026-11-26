#!/usr/bin/env bash
# Deploys the whole stack to AWS (profile ai-agent-desk-deployer, ap-southeast-2). Everything comes from infra/ (Terraform).
#   scripts/deploy.sh           full deploy: OIDC role, ECR, images, infrastructure, console, migrate + seed, smoke test
#   scripts/deploy.sh app       only build + push images and roll ECS (no Terraform)
source "$(dirname "$0")/_common.sh"
export AWS_PROFILE=ai-agent-desk-deployer AWS_REGION=ap-southeast-2 AWS_DEFAULT_REGION=ap-southeast-2 AWS_PAGER=""
MODE="${1:-full}"
TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"
TF="terraform -chdir=infra"
mkdir -p .local proof/phase2-cloud/logs

aws sts get-caller-identity --query Arn --output text >/dev/null || { echo "AWS identity check failed"; exit 1; }
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com"

oidc() {
  # Account-wide OIDC provider: reuse if present, create (and record it) otherwise.
  if aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text | grep -q token.actions.githubusercontent.com; then
    create=false
  else
    create=true; touch infra/.oidc-created
  fi
  if terraform -chdir=infra/github-oidc init -input=false >/dev/null && terraform -chdir=infra/github-oidc apply -auto-approve -input=false -var "create_provider=$create" >/dev/null; then
    role=$(terraform -chdir=infra/github-oidc output -raw role_arn)
    gh variable set AWS_DEPLOY_ROLE_ARN --body "$role" >/dev/null && echo "GitHub OIDC role ready: variable AWS_DEPLOY_ROLE_ARN set"
  else
    echo "OIDC setup blocked (SCP?). Falling back to scripts/deploy.sh from this PC; see docs/DECISIONS.md"
  fi
}

build_and_push() {
  echo "== build images :$TAG"
  pnpm --dir web build:widget
  aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
  docker build -q -t "$REGISTRY/ai-agent-desk/rails:$TAG" .
  docker build -q -t "$REGISTRY/ai-agent-desk/help-center:$TAG" web/help-center
  docker build -q -t "$REGISTRY/ai-agent-desk/company-backend:$TAG" -f mocks/company-backend/Dockerfile mocks
  for repo in rails help-center company-backend; do docker push -q "$REGISTRY/ai-agent-desk/$repo:$TAG"; done
}

if [ "$MODE" = "app" ]; then
  build_and_push
  scripts/ecs-deploy-image.sh "$TAG"
  exit 0
fi

$TF init -input=false >/dev/null
oidc
echo "== ECR repositories"
$TF apply -auto-approve -input=false -target=aws_ecr_repository.app >/dev/null
build_and_push

echo "== infrastructure (Terraform)"
$TF apply -auto-approve -input=false -var "image_tag=$TAG" | tee proof/phase2-cloud/logs/terraform-apply.log | tail -5

ALB=$($TF output -raw alb_dns); CF=$($TF output -raw cloudfront_domain); BUCKET=$($TF output -raw console_bucket); CFID=$($TF output -raw cloudfront_id)

echo "== console + phone simulator -> S3 / CloudFront"
VITE_API_URL=same-origin pnpm --dir web/console build >/dev/null
(cd web/phone-sim && VITE_API_URL=same-origin pnpm exec vite build --base /phone/ --outDir dist >/dev/null)
aws s3 sync web/console/dist "s3://$BUCKET/" --delete --exclude "phone/*" --only-show-errors
aws s3 sync web/phone-sim/dist "s3://$BUCKET/phone/" --delete --only-show-errors
aws cloudfront create-invalidation --distribution-id "$CFID" --paths "/*" >/dev/null

echo "== wait for ECS services"
aws ecs wait services-stable --cluster ai-agent-desk --services $($TF output -json services | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).join(" "))')

echo "== migrate + seed (one-off ECS task)"
scripts/ecs-run-task.sh web "bin/rails db:prepare db:seed" | tee proof/phase2-cloud/logs/migrate-seed.log | tail -5

cat > .local/cloud.env <<EOF
export API_URL=http://$ALB
export HELP_URL=http://$ALB
export CONSOLE_URL=https://$CF
export PHONE_URL=https://$CF/phone/index.html
export SEED_PASSWORD=$($TF output -raw seed_password)
export LOAD_TEST_TOKEN=$($TF output -raw load_test_token)
EOF

echo "== smoke test"
curl -fs "http://$ALB/up" >/dev/null && echo "ALB /up ok"
curl -fs -o /dev/null "https://$CF/" && echo "CloudFront console ok"
node scripts/smoke-chat.mjs "http://$ALB" pk_demo_mirai "注文 A-1023 はいつ届きますか？" | tee proof/phase2-cloud/logs/smoke-chat-bedrock.log
echo "deployed: tag $TAG  ALB http://$ALB  console https://$CF"
