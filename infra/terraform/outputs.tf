# S3 Bucket outputs
output "postgres_backup_bucket_name" {
  description = "Name of the S3 bucket for PostgreSQL backups"
  value       = aws_s3_bucket.postgres_backups.bucket
}

output "postgres_backup_bucket_id" {
  description = "ID of the S3 bucket for PostgreSQL backups"
  value       = aws_s3_bucket.postgres_backups.id
}

output "postgres_backup_bucket_arn" {
  description = "ARN of the S3 bucket for PostgreSQL backups"
  value       = aws_s3_bucket.postgres_backups.arn
}

# ECR Repository outputs
output "listmonk_ecr_repository_url" {
  description = "URL of the ECR repository for Listmonk application"
  value       = aws_ecr_repository.listmonk_app.repository_url
}

output "postgres_ecr_repository_url" {
  description = "URL of the ECR repository for PostgreSQL"
  value       = aws_ecr_repository.postgres.repository_url
}

output "listmonk_ecr_repository_arn" {
  description = "ARN of the ECR repository for Listmonk application"
  value       = aws_ecr_repository.listmonk_app.arn
}

output "postgres_ecr_repository_arn" {
  description = "ARN of the ECR repository for PostgreSQL"
  value       = aws_ecr_repository.postgres.arn
}

# Secrets Manager outputs
output "postgres_secret_arn" {
  description = "ARN of the Secrets Manager secret for PostgreSQL credentials"
  value       = aws_secretsmanager_secret.postgres_credentials.arn
}

output "listmonk_secret_arn" {
  description = "ARN of the Secrets Manager secret for Listmonk app secrets"
  value       = aws_secretsmanager_secret.listmonk_app_secrets.arn
}

output "postgres_secret_name" {
  description = "Name of the Secrets Manager secret for PostgreSQL credentials"
  value       = aws_secretsmanager_secret.postgres_credentials.name
}

output "listmonk_secret_name" {
  description = "Name of the Secrets Manager secret for Listmonk app secrets"
  value       = aws_secretsmanager_secret.listmonk_app_secrets.name
}

# LocalStack endpoint
output "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  value       = var.localstack_endpoint
}