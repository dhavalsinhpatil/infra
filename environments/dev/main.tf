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

module "eks" {
  source = "../../modules/eks"

  name_prefix = var.name_prefix
  vpc_id      = module.vpc.vpc_id

  # Public subnets: NAT Gateway is disabled for cost, so nodes need a
  # direct internet route (image pulls, EKS API) that only the public
  # subnets provide without it.
  subnet_ids = module.vpc.public_subnet_ids

  node_instance_types = ["t3.small"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3
}
