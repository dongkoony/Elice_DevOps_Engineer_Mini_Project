# 지역 변수 정의
locals {
  project_name = var.project_name
  region       = var.region
  
  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CreatedBy   = "elice-devops-team"
  }
}

# VPC 모듈 호출
module "vpc" {
  source = "./modules/vpc"

  project_name = local.project_name
  common_tags  = local.common_tags
}

# 보안 그룹 모듈 호출
module "security_groups" {
  source = "./modules/security-groups"

  project_name = local.project_name
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr_block
  common_tags  = local.common_tags
}

# IAM 기본 모듈 호출 (EKS 클러스터와 노드 역할)
module "iam_base" {
  source = "./modules/iam-base"

  project_name = local.project_name
  common_tags  = local.common_tags
}

# EKS 모듈 호출
module "eks" {
  source = "./modules/eks"

  project_name               = local.project_name
  cluster_role_arn          = module.iam_base.eks_cluster_role_arn
  node_role_arn             = module.iam_base.eks_nodes_role_arn
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_security_group_id = module.security_groups.eks_cluster_security_group_id
  node_security_group_id    = module.security_groups.eks_nodes_security_group_id
  common_tags               = local.common_tags

  depends_on = [module.vpc, module.security_groups, module.iam_base]
}

# IAM OIDC 모듈 호출 (EKS 클러스터 생성 후)
module "iam_oidc" {
  source = "./modules/iam-oidc"

  project_name    = local.project_name
  oidc_issuer_url = module.eks.oidc_issuer_url
  common_tags     = local.common_tags

  depends_on = [module.eks]
}

# RDS 모듈 호출
module "rds" {
  source = "./modules/rds"

  project_name                = local.project_name
  rds_security_group_id       = module.security_groups.rds_security_group_id
  database_subnet_group_name  = module.vpc.database_subnet_group_name
  common_tags                 = local.common_tags

  depends_on = [module.vpc, module.security_groups]
}

# S3 모듈 호출
module "s3" {
  source = "./modules/s3"

  project_name = local.project_name
  common_tags  = local.common_tags
}

# EBS CSI 드라이버 애드온 (OIDC 모듈 생성 후)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_id
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.24.0-eksbuild.1"
  service_account_role_arn = module.iam_oidc.ebs_csi_driver_role_arn

  depends_on = [
    module.eks,
    module.iam_oidc
  ]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-ebs-csi-driver"
    Type = "EBS CSI 드라이버"
  })
}

# 마이크로서비스용 ECR 리포지토리 생성
resource "aws_ecr_repository" "microservices" {
  for_each = toset(var.microservices)

  name                 = "${local.project_name}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${each.value}"
    Type = "마이크로서비스 컨테이너 저장소"
  })
} 