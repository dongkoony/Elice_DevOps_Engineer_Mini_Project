#!/bin/bash

# Jenkins Pipeline Fix Script
# Jenkins 파이프라인 Git 체크아웃 문제 해결을 위한 스크립트

set -e

echo "🔧 Jenkins 파이프라인 Git 체크아웃 문제 해결 스크립트"
echo "=================================================="

# 1. 현재 Git 상태 확인
echo "📋 현재 Git 상태 확인..."
git status --porcelain

# 2. Jenkins 파이프라인 파일 수정사항 확인
echo ""
echo "🔍 Jenkins 파이프라인 수정사항:"
if [ -f "jenkins/microservice-gitops-pipeline.groovy" ]; then
    echo "✅ jenkins/microservice-gitops-pipeline.groovy 존재함"
    grep -n "소스코드 체크아웃" jenkins/microservice-gitops-pipeline.groovy || echo "⚠️ Git 체크아웃 스테이지 확인 필요"
else
    echo "❌ jenkins/microservice-gitops-pipeline.groovy 파일이 없습니다"
    exit 1
fi

# 3. GitOps 통합 스크립트 확인
echo ""
echo "📦 GitOps 통합 스크립트 확인..."
if [ -f "scripts/jenkins-gitops-integration.sh" ]; then
    echo "✅ scripts/jenkins-gitops-integration.sh 존재함"
    chmod +x scripts/jenkins-gitops-integration.sh
    echo "✅ 실행 권한 설정 완료"
else
    echo "❌ scripts/jenkins-gitops-integration.sh 파일이 없습니다"
    exit 1
fi

# 4. API Gateway 서비스 디렉토리 확인
echo ""
echo "🏗️ API Gateway 서비스 확인..."
if [ -d "aws/microservices/api-gateway" ]; then
    echo "✅ aws/microservices/api-gateway 디렉토리 존재함"
    
    # 필수 파일 확인
    if [ -f "aws/microservices/api-gateway/Dockerfile" ]; then
        echo "✅ Dockerfile 존재함"
    else
        echo "❌ Dockerfile 없음"
    fi
    
    if [ -f "aws/microservices/api-gateway/pyproject.toml" ]; then
        echo "✅ pyproject.toml 존재함"
    else
        echo "❌ pyproject.toml 없음"
    fi
    
    if [ -f "aws/microservices/api-gateway/api_gateway/main.py" ]; then
        echo "✅ main.py 존재함"
    else
        echo "❌ main.py 없음"
    fi
else
    echo "❌ aws/microservices/api-gateway 디렉토리가 없습니다"
    exit 1
fi

# 5. Git 커밋 및 푸시 준비
echo ""
echo "📤 Git 커밋 및 푸시 준비..."
echo "현재 브랜치: $(git branch --show-current)"

# 변경된 파일들 추가
git add jenkins/microservice-gitops-pipeline.groovy
git add scripts/jenkins-gitops-integration.sh

echo "✅ Jenkins 관련 파일들이 스테이징됨"

# 6. 커밋 메시지 생성
COMMIT_MSG="fix: Jenkins GitOps 파이프라인 Groovy 문법 오류 수정 및 Git 체크아웃 스테이지 추가

- FULL_IMAGE_TAG 환경변수 동적 생성으로 변경하여 Groovy 문법 오류 해결
- Git 소스코드 체크아웃 스테이지 추가로 서비스 디렉토리 부재 문제 해결
- Jenkins GitOps 통합 스크립트 실행 권한 설정

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# 7. 커밋 실행
echo ""
echo "💾 변경사항 커밋 중..."
git commit -m "$COMMIT_MSG"

echo "✅ 커밋 완료"

# 8. 원격 저장소로 푸시
echo ""
echo "🚀 원격 저장소로 푸시 중..."
CURRENT_BRANCH=$(git branch --show-current)
git push origin $CURRENT_BRANCH

echo "✅ 푸시 완료"

# 9. Jenkins 재실행 안내
echo ""
echo "🎉 Jenkins 파이프라인 수정 완료!"
echo "=================================================="
echo ""
echo "📋 다음 단계:"
echo "1. Jenkins UI에서 파이프라인 다시 실행"
echo "2. '📥 소스코드 체크아웃' 스테이지가 정상 실행되는지 확인"
echo "3. 'aws/microservices/api-gateway' 디렉토리 인식 확인"
echo "4. Docker 이미지 빌드까지 진행되는지 모니터링"
echo ""
echo "🔗 Jenkins 접속: http://localhost:8080"
echo "📂 파이프라인: microservice-gitops-pipeline"
echo "⚙️ 매개변수: SERVICE_NAME=api-gateway, ENVIRONMENT=dev"
echo ""
echo "✅ 스크립트 실행 완료"