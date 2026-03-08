# Data sources to check existence

data "external" "s3_bucket_check" {
  program = ["bash", "-c", "if aws s3api head-bucket --bucket ${var.postgres_backup_bucket_name} --endpoint-url ${var.localstack_endpoint} 2>/dev/null; then echo '{\"exists\": \"true\"}'; else echo '{\"exists\": \"false\"}'; fi"]
}

# ECR checks commented out
# data "external" "ecr_listmonk_check" {
#   program = ["bash", "-c", "if aws ecr describe-repositories --repository-names ${var.listmonk_ecr_repo_name} --endpoint-url ${var.localstack_endpoint} 2>/dev/null; then echo '{\"exists\": \"true\"}'; else echo '{\"exists\": \"false\"}'; fi"]
# }

# data "external" "ecr_postgres_check" {
#   program = ["bash", "-c", "if aws ecr describe-repositories --repository-names ${var.postgres_ecr_repo_name} --endpoint-url ${var.localstack_endpoint} 2>/dev/null; then echo '{\"exists\": \"true\"}'; else echo '{\"exists\": \"false\"}'; fi"]
# }

data "external" "secret_postgres_check" {
  program = ["bash", "-c", "if aws secretsmanager describe-secret --secret-id ${var.postgres_secret_name} --endpoint-url ${var.localstack_endpoint} 2>/dev/null; then echo '{\"exists\": \"true\"}'; else echo '{\"exists\": \"false\"}'; fi"]
}

data "external" "secret_listmonk_check" {
  program = ["bash", "-c", "if aws secretsmanager describe-secret --secret-id ${var.listmonk_secret_name} --endpoint-url ${var.localstack_endpoint} 2>/dev/null; then echo '{\"exists\": \"true\"}'; else echo '{\"exists\": \"false\"}'; fi"]
}

# S3 Bucket for PostgreSQL backups
resource "aws_s3_bucket" "postgres_backups" {
  count = data.external.s3_bucket_check.result.exists == "false" ? 1 : 0
  bucket = var.postgres_backup_bucket_name

  tags = {
    Name        = "PostgreSQL Backups"
    Environment = var.environment
    Purpose     = "Database Backups"
  }
}

# S3 Bucket versioning for backups
resource "aws_s3_bucket_versioning" "postgres_backups_versioning" {
  count = data.external.s3_bucket_check.result.exists == "false" ? 1 : 0
  bucket = aws_s3_bucket.postgres_backups[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket public access block for security
resource "aws_s3_bucket_public_access_block" "postgres_backups_pab" {
  count = data.external.s3_bucket_check.result.exists == "false" ? 1 : 0
  bucket = aws_s3_bucket.postgres_backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECR Repository for Listmonk application
# Commented out because ECR is not supported in free LocalStack
# resource "aws_ecr_repository" "listmonk_app" {
#   count = data.external.ecr_listmonk_check.result.exists == "false" ? 1 : 0
#   name                 = var.listmonk_ecr_repo_name
#   image_tag_mutability = "MUTABLE"

#   image_scanning_configuration {
#     scan_on_push = false
#   }

#   tags = {
#     Name        = "Listmonk Application"
#     Environment = var.environment
#   }
# }

# ECR Repository for PostgreSQL
# Commented out because ECR is not supported in free LocalStack
# resource "aws_ecr_repository" "postgres" {
#   count = data.external.ecr_postgres_check.result.exists == "false" ? 1 : 0
#   name                 = var.postgres_ecr_repo_name
#   image_tag_mutability = "MUTABLE"

#   image_scanning_configuration {
#     scan_on_push = false
#   }

#   tags = {
#     Name        = "PostgreSQL Database"
#     Environment = var.environment
#   }
# }

# AWS Secrets Manager for PostgreSQL credentials
resource "aws_secretsmanager_secret" "postgres_credentials" {
  count = data.external.secret_postgres_check.result.exists == "false" ? 1 : 0
  name                    = var.postgres_secret_name
  description             = "PostgreSQL database credentials for Listmonk"
  recovery_window_in_days = 0

  tags = {
    Name        = "PostgreSQL Credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "postgres_credentials_version" {
  count = data.external.secret_postgres_check.result.exists == "false" ? 1 : 0
  secret_id = aws_secretsmanager_secret.postgres_credentials[0].id

  secret_string = jsonencode({
    username = var.postgres_username
    password = var.postgres_password
    database = var.postgres_database
    host     = var.postgres_host
    port     = var.postgres_port
  })
}

# AWS Secrets Manager for Listmonk application secrets
resource "aws_secretsmanager_secret" "listmonk_app_secrets" {
  count = data.external.secret_listmonk_check.result.exists == "false" ? 1 : 0
  name                    = var.listmonk_secret_name
  description             = "Listmonk application configuration secrets"
  recovery_window_in_days = 0

  tags = {
    Name        = "Listmonk App Secrets"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "listmonk_app_secrets_version" {
  count = data.external.secret_listmonk_check.result.exists == "false" ? 1 : 0
  secret_id = aws_secretsmanager_secret.listmonk_app_secrets[0].id

  secret_string = jsonencode({
    admin_username = var.listmonk_admin_username
    admin_password = var.listmonk_admin_password
    smtp_host      = var.smtp_host
    smtp_port      = var.smtp_port
    smtp_username  = var.smtp_username
    smtp_password  = var.smtp_password
    from_email     = var.from_email
  })
}