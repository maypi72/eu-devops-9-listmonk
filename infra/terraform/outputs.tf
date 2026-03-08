# S3 Bucket outputs
output "postgres_backup_bucket_name" {
  description = "Name of the S3 bucket for PostgreSQL backups"
  value       = try(aws_s3_bucket.postgres_backups[0].bucket, null)
}

output "postgres_backup_bucket_id" {
  description = "ID of the S3 bucket for PostgreSQL backups"
  value       = try(aws_s3_bucket.postgres_backups[0].id, null)
}

output "postgres_backup_bucket_arn" {
  description = "ARN of the S3 bucket for PostgreSQL backups"
  value       = try(aws_s3_bucket.postgres_backups[0].arn, null)
}

# ECR Repository outputs
# Commented out because ECR is not supported in free LocalStack
# output "listmonk_ecr_repository_url" {
#   description = "URL of the ECR repository for Listmonk application"
#   value       = try(aws_ecr_repository.listmonk_app[0].repository_url, null)
# }

# output "postgres_ecr_repository_url" {
#   description = "URL of the ECR repository for PostgreSQL"
#   value       = try(aws_ecr_repository.postgres[0].repository_url, null)
# }

# output "listmonk_ecr_repository_arn" {
#   description = "ARN of the ECR repository for Listmonk application"
#   value       = try(aws_ecr_repository.listmonk_app[0].arn, null)
# }

# output "postgres_ecr_repository_arn" {
#   description = "ARN of the ECR repository for PostgreSQL"
#   value       = try(aws_ecr_repository.postgres[0].arn, null)
# }

# Secrets Manager outputs
output "postgres_secret_arn" {
  description = "ARN of the Secrets Manager secret for PostgreSQL credentials"
  value       = try(aws_secretsmanager_secret.postgres_credentials[0].arn, null)
}

output "listmonk_secret_arn" {
  description = "ARN of the Secrets Manager secret for Listmonk app secrets"
  value       = try(aws_secretsmanager_secret.listmonk_app_secrets[0].arn, null)
}

output "postgres_secret_name" {
  description = "Name of the Secrets Manager secret for PostgreSQL credentials"
  value       = try(aws_secretsmanager_secret.postgres_credentials[0].name, null)
}

output "listmonk_secret_name" {
  description = "Name of the Secrets Manager secret for Listmonk app secrets"
  value       = try(aws_secretsmanager_secret.listmonk_app_secrets[0].name, null)
}

# LocalStack endpoint
output "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  value       = var.localstack_endpoint
}