# Configure Terraform
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }

  # Configure local backend for development (switch to S3 after LocalStack is running)
  # By default we use local state; having an explicit local backend avoids
  # backend detection issues when the config is modified.
  backend "local" {
    path = "terraform.tfstate"
  }

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
}
  

# Configure the AWS Provider
provider "aws" {
  region                      = var.aws_region
  access_key                  = var.aws_access_key_id
  secret_key                  = var.aws_secret_access_key
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  # Para facilitar el uso con LocalStack 
  s3_use_path_style           = true
  skip_region_validation      = true
  sts_region                  = var.aws_region


  endpoints {
    s3             = var.localstack_endpoint
    ecr            = var.localstack_endpoint
    secretsmanager = var.localstack_endpoint
  }

  
}