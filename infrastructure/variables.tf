variable "student_id" {
  description = "AltSchool student ID for unique resource naming"
  type        = string
  default     = "1072"
}

variable "region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

# New VPC variables
variable "vpc_name" {
  description = "Name tag for the VPC as per project requirements"
  type        = string
  default     = "project-bedrock-vpc"
}

variable "cluster_name" {
  description = "Name of the EKS cluster as per project requirements"
  type        = string
  default     = "project-bedrock-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones for subnet distribution"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}


# EKS IAM variables
variable "cluster_service_account_namespace" {
  description = "Kubernetes namespace for cluster resources"
  type        = string
  default     = "kube-system"
}

variable "cluster_service_account_name" {
  description = "Kubernetes service account name for EKS"
  type        = string
  default     = "cluster-autoscaler"
}