variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "elice-devops"
    Environment = "production"
    ManagedBy   = "terraform"
  }
} 