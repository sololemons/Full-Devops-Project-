terraform {
  required_version = ">= 1.5"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets = var.public_subnets
  
  enable_nat_gateway = false 
  map_public_ip_on_launch = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# --- EKS Cluster ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name = var.cluster_name
  cluster_version = var.kubernetes_version
   
  subnet_ids = module.vpc.public_subnets
  vpc_id = module.vpc.vpc_id
  
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    staging_nodes = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
    }
  }
}

resource "aws_s3_bucket" "receipts" {
  bucket        = "${var.project_name}-receipts-${var.environment}-${var.user_id}"
  force_destroy = true 
}

module "payments_s3_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-payments-role"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }

  role_policy_arns = {
    s3 = aws_iam_policy.s3_access.arn
  }
}

resource "aws_iam_policy" "s3_access" {
  name = "${var.project_name}-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.receipts.arn}/*"
    }]
  })
}
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", var.region, "--cluster-name", module.eks.cluster_name]
  }
}

resource "kubernetes_namespace" "app" {
  depends_on = [module.eks]
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account" "payments_sa" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.payments_s3_role.iam_role_arn
    }
  }
}