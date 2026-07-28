variable "name_prefix" {
  description = "Prefix applied to all resource names/tags"
  type        = string
}

variable "github_org" {
  description = "GitHub org/user that owns the repos allowed to assume the CI role via OIDC"
  type        = string
}

variable "github_repos" {
  description = "List of \"org/repo\" allowed to assume the CI deploy role (e.g. [\"dhavalsinhpatil/employee-management-api\"])"
  type        = list(string)
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the CI role is allowed to push images to"
  type        = list(string)
  default     = []
}

variable "secrets_manager_arns" {
  description = "Secrets Manager secret ARNs the application runtime role may read"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
