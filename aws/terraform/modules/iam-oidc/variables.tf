variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "oidc_issuer_url" {
  description = "EKS 클러스터 OIDC 발급자 URL"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
} 