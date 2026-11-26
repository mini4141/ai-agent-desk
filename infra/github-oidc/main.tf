# GitHub Actions -> AWS without stored keys. The role trusts only this repository.
# The account-wide OIDC provider may already exist (other projects share the account): set create_provider=false then.
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.80" }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "aws_profile" {
  type    = string
  default = "ai-agent-desk-deployer"
}

variable "github_repo" {
  type    = string
  default = "mini4141/ai-agent-desk"
}

variable "create_provider" {
  description = "Create the token.actions.githubusercontent.com provider (false if it already exists)"
  type        = bool
  default     = true
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
  default_tags {
    tags = {
      Project   = "ai-agent-desk"
      Ephemeral = "true"
      ManagedBy = "terraform"
      Owner     = "alvieirvansyah"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  provider_arn = var.create_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "ai-agent-desk-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Deployment needs ECR push, ECS task-definition/service updates and iam:PassRole for the two ECS roles.
resource "aws_iam_role_policy" "deploy" {
  name = "deploy"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:DescribeImages"], Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/ai-agent-desk/*" },
      { Effect = "Allow", Action = ["ecs:Describe*", "ecs:List*", "ecs:RegisterTaskDefinition", "ecs:UpdateService", "ecs:RunTask", "ecs:StopTask", "ecs:TagResource"], Resource = "*" },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ai-agent-desk-ecs-*"] },
      { Effect = "Allow", Action = ["elasticloadbalancing:Describe*", "logs:GetLogEvents", "logs:DescribeLogStreams", "cloudfront:CreateInvalidation", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"], Resource = "*" }
    ]
  })
}

output "role_arn" {
  value = aws_iam_role.deploy.arn
}

output "provider_created" {
  value = var.create_provider
}
