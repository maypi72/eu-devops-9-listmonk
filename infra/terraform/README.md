# Terraform Infrastructure for Listmonk

This Terraform configuration sets up the necessary AWS resources for running Listmonk with LocalStack.

## Prerequisites

- LocalStack running (use `../scripts/install-localstack.sh`)
- Terraform installed
- kubectl configured for your K3s cluster

## GitHub Secrets Required

Configure the following secrets in your GitHub repository:

### Required Secrets
- `AWS_ACCESS_KEY_ID`: AWS access key (use `test` for LocalStack)
- `AWS_SECRET_ACCESS_KEY`: AWS secret key (use `test` for LocalStack)
- `POSTGRES_PASSWORD`: PostgreSQL database password
- `LISTMONK_ADMIN_PASSWORD`: Listmonk admin password

### Optional Secrets (for email functionality)
- `SMTP_USERNAME`: SMTP server username
- `SMTP_PASSWORD`: SMTP server password

## Resources Created

- **S3 Bucket**: For PostgreSQL database backups with versioning enabled
- **ECR Repositories**: For Listmonk application and PostgreSQL container images
- **AWS Secrets Manager**: For storing database credentials and application secrets

## Usage

### Local Development

1. **Set environment variables**:
   ```bash
   export AWS_ACCESS_KEY_ID=test
   export AWS_SECRET_ACCESS_KEY=test
   export LOCALSTACK_ENDPOINT=http://localhost:31566
   export ENVIRONMENT=development
   export POSTGRES_BACKUP_BUCKET_NAME=listmonk-postgres-backups
   export LISTMONK_ECR_REPO_NAME=listmonk/app
   export POSTGRES_ECR_REPO_NAME=listmonk/postgres
   export POSTGRES_SECRET_NAME=listmonk/postgres-credentials
   export POSTGRES_USERNAME=listmonk
   export POSTGRES_PASSWORD=your_postgres_password
   export POSTGRES_DATABASE=listmonk
   export POSTGRES_HOST=postgres
   export POSTGRES_PORT=5432
   export LISTMONK_SECRET_NAME=listmonk/app-secrets
   export LISTMONK_ADMIN_USERNAME=admin
   export LISTMONK_ADMIN_PASSWORD=your_admin_password
   export SMTP_HOST=smtp.gmail.com
   export SMTP_PORT=587
   export SMTP_USERNAME=your_smtp_username
   export SMTP_PASSWORD=your_smtp_password
   export FROM_EMAIL=noreply@listmonk.local
   ```

2. **Initialize Terraform**:
   ```bash
   cd infra/terraform
   terraform init
   ```

3. **Review the plan**:
   ```bash
   terraform plan
   ```

4. **Apply the configuration**:
   ```bash
   terraform apply
   ```

5. **Verify resources**:
   ```bash
   terraform output
   ```

## Switching to S3 Backend

After LocalStack is running, you can switch to the S3 backend for state management:

1. **Ensure LocalStack is running** (the `terraform-state-bucket` should exist)
2. **Migrate the state**:
   ```bash
   # Uncomment the S3 backend block in providers.tf
   # Comment out the local backend block
   terraform init -migrate-state
   ```

## Configuration

The configuration uses LocalStack endpoints. Update `terraform.tfvars` with your specific values:

- Database credentials
- SMTP settings
- Custom bucket/repository names

## Important Notes

- This configuration is designed for LocalStack (development/testing)
- **Backend Configuration**: The S3 backend uses fixed values for LocalStack. For production deployments, consider using a different backend (like S3 on real AWS)
- Secrets are stored in AWS Secrets Manager (LocalStack implementation)
- S3 bucket has versioning enabled for backup safety
- ECR repositories are configured for container image storage

## Cleanup

To destroy all resources:
```bash
terraform destroy
```