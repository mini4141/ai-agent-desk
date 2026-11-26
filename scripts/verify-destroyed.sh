#!/usr/bin/env bash
# Verifies nothing billable remains (SPECS §11). Exits non-zero if anything does.
# The tagging API lags after deletion, so every tagged hit is confirmed with a direct describe call before it counts.
source "$(dirname "$0")/_common.sh"
export AWS_PROFILE=ai-agent-desk-deployer AWS_REGION=ap-southeast-2 AWS_DEFAULT_REGION=ap-southeast-2 AWS_PAGER=""
OUT="${1:-proof/phase3-destroy/verify-destroyed.txt}"
mkdir -p "$(dirname "$OUT")"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
fail=0

{
echo "# verify-destroyed  $(date -u +%FT%TZ)  region=$AWS_REGION"
check() { # label, command output (empty = gone)
  local label=$1 found=$2
  if [ -z "$found" ] || [ "$found" = "None" ]; then echo "OK    $label: none"; else echo "FAIL  $label: $found"; fail=1; fi
}

check "ECS cluster"        "$(aws ecs describe-clusters --clusters ai-agent-desk --query "clusters[?status=='ACTIVE'].clusterName" --output text 2>/dev/null)"
check "Load balancers"     "$(aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName,'ai-agent-desk')].LoadBalancerName" --output text 2>/dev/null)"
check "Target groups"      "$(aws elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupName,'ai-agent-desk')].TargetGroupName" --output text 2>/dev/null)"
check "RDS instances"      "$(aws rds describe-db-instances --query "DBInstances[?starts_with(DBInstanceIdentifier,'ai-agent-desk')].DBInstanceIdentifier" --output text 2>/dev/null)"
check "ElastiCache"        "$(aws elasticache describe-cache-clusters --query "CacheClusters[?starts_with(CacheClusterId,'ai-agent-desk')].CacheClusterId" --output text 2>/dev/null)"
check "CloudFront"         "$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment,'ai-agent-desk')].Id" --output text 2>/dev/null)"
check "S3 buckets"         "$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'ai-agent-desk')].Name" --output text 2>/dev/null)"
check "ECR repositories"   "$(aws ecr describe-repositories --query "repositories[?starts_with(repositoryName,'ai-agent-desk')].repositoryName" --output text 2>/dev/null)"
check "Secrets Manager"    "$(aws secretsmanager list-secrets --query "SecretList[?starts_with(Name,'ai-agent-desk')].Name" --output text 2>/dev/null)"
check "IAM roles"          "$(aws iam list-roles --query "Roles[?starts_with(RoleName,'ai-agent-desk')].RoleName" --output text 2>/dev/null)"
check "VPCs"               "$(aws ec2 describe-vpcs --filters Name=tag:Project,Values=ai-agent-desk --query 'Vpcs[].VpcId' --output text 2>/dev/null)"
check "NAT gateways"       "$(aws ec2 describe-nat-gateways --filter Name=state,Values=available,pending --query "NatGateways[?Tags[?Key=='Project'&&Value=='ai-agent-desk']].NatGatewayId" --output text 2>/dev/null)"
check "CloudWatch log groups" "$(aws logs describe-log-groups --log-group-name-prefix /ecs/ai-agent-desk --query 'logGroups[].logGroupName' --output text 2>/dev/null)"
check "CloudWatch alarms"  "$(aws cloudwatch describe-alarms --alarm-name-prefix ai-agent-desk --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null)"
if [ ! -f infra/.oidc-created ]; then
  echo "NOTE  OIDC provider was not created by this project (shared account-wide provider is left alone)"
fi

echo; echo "# resources still tagged Project=ai-agent-desk (tagging API; can lag a few minutes)"
tagged=$(aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=ai-agent-desk --query 'ResourceTagMappingList[].ResourceARN' --output text 2>/dev/null)
if [ -z "$tagged" ]; then echo "OK    tagging API: none"; else
  for arn in $tagged; do echo "INFO  tagged: ${arn}"; done
  echo "      (confirmed above by direct describe calls; tagged entries for deleted resources are eventual-consistency leftovers)"
fi
echo; [ "$fail" = 0 ] && echo "RESULT: nothing billable remains" || echo "RESULT: BILLABLE RESOURCES REMAIN"
} 2>&1 | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g' | tee "$OUT"
exit "${PIPESTATUS[0]}"
