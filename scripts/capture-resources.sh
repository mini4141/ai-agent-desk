#!/usr/bin/env bash
# Writes proof/phase2-cloud/resources.txt: what is deployed, straight from Terraform outputs and describe calls (redacted).
source "$(dirname "$0")/_common.sh"
export AWS_PROFILE=ai-agent-desk-deployer AWS_REGION=ap-southeast-2 AWS_PAGER="" PYTHONIOENCODING=utf-8
OUT=proof/phase2-cloud/resources.txt
{
echo "# Deployed AWS resources (project ai-agent-desk, region ap-southeast-2) — $(date -u +%FT%TZ)"
echo; echo "## ECS services (Fargate)"
aws ecs describe-services --cluster ai-agent-desk --services ai-agent-desk-web ai-agent-desk-worker ai-agent-desk-help-center ai-agent-desk-company-backend \
  --query 'services[].[serviceName,launchType,desiredCount,runningCount,deployments[0].rolloutState,deploymentConfiguration.deploymentCircuitBreaker.enable,deploymentConfiguration.deploymentCircuitBreaker.rollback]' --output table
echo; echo "## Web tasks per availability zone"
for t in $(aws ecs list-tasks --cluster ai-agent-desk --service-name ai-agent-desk-web --query 'taskArns[]' --output text); do
  aws ecs describe-tasks --cluster ai-agent-desk --tasks "$t" --query 'tasks[0].[availabilityZone,lastStatus,cpu,memory]' --output text
done
echo; echo "## Task sizes"
for f in web worker help-center company-backend; do aws ecs describe-task-definition --task-definition ai-agent-desk-$f --query 'taskDefinition.[family,cpu,memory]' --output text; done
echo; echo "## RDS PostgreSQL"
aws rds describe-db-instances --db-instance-identifier ai-agent-desk --query 'DBInstances[0].[DBInstanceClass,Engine,EngineVersion,MultiAZ,PubliclyAccessible,StorageEncrypted,DBInstanceStatus]' --output text
echo; echo "## ElastiCache Redis"
aws elasticache describe-cache-clusters --cache-cluster-id ai-agent-desk --query 'CacheClusters[0].[CacheNodeType,Engine,EngineVersion,CacheClusterStatus]' --output text
echo; echo "## Load balancer"
aws elbv2 describe-load-balancers --names ai-agent-desk --query 'LoadBalancers[0].[Type,Scheme,AvailabilityZones[].ZoneName|join(`,`,@),State.Code]' --output text
aws elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupName,'ai-agent-desk')].[TargetGroupName,Port,HealthCheckPath]" --output text
echo; echo "## CloudFront"
aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment,'ai-agent-desk')].[Id,Status,PriceClass,Comment]" --output text
echo; echo "## S3 / ECR / Secrets Manager / IAM roles"
aws s3api list-buckets --query "Buckets[?starts_with(Name,'ai-agent-desk')].Name" --output text
aws ecr describe-repositories --query "repositories[?starts_with(repositoryName,'ai-agent-desk')].repositoryName" --output text
aws secretsmanager list-secrets --query "SecretList[?starts_with(Name,'ai-agent-desk')].Name" --output text
aws iam list-roles --query "Roles[?starts_with(RoleName,'ai-agent-desk')].RoleName" --output text
echo; echo "## CloudWatch alarms and log groups (1-day retention)"
aws cloudwatch describe-alarms --alarm-name-prefix ai-agent-desk --query 'MetricAlarms[].[AlarmName,StateValue]' --output text
aws logs describe-log-groups --log-group-name-prefix /ecs/ai-agent-desk --query 'logGroups[].[logGroupName,retentionInDays]' --output text
echo; echo "## VPC (no NAT gateway)"
aws ec2 describe-vpcs --filters Name=tag:Project,Values=ai-agent-desk --query 'Vpcs[].CidrBlock' --output text
echo "NAT gateways: $(aws ec2 describe-nat-gateways --filter Name=state,Values=available --query "length(NatGateways[?Tags[?Key=='Project'&&Value=='ai-agent-desk']])" --output text)"
echo; echo "## Terraform outputs"
terraform -chdir=infra output 2>/dev/null | grep -vE "seed_password|load_test_token"
} 2>&1 | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g; s/(AKIA|ASIA)[A-Z0-9]{16}/<ACCESS_KEY>/g' | tee "$OUT" | head -70
