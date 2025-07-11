# EKS 클러스터 IAM 역할 ARN
output "eks_cluster_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  value       = aws_iam_role.eks_cluster.arn
}

# EKS 워커 노드 IAM 역할 ARN
output "eks_nodes_role_arn" {
  description = "EKS 워커 노드 IAM 역할 ARN"
  value       = aws_iam_role.eks_nodes.arn
} 