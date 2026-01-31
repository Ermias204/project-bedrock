output "state_bucket_name" {
  description = "The name of the S3 bucket created for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_lock_table" {
  description = "The name of the DynamoDB table used for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}


# EKS Cluster outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = aws_eks_cluster.main.name
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}


output "assets_bucket_name" {
  description = "Name of the S3 bucket for assets"
  value       = "bedrock-assets-${var.student_id}"
}


output "dev_view_access_key_id" {
  description = "Access Key ID for bedrock-dev-view user"
  value       = aws_iam_access_key.dev_view.id
  sensitive   = true
}

output "dev_view_secret_access_key" {
  description = "Secret Access Key for bedrock-dev-view user"
  value       = aws_iam_access_key.dev_view.secret
  sensitive   = true
}