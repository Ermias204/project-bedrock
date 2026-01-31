
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# 1. S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "bedrock-tfstate-${var.student_id}"

  # Prevent accidental deletion of the state bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "Bedrock Terraform State"
    Project = "Bedrock"
  }
}

# Enable versioning on the S3 bucket
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the state bucket at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "state_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "bedrock-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "Bedrock Terraform State Lock"
    Project = "Bedrock"
  }
}



# Main VPC for Project Bedrock
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = var.vpc_name
    Project = "Bedrock"
  }
}

# Internet Gateway for public subnet internet access
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.vpc_name}-igw"
    Project = "Bedrock"
  }
}

# Public Subnets (one per AZ)
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.vpc_name}-public-${count.index + 1}"
    Project = "Bedrock"
  }
}

# Private Subnets (one per AZ)
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name    = "${var.vpc_name}-private-${count.index + 1}"
    Project = "Bedrock"
  }
}

# Public Route Table with Internet Gateway route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.vpc_name}-public-rt"
    Project = "Bedrock"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}



# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.vpc_name}-nat-eip"
    Project = "Bedrock"
  }
}

# NAT Gateway placed in the first public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "${var.vpc_name}-nat"
    Project = "Bedrock"
  }


  depends_on = [aws_internet_gateway.main]
}

# Private Route Table with route through NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.vpc_name}-private-rt"
    Project = "Bedrock"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


# IAM role for EKS cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.cluster_name}-cluster-role"
    Project = "Bedrock"
  }
}

# Attach necessary policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Optional: VPC CNI policy for networking
resource "aws_iam_role_policy_attachment" "eks_vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}


# IAM role for EKS worker nodes
resource "aws_iam_role" "eks_node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.cluster_name}-node-group-role"
    Project = "Bedrock"
  }
}

# Attach essential policies for worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}




# EKS CLUSTER

# EKS Cluster control plane
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.34" # As per requirement: >= v1.34.0

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Enable control plane logging for CloudWatch
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_cni_policy
  ]

  tags = {
    Name    = var.cluster_name
    Project = "Bedrock"
  }
}


# EKS Managed Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "bedrock-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id # Deploy nodes in private subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  # Required for managed node groups
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy
  ]

  tags = {
    Name    = "bedrock-node-group"
    Project = "Bedrock"
  }
}


# ======================
# DEVELOPER IAM USER
# ======================

# IAM user for developer access (bedrock-dev-view)
resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"

  tags = {
    Name    = "bedrock-dev-view"
    Project = "Bedrock"
  }
}

# Attach AWS managed ReadOnlyAccess policy
resource "aws_iam_user_policy_attachment" "dev_view_readonly" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Create access keys for the user (for grading submission)
resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}


resource "null_resource" "update_aws_auth" {
  depends_on = [aws_eks_cluster.main, aws_eks_node_group.main]

  provisioner "local-exec" {
    command = <<EOT
      # Add IAM user to aws-auth ConfigMap
      kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml
      
      # Check if user already exists in mapUsers
      if ! grep -q "bedrock-dev-view" aws-auth.yaml; then
        # Add the user mapping
        cat >> aws-auth.yaml <<EOF
      - userarn: ${aws_iam_user.dev_view.arn}
        username: ${aws_iam_user.dev_view.name}
        groups:
        - view
EOF
        # Apply the updated ConfigMap
        kubectl apply -f aws-auth.yaml
      fi
      
      # Clean up
      rm -f aws-auth.yaml
    EOT
  }

  triggers = {
    user_arn = aws_iam_user.dev_view.arn
  }
}



# S3 BUCKET FOR ASSETS


# S3 bucket for marketing assets (product images)
resource "aws_s3_bucket" "assets" {
  bucket = "bedrock-assets-1072" # Using your student ID

  tags = {
    Name    = "bedrock-assets-1072"
    Project = "Bedrock"
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on the assets bucket
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the assets bucket at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# ======================
# LAMBDA FUNCTION
# ======================

# IAM role for Lambda function
resource "aws_iam_role" "lambda_asset_processor" {
  name = "bedrock-asset-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "bedrock-asset-processor-role"
    Project = "Bedrock"
  }
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_asset_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy to allow Lambda to read from S3
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_asset_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.assets.arn,
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}




# Lambda function
resource "aws_lambda_function" "asset_processor" {
  function_name = "bedrock-asset-processor"
  role          = aws_iam_role.lambda_asset_processor.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  # Use the zip file we created
  filename         = "../lambda-asset-processor.zip"
  source_code_hash = filebase64sha256("../lambda-asset-processor.zip")

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = {
    Name    = "bedrock-asset-processor"
    Project = "Bedrock"
  }
}

# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}



# S3 BUCKET NOTIFICATION FOR LAMBDA


resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "images/"
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "images/"
    filter_suffix       = ".png"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}


output "lambda_function_arn" {
  value = aws_lambda_function.asset_processor.arn
}






# Create Kubernetes RoleBinding for view access in retail-app namespace
resource "kubernetes_role_binding_v1" "dev_view" {
  metadata {
    name      = "bedrock-dev-view-binding"
    namespace = "retail-app"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "User"
    name      = aws_iam_user.dev_view.name
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [null_resource.update_aws_auth]
}




# CLOUDWATCH OBSERVABILITY

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "amazon-cloudwatch-observability"

  # Let EKS choose compatible version
  # addon_version = ""

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name    = "cloudwatch-observability"
    Project = "Bedrock"
  }
}