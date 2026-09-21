variable "region" {
  description = "AWS region for the demo infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name; applied as the Environment tag."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Resource owner; applied as the Owner tag."
  type        = string
  default     = "nivesh"
}
