# Project Bedrock - InnovateMart EKS Deployment

## Project Overview
Production-grade microservices deployment on AWS EKS for InnovateMart's retail store application.

## Architecture
- VPC with public/private subnets across 2 AZs
- EKS cluster (v1.34) with managed node groups
- Retail Store Sample App deployed in `retail-app` namespace
- CloudWatch logging for control plane and containers
- S3 bucket with Lambda function for image processing
- IAM user with read-only access for developers

## Prerequisites
- AWS Account with appropriate permissions
- Terraform v1.0+
- AWS CLI configured
- kubectl and helm installed

## Deployment

### 1. Clone Repository

git clone https://github.com/Ermias204/project-bedrock

cd project-bedrock
2. Initialize Terraform

cd infrastructure
terraform init

3. Apply Infrastructure

terraform apply

4. Configure kubectl

aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster

5. Verify Deployment

kubectl get pods -n retail-app
kubectl get svc -n retail-app
CI/CD Pipeline
GitHub Actions workflow automates:

terraform plan on Pull Requests

terraform apply on merges to main

Grading Credentials
IAM User: bedrock-dev-view

Access Key: (see Terraform outputs)

Secret Key: (see Terraform outputs)

Cleanup
bash
cd infrastructure
terraform destroy -auto-approve
