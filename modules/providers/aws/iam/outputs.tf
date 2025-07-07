
output "ecr_iam_role_name" {
  description = "IAM role name of ECR"
  value       = aws_iam_role.ecr_iam_role.name
}
