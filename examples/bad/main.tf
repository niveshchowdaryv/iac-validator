terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # The demo pipeline runs `terraform plan -refresh=false` with dummy placeholder
  # credentials (see .github/workflows/iac-validate.yml), so no real AWS access is
  # needed to validate policies. For real deployments, remove these skips and
  # authenticate via SSO or OIDC instead of static credentials.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# --------------------------------------------------------------------------
# S3 bucket
# --------------------------------------------------------------------------
resource "aws_s3_bucket" "app_data" {
  # Bucket names are globally unique; change the suffix if you ever apply this.
  bucket = "iac-validator-demo-${var.environment}"

  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

# INTENTIONAL: public-read ACL — caught by policies/s3.rego (deny public S3 ACLs).
# Separate resource because AWS provider v5 removed the inline `acl` argument.
resource "aws_s3_bucket_acl" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  acl    = "public-read"
}

# INTENTIONAL: no aws_s3_bucket_server_side_encryption_configuration resource —
# caught by policies/s3.rego (deny S3 without SSE)

# --------------------------------------------------------------------------
# Security group
# --------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "iac-validator-demo-${var.environment}"
  description = "Demo security group for iac-validator"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # INTENTIONAL: 0.0.0.0/0 on port 22 — caught by policies/ec2.rego
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

# --------------------------------------------------------------------------
# EC2 instance
# --------------------------------------------------------------------------
resource "aws_instance" "app" {
  # Placeholder AMI (Amazon Linux 2, us-east-1). This config is only ever
  # planned in CI with -refresh=false; it is never applied to a real account.
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app.id]

  # INTENTIONAL: no tags block — caught by policies/tags.rego
  # (requires Environment and Owner tags on every tagged resource type)
}
