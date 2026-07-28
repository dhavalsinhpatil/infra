output "github_actions_ci_role_arn" {
  value = aws_iam_role.github_actions_ci.arn
}

output "app_runtime_role_arn" {
  value = aws_iam_role.app_runtime.arn
}

output "app_runtime_instance_profile_name" {
  value = aws_iam_instance_profile.app_runtime.name
}
