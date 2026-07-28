module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = var.name_prefix
  azs                  = var.azs
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # NAT gateway is not Free Tier eligible; leave disabled until the
  # workload actually needs outbound internet from a private subnet.
  enable_nat_gateway = false
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "employee-management-api",
    "employee-management-ui",
  ]
}

module "iam" {
  source = "../../modules/iam"

  name_prefix         = var.name_prefix
  github_org          = var.github_org
  github_repos        = var.github_repos
  ecr_repository_arns = values(module.ecr.repository_arns)
}
