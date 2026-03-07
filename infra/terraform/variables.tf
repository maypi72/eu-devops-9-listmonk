variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS access key ID for LocalStack"
  type        = string
  default     = "test"
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for LocalStack"
  type        = string
  default     = "test"
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:31566"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

# S3 Bucket variables
variable "postgres_backup_bucket_name" {
  description = "Name of the S3 bucket for PostgreSQL backups"
  type        = string
  default     = "listmonk-postgres-backups"
}

# ECR Repository variables
variable "listmonk_ecr_repo_name" {
  description = "Name of the ECR repository for Listmonk application"
  type        = string
  default     = "listmonk/app"
}

variable "postgres_ecr_repo_name" {
  description = "Name of the ECR repository for PostgreSQL"
  type        = string
  default     = "listmonk/postgres"
}

# PostgreSQL variables
variable "postgres_secret_name" {
  description = "Name of the Secrets Manager secret for PostgreSQL credentials"
  type        = string
  default     = "listmonk/postgres-credentials"
}

variable "postgres_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "listmonk"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "listmonk_password"
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "listmonk"
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "postgres"
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

# Listmonk application variables
variable "listmonk_secret_name" {
  description = "Name of the Secrets Manager secret for Listmonk app secrets"
  type        = string
  default     = "listmonk/app-secrets"
}

variable "listmonk_admin_username" {
  description = "Listmonk admin username"
  type        = string
  default     = "admin"
}

variable "listmonk_admin_password" {
  description = "Listmonk admin password"
  type        = string
  default     = "admin_password"
  sensitive   = true
}

# SMTP variables
variable "smtp_host" {
  description = "SMTP server host"
  type        = string
  default     = "smtp.gmail.com"
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = string
  default     = "587"
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "from_email" {
  description = "From email address for Listmonk"
  type        = string
  default     = "noreply@listmonk.local"
}