# Configure Terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configure local backend for development (switch to S3 after LocalStack is running)
  # To use S3 backend, uncomment the lines below after running: terraform init -migrate-state
  /*
  backend "s3" {
    bucket                      = "terraform-state-bucket"
    key                         = "terraform.tfstate"
    region                      = "us-east-1"
    endpoints {
      s3 = "http://localhost:31566"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
    access_key                  = "test"
    secret_key                  = "test"
  }
  */
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region                      = var.aws_region
  access_key                  = var.aws_access_key_id
  secret_key                  = var.aws_secret_access_key
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = var.localstack_endpoint
    ecr      = var.localstack_endpoint
    secretsmanager = var.localstack_endpoint
  }
}