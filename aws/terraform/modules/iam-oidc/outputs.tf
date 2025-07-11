# EBS CSI 드라이버 IAM 역할 ARN
output "ebs_csi_driver_role_arn" {
  description = "EBS CSI 드라이버 IAM 역할 ARN"
  value       = aws_iam_role.ebs_csi_driver.arn
}

# AWS Load Balancer Controller IAM 역할 ARN
output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM 역할 ARN"
  value       = aws_iam_role.aws_load_balancer_controller.arn
} 