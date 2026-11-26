variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "aws_profile" {
  type    = string
  default = "ai-agent-desk-deployer"
}

variable "project" {
  type    = string
  default = "ai-agent-desk"
}

variable "image_tag" {
  description = "Tag of the rails / help-center / company-backend images in ECR"
  type        = string
  default     = "latest"
}

variable "web_desired_count" {
  type    = number
  default = 2
}

variable "bedrock_model_id" {
  type    = string
  default = "au.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "bedrock_embed_model_id" {
  type    = string
  default = "amazon.titan-embed-text-v2:0"
}
