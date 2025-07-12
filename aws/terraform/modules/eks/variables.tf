variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "cluster_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  type        = string
}

variable "node_role_arn" {
  description = "워커 노드 IAM 역할 ARN"
  type        = string
}

variable "cluster_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.31"
}

variable "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "프라이빗 서브넷 ID"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "클러스터 보안그룹 ID"
  type        = string
}

variable "node_security_group_id" {
  description = "워커 노드 보안그룹 ID"
  type        = string
}

# EBS CSI 드라이버 역할은 별도 모듈에서 관리
# 순환 종속성 해결을 위해 제거

variable "node_desired_size" {
  description = "워커 노드 기본 개수"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "워커 노드 최대 개수"
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "워커 노드 최소 개수"
  type        = number
  default     = 1
}

variable "node_instance_types" {
  description = "워커 노드 인스턴스 타입"
  type        = list(string)
  default     = ["t3.small"]  # 비용 최적화: medium → small
}

variable "node_capacity_type" {
  description = "노드 용량 타입"
  type        = string
  default     = "SPOT"  # 비용 최적화: Spot 인스턴스 사용
}

variable "node_disk_size" {
  description = "워커 노드 디스크 크기(GB)"
  type        = number
  default     = 20
}

variable "node_ssh_key" {
  description = "SSH 키페어 이름"
  type        = string
  default     = null
}

variable "ebs_csi_driver_version" {
  description = "EBS CSI 드라이버 버전"
  type        = string
  default     = "v1.45.0-eksbuild.2"
}

variable "vpc_cni_version" {
  description = "VPC CNI 버전"
  type        = string
  default     = "v1.19.6-eksbuild.7"
}

variable "coredns_version" {
  description = "CoreDNS 버전"
  type        = string
  default     = "v1.11.4-eksbuild.14"
}

variable "kube_proxy_version" {
  description = "kube-proxy 버전"
  type        = string
  default     = "v1.31.10-eksbuild.2"
}

# 비용 최적화 옵션 추가
variable "enable_spot_instances" {
  description = "Spot 인스턴스 사용 여부"
  type        = bool
  default     = true
}

variable "spot_max_price" {
  description = "Spot 인스턴스 최대 가격(시간당 USD)"
  type        = string
  default     = "0.05"  # t3.small On-Demand의 약 50%
}

variable "mixed_instances_policy" {
  description = "혼합 인스턴스 정책 사용 여부"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "elice-devops"
    Environment = "production"
    ManagedBy   = "terraform"
    CostCenter  = "DevOps-Team"  # 비용 추적용
  }
} 