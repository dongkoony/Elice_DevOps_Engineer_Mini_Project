#!/bin/bash

# Elice DevOps Project - ECR Lifecycle Policy Setup Script
# ECR 리포지토리에 이미지 라이프사이클 정책을 자동으로 적용하는 스크립트

set -e

# 색상 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 설정 변수
PROJECT_NAME="elice-devops"
AWS_REGION="ap-northeast-2"
ENVIRONMENTS=("dev" "stg" "prod")

# 환경별 lifecycle 정책 정의
create_dev_policy() {
    cat <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["dev-"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Delete images older than 7 days",
      "selection": {
        "tagStatus": "any",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

create_stg_policy() {
    cat <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["stg-"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Delete images older than 14 days",
      "selection": {
        "tagStatus": "any",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 14
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

create_prod_policy() {
    cat <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 20 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["prod-"],
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Delete untagged images older than 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Delete tagged images older than 90 days",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["prod-"],
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 90
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

# 특정 리포지토리에 lifecycle 정책 적용
apply_lifecycle_policy() {
    local repo_name=$1
    local env=$2
    local policy_json=""
    
    case $env in
        "dev")
            policy_json=$(create_dev_policy)
            ;;
        "stg")
            policy_json=$(create_stg_policy)
            ;;
        "prod")
            policy_json=$(create_prod_policy)
            ;;
        *)
            log_error "Unknown environment: $env"
            return 1
            ;;
    esac
    
    log_info "Applying lifecycle policy to $repo_name"
    
    if aws ecr put-lifecycle-policy \
        --repository-name "$repo_name" \
        --lifecycle-policy-text "$policy_json" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_success "Policy applied: $repo_name"
        return 0
    else
        log_error "Failed to apply policy: $repo_name"
        return 1
    fi
}

# 모든 리포지토리에 정책 적용
apply_all_policies() {
    local failed_repos=()
    local success_count=0
    
    log_info "Starting ECR lifecycle policy application..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        log_info "Processing $env environment..."
        
        # 해당 환경의 모든 리포지토리 가져오기
        local repos=$(aws ecr describe-repositories \
            --query "repositories[?contains(repositoryName, '${PROJECT_NAME}-${env}-')].repositoryName" \
            --output text \
            --region "$AWS_REGION")
        
        if [ -z "$repos" ]; then
            log_warning "No repositories found for environment: $env"
            continue
        fi
        
        for repo in $repos; do
            if apply_lifecycle_policy "$repo" "$env"; then
                ((success_count++))
            else
                failed_repos+=("$repo")
            fi
        done
    done
    
    # 결과 요약
    echo ""
    log_info "=== Lifecycle Policy Application Summary ==="
    log_success "Successfully applied: $success_count repositories"
    
    if [ ${#failed_repos[@]} -gt 0 ]; then
        log_error "Failed repositories (${#failed_repos[@]}):"
        for repo in "${failed_repos[@]}"; do
            log_error "  - $repo"
        done
        return 1
    else
        log_success "All policies applied successfully!"
        return 0
    fi
}

# 정책 상태 확인
check_policy_status() {
    log_info "Checking lifecycle policy status..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        echo ""
        log_info "=== $env Environment ==="
        
        local repos=$(aws ecr describe-repositories \
            --query "repositories[?contains(repositoryName, '${PROJECT_NAME}-${env}-')].repositoryName" \
            --output text \
            --region "$AWS_REGION")
        
        for repo in $repos; do
            if aws ecr get-lifecycle-policy --repository-name "$repo" --region "$AWS_REGION" > /dev/null 2>&1; then
                log_success "$repo: Policy exists"
            else
                log_warning "$repo: No policy"
            fi
        done
    done
}

# 정책 삭제
remove_policies() {
    log_warning "Removing all lifecycle policies..."
    
    echo -n "Are you sure you want to remove all lifecycle policies? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        return 0
    fi
    
    local removed_count=0
    
    for env in "${ENVIRONMENTS[@]}"; do
        local repos=$(aws ecr describe-repositories \
            --query "repositories[?contains(repositoryName, '${PROJECT_NAME}-${env}-')].repositoryName" \
            --output text \
            --region "$AWS_REGION")
        
        for repo in $repos; do
            if aws ecr delete-lifecycle-policy --repository-name "$repo" --region "$AWS_REGION" > /dev/null 2>&1; then
                log_success "Policy removed: $repo"
                ((removed_count++))
            fi
        done
    done
    
    log_success "Removed policies from $removed_count repositories"
}

# 사용법 출력
usage() {
    echo "Elice DevOps Project - ECR Lifecycle Policy Setup"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  apply     - Apply lifecycle policies to all repositories"
    echo "  status    - Check current policy status"
    echo "  remove    - Remove all lifecycle policies"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 apply"
    echo "  $0 status"
    echo "  $0 remove"
}

# 메인 로직
main() {
    case ${1:-help} in
        apply)
            apply_all_policies
            ;;
        status)
            check_policy_status
            ;;
        remove)
            remove_policies
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@" 