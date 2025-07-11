variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "elice-devops"
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "production"
}

variable "microservices" {
  description = "마이크로서비스 목록"
  type        = list(string)
  default = [
    "api-gateway",
    "user-service",
    "auth-service",
    "product-service",
    "inventory-service",
    "order-service",
    "payment-service",
    "notification-service",
    "review-service",
    "analytics-service",
    "log-service",
    "health-service"
  ]
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "database_subnet_cidrs" {
  description = "데이터베이스 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.30.0/24", "10.0.40.0/24"]
}

variable "eks_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.28"
}

variable "eks_node_instance_types" {
  description = "워커 노드 인스턴스 타입"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "eks_node_desired_size" {
  description = "워커 노드 기본 개수"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "워커 노드 최대 개수"
  type        = number
  default     = 10
}

variable "eks_node_min_size" {
  description = "워커 노드 최소 개수"
  type        = number
  default     = 1
}

variable "rds_engine_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "15.13"
}

variable "rds_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS 기본 스토리지 크기(GB)"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "RDS 최대 스토리지 크기(GB)"
  type        = number
  default     = 100
} 