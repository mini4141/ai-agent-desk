resource "aws_ecr_repository" "app" {
  for_each             = toset(["rails", "help-center", "company-backend"])
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

locals {
  registry = "${local.account}.dkr.ecr.${var.region}.amazonaws.com"
  images = {
    rails           = "${local.registry}/${local.name}/rails:${var.image_tag}"
    help_center     = "${local.registry}/${local.name}/help-center:${var.image_tag}"
    company_backend = "${local.registry}/${local.name}/company-backend:${var.image_tag}"
  }
}
