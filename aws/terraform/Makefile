# 기본 설정
TERRAFORM = terraform
AWS_REGION = ap-northeast-2

# 색상 출력
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help init plan-dev apply-dev plan-stg apply-stg plan-prod apply-prod destroy-dev destroy-stg destroy-prod

# 도움말
help:
	@echo "$(GREEN) Terraform 환경별 배포 명령어$(NC)"
	@echo ""
	@echo "$(YELLOW) 초기 설정:$(NC)"
	@echo "  make init          - Terraform 초기화"
	@echo ""
	@echo "$(YELLOW) 개발환경:$(NC)"
	@echo "  make plan-dev      - 개발환경 실행 계획 확인"
	@echo "  make apply-dev     - 개발환경 배포"
	@echo "  make destroy-dev   - 개발환경 삭제"
	@echo ""
	@echo "$(YELLOW) 스테이징환경:$(NC)"
	@echo "  make plan-stg      - 스테이징환경 실행 계획 확인"
	@echo "  make apply-stg     - 스테이징환경 배포"
	@echo "  make destroy-stg   - 스테이징환경 삭제"
	@echo ""
	@echo "$(YELLOW) 프로덕션환경:$(NC)"
	@echo "  make plan-prod     - 프로덕션환경 실행 계획 확인"
	@echo "  make apply-prod    - 프로덕션환경 배포"
	@echo "  make destroy-prod  - 프로덕션환경 삭제"

# Terraform 초기화
init:
	@echo "$(GREEN) Terraform 초기화 중...$(NC)"
	$(TERRAFORM) init

# 개발환경
plan-dev:
	@echo "$(GREEN) 개발환경 계획 확인 중...$(NC)"
	$(TERRAFORM) plan -var-file="terraform.tfvars.dev"

apply-dev:
	@echo "$(GREEN) 개발환경 배포 중...$(NC)"
	$(TERRAFORM) apply -var-file="terraform.tfvars.dev"

destroy-dev:
	@echo "$(RED)  개발환경 삭제 중...$(NC)"
	$(TERRAFORM) destroy -var-file="terraform.tfvars.dev"

# 스테이징환경
plan-stg:
	@echo "$(GREEN) 스테이징환경 계획 확인 중...$(NC)"
	$(TERRAFORM) plan -var-file="terraform.tfvars.stg"

apply-stg:
	@echo "$(GREEN) 스테이징환경 배포 중...$(NC)"
	$(TERRAFORM) apply -var-file="terraform.tfvars.stg"

destroy-stg:
	@echo "$(RED)  스테이징환경 삭제 중...$(NC)"
	$(TERRAFORM) destroy -var-file="terraform.tfvars.stg"

# 프로덕션환경
plan-prod:
	@echo "$(GREEN) 프로덕션환경 계획 확인 중...$(NC)"
	$(TERRAFORM) plan -var-file="terraform.tfvars.prod"

apply-prod:
	@echo "$(YELLOW)  프로덕션환경 배포 - 신중하게 진행!$(NC)"
	@read -p "정말 프로덕션 환경에 배포하시겠습니까? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(TERRAFORM) apply -var-file="terraform.tfvars.prod"; \
	else \
		echo "$(RED) 프로덕션 배포가 취소되었습니다.$(NC)"; \
	fi

destroy-prod:
	@echo "$(RED)  프로덕션환경 삭제 - 매우 위험!$(NC)"
	@read -p "정말 프로덕션 환경을 삭제하시겠습니까? (DELETE_PROD): " confirm; \
	if [ "$$confirm" = "DELETE_PROD" ]; then \
		$(TERRAFORM) destroy -var-file="terraform.tfvars.prod"; \
	else \
		echo "$(RED) 프로덕션 삭제가 취소되었습니다.$(NC)"; \
	fi 