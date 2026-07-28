variable "aws_region" {
  description = "AWS region for dev resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to resource names/tags in this environment"
  type        = string
  default     = "empmgmt-dev"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "github_org" {
  description = "GitHub org/user that owns the application repos"
  type        = string
  default     = "dhavalsinhpatil"
}

variable "github_repos" {
  description = "List of \"org/repo\" allowed to assume the CI deploy role"
  type        = list(string)
  default = [
    "dhavalsinhpatil/employee-management-api",
    "dhavalsinhpatil/employee-management-ui",
    "dhavalsinhpatil/infra",
  ]
}
