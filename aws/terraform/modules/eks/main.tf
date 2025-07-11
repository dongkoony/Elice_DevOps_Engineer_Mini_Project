# EKS 클러스터 생성
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [var.cluster_security_group_id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-cluster"
    Type = "EKS 클러스터"
  })
}

# EKS 노드 그룹 생성
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type
  disk_size      = var.node_disk_size

  # SSH 접근이 필요한 경우에만 사용
  # remote_access {
  #   ec2_ssh_key               = var.node_ssh_key
  #   source_security_group_ids = [var.node_security_group_id]
  # }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-node-group"
    Type = "EKS 노드 그룹"
  })

  depends_on = [
    aws_eks_cluster.main
  ]
}

# EBS CSI 드라이버 애드온 (별도 모듈에서 관리)
# 순환 종속성 해결을 위해 별도 모듈로 분리

# VPC CNI 애드온
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = var.vpc_cni_version

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc-cni"
    Type = "VPC CNI"
  })
}

# CoreDNS 애드온
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = var.coredns_version

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-coredns"
    Type = "CoreDNS"
  })
}

# kube-proxy 애드온
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_version

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-kube-proxy"
    Type = "kube-proxy"
  })
}

# EKS 클러스터 암호화용 KMS 키
resource "aws_kms_key" "eks" {
  description             = "${var.project_name} EKS 클러스터 암호화 키"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eks-kms-key"
    Type = "EKS 암호화 키"
  })
}

# KMS 키 별칭
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch 로그 그룹 (EKS 클러스터 로그용)
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.project_name}-cluster/cluster"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eks-cluster-logs"
    Type = "EKS 클러스터 로그"
  })
}

# OIDC 아이덴티티 프로바이더 생성
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eks-oidc"
    Type = "OIDC 프로바이더"
  })
}

# EKS 클러스터 인증서 정보
data "tls_certificate" "eks_cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
} 