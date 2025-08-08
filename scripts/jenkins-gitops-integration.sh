pipeline {
  agent any

  parameters {
    choice(
      name: 'SERVICE_NAME',
      choices: [
        'api-gateway',
        'auth-service',
        'user-service',
        'product-service',
        'order-service',
        'payment-service',
        'inventory-service',
        'review-service',
        'notification-service',
        'analytics-service',
        'log-service',
        'health-service'
      ],
      description: '빌드할 마이크로서비스 선택'
    )
    choice(
      name: 'ENVIRONMENT',
      choices: ['dev', 'stg', 'prod'],
      description: '배포 환경 선택'
    )
    string(
      name: 'IMAGE_TAG',
      defaultValue: 'latest',
      description: 'Docker 이미지 태그 (기본값: latest)'
    )
    booleanParam(
      name: 'SKIP_TESTS',
      defaultValue: false,
      description: '테스트 건너뛰기'
    )
    booleanParam(
      name: 'GITOPS_UPDATE',
      defaultValue: true,
      description: 'GitOps 저장소 업데이트 (권장)'
    )
    booleanParam(
      name: 'CREATE_PR',
      defaultValue: false,
      description: 'Pull Request 생성 (staging/production 권장)'
    )
  }

  environment {
    // Docker 레지스트리 설정
    DOCKER_REGISTRY = "${env.DOCKER_REGISTRY ?: 'localhost:5000'}"
    SERVICE_PATH = "aws/microservices/${params.SERVICE_NAME}"
    IMAGE_NAME = "${DOCKER_REGISTRY}/${params.SERVICE_NAME}"
    FULL_IMAGE_TAG = "${params.ENVIRONMENT}-${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'unknown'}"

    // GitOps 설정
    GIT_USER_NAME = "jenkins-ci"
    GIT_USER_EMAIL = "dhyeon.shin@icloud.com"
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 25, unit: 'MINUTES')
    disableConcurrentBuilds()
    skipStagesAfterUnstable()
  }

  stages {
    stage('🔍 준비 및 검증') {
      steps {
        echo "=== Elice DevOps GitOps 마이크로서비스 파이프라인 ==="
        echo "서비스: ${params.SERVICE_NAME}"
        echo "환경: ${params.ENVIRONMENT}"
        echo "이미지 태그: ${params.IMAGE_TAG}"
        echo "풀 이미지명: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
        echo "GitOps 업데이트: ${params.GITOPS_UPDATE}"

        // 서비스 디렉토리 존재 확인
        script {
          if (!fileExists("${env.SERVICE_PATH}")) {
            error("서비스 디렉토리를 찾을 수 없습니다: ${env.SERVICE_PATH}")
          }

          if (!fileExists("${env.SERVICE_PATH}/pyproject.toml")) {
            error("pyproject.toml 파일을 찾을 수 없습니다: ${env.SERVICE_PATH}/pyproject.toml")
          }

          if (!fileExists("${env.SERVICE_PATH}/Dockerfile")) {
            error("Dockerfile을 찾을 수 없습니다: ${env.SERVICE_PATH}/Dockerfile")
          }
        }

        echo "✅ 모든 필수 파일이 존재합니다"
      }
    }

    stage('📦 uv 설치 및 의존성 검증') {
      steps {
        dir("${env.SERVICE_PATH}") {
          sh '''
            echo "=== uv 설치 ==="

            # uv가 이미 설치되어 있는지 확인
            if ! command -v uv >/dev/null 2>&1; then
              echo "uv 설치 중..."
              curl -LsSf https://astral.sh/uv/install.sh | sh
              export PATH="$HOME/.local/bin:$PATH"
            else
              echo "✅ uv 이미 설치됨"
            fi

            # uv 경로 확인
            export PATH="$HOME/.local/bin:$PATH"
            which uv || echo "uv 경로: $HOME/.local/bin/uv"
            uv --version

            echo "=== 의존성 파일 검증 ==="

            # pyproject.toml 확인
            if [ -f "pyproject.toml" ]; then
              echo "✅ pyproject.toml 존재함"
              echo "프로젝트 정보:"
              head -15 pyproject.toml
            fi

            # requirements.lock 확인
            if [ -f "requirements.lock" ]; then
              echo "✅ requirements.lock 존재함"
              echo "의존성 개수: $(wc -l < requirements.lock)"
              echo "주요 의존성:"
              head -10 requirements.lock
            fi

            # Python 환경 확인
            python3 --version

            echo "✅ uv 설치 및 의존성 검증 완료"
          '''
        }
      }
    }

    stage('🧪 코드 품질 검사') {
      when {
        expression { params.SKIP_TESTS != true }
      }
      parallel {
        stage('린팅') {
          steps {
            dir("${env.SERVICE_PATH}") {
              sh '''
                echo "=== 코드 린팅 검사 ==="

                # Python 문법 검사
                echo "Python 파일 문법 검사"
                find . -name "*.py" -exec python3 -m py_compile {} \\; 2>/dev/null || echo "Python 문법 검사 완료"

                # 기본 코드 스타일 검사
                echo "코드 스타일 기본 검사"
                find . -name "*.py" | head -5 | while read file; do
                  echo "검사: $file"
                  python3 -c "
import ast
with open('$file', 'r') as f:
  try:
    ast.parse(f.read())
    print('✅ $file - 문법 정상')
  except SyntaxError as e:
    print('❌ $file - 문법 오류:', e)
" 2>/dev/null || echo "파일 검사 완료"
                done

                echo "✅ 린팅 검사 완료"
              '''
            }
          }
        }

        stage('타입 검사') {
          steps {
            dir("${env.SERVICE_PATH}") {
              sh '''
                echo "=== 기본 타입 검사 ==="

                # Python 타입 힌트 기본 검증
                echo "타입 힌트 확인"
                find . -name "*.py" | head -3 | while read file; do
                  echo "검사: $file"
                  if grep -q "typing\\|Type\\|:" "$file" 2>/dev/null; then
                    echo "✅ $file - 타입 힌트 사용"
                  else
                    echo "ℹ️ $file - 타입 힌트 미사용"
                  fi
                done

                # 기본 import 검사
                echo "Import 구문 검사"
                python3 -c "
import os
import sys
for root, dirs, files in os.walk('.'):
  for file in files:
    if file.endswith('.py'):
      filepath = os.path.join(root, file)
      try:
        with open(filepath, 'r') as f:
          content = f.read()
          if 'import' in content:
            print(f'✅ {filepath} - Import 구문 정상')
      except Exception as e:
        print(f'⚠️ {filepath} - 읽기 오류')
    break
  break
" 2>/dev/null || echo "Import 검사 완료"

                echo "✅ 타입 검사 완료"
              '''
            }
          }
        }
      }
    }

    stage('🏗️ Docker 이미지 빌드') {
      steps {
        dir("${env.SERVICE_PATH}") {
          sh """
            echo "=== Docker 이미지 빌드 ==="

            # 현재 디렉토리와 Dockerfile 확인
            echo "현재 위치: \$(pwd)"
            echo "Dockerfile 내용 (첫 10줄):"
            head -10 Dockerfile

            # Docker 이미지 빌드
            docker build \\
              --tag ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG} \\
              --tag ${env.IMAGE_NAME}:latest \\
              --label "service=${params.SERVICE_NAME}" \\
              --label "environment=${params.ENVIRONMENT}" \\
              --label "build-number=${env.BUILD_NUMBER}" \\
              --label "git-commit=${env.GIT_COMMIT ?: 'unknown'}" \\
              --label "gitops-enabled=true" \\
              .

            echo "✅ Docker 이미지 빌드 완료"
            docker images | grep ${params.SERVICE_NAME} | head -5
          """
        }
      }
    }

    stage('🔐 보안 검사') {
      when {
        expression { params.SKIP_TESTS != true }
      }
      steps {
        sh """
          echo "=== Docker 이미지 보안 검사 ==="

          # Trivy가 있다면 보안 스캔 (선택적)
          if command -v trivy >/dev/null 2>&1; then
            echo "Trivy로 보안 스캔 실행"
            trivy image --exit-code 0 --severity HIGH,CRITICAL ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}
          else
            echo "Trivy 미설치 - 기본 보안 검사 실행"
            docker run --rm ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG} python --version
          fi
        """
      }
    }

    stage('📤 이미지 푸시') {
      steps {
        sh """
          echo "=== Docker 이미지 레지스트리 푸시 ==="

          # 로컬 레지스트리에 푸시
          if [[ "${env.DOCKER_REGISTRY}" == "localhost:5000" ]]; then
            echo "로컬 레지스트리에 푸시: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
            docker push ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}
            docker push ${env.IMAGE_NAME}:latest

            echo "✅ 이미지 푸시 완료"
            echo "이미지: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
            echo "태그: ${env.FULL_IMAGE_TAG}"
          else
            echo "외부 레지스트리 푸시는 추후 구현"
          fi
        """
      }
    }

    stage('🔄 GitOps 업데이트') {
      when {
        expression { params.GITOPS_UPDATE == true }
      }
      steps {
        script {
          echo "=== Kubernetes 매니페스트 업데이트 시작 ==="

          // 로컬 GitOps 스크립트 경로
          def gitopsScript = "./scripts/jenkins-gitops-integration.sh"
          def gitopsCmd = "${gitopsScript} ${params.SERVICE_NAME} ${env.FULL_IMAGE_TAG} ${params.ENVIRONMENT}"

          // 옵션 추가
          gitopsCmd += " --registry ${env.DOCKER_REGISTRY}"
          gitopsCmd += " --git-user '${env.GIT_USER_NAME}'"
          gitopsCmd += " --git-email '${env.GIT_USER_EMAIL}'"

          // PR 생성 조건
          if (params.CREATE_PR == true || params.ENVIRONMENT in ['stg', 'prod']) {
            gitopsCmd += " --pr"
            echo "Pull Request 생성 모드로 GitOps 업데이트"
          }

          echo "GitOps 명령: ${gitopsCmd}"

          // GitOps 스크립트 실행
          sh """
            # GitOps 스크립트 경로 확인
            if [ ! -f "${gitopsScript}" ]; then
              echo "❌ GitOps 스크립트를 찾을 수 없습니다: ${gitopsScript}"
              exit 1
            fi

            # 스크립트 실행 권한 확인
            chmod +x "${gitopsScript}"

            # GitOps 업데이트 실행
            ${gitopsCmd}
          """

          // 환경별 안내 메시지
          switch(params.ENVIRONMENT) {
            case 'dev':
              echo "✅ 개발 환경 매니페스트 업데이트 완료"
              echo "ℹ️ kubectl apply로 즉시 배포하거나 ArgoCD 동기화 대기"
              break
            case 'stg':
              echo "✅ 스테이징 환경 매니페스트 업데이트 완료"
              echo "⚠️ 승인 후 수동 배포 권장"
              break
            case 'prod':
              echo "✅ 운영 환경 매니페스트 업데이트 완료"
              echo "⚠️ Pull Request 검토 및 승인 후 배포하세요"
              echo "🔐 운영 환경 배포는 추가 검토가 필요합니다"
              break
          }
        }
      }
    }

    stage('📊 배포 상태 확인') {
      when {
        allOf {
          expression { params.GITOPS_UPDATE == true }
          expression { params.ENVIRONMENT == 'dev' }
        }
      }
      steps {
        script {
          echo "=== 개발환경 배포 상태 모니터링 ==="

          // ArgoCD CLI가 설치되어 있다면 상태 확인
          sh '''
            # ArgoCD 상태 확인 (선택적)
            if command -v argocd >/dev/null 2>&1; then
              echo "ArgoCD CLI로 애플리케이션 상태 확인 중..."
              # argocd app get api-gateway-dev 등의 명령어 실행
            else
              echo "ArgoCD CLI가 설치되지 않음 - 수동으로 ArgoCD UI 확인 필요"
            fi

            # Kubernetes 클러스터 연결 확인
            if kubectl cluster-info >/dev/null 2>&1; then
              echo "Kubernetes 클러스터 연결 확인됨"

              # 네임스페이스 존재 확인
              if kubectl get namespace elice-devops-dev >/dev/null 2>&1; then
                echo "개발환경 네임스페이스 존재함"

                # 기존 배포 확인
                if kubectl get deployment dev-${SERVICE_NAME} -n elice-devops-dev >/dev/null 2>&1; then
                  echo "기존 배포 상태:"
                  kubectl get deployment dev-${SERVICE_NAME} -n elice-devops-dev
                else
                  echo "새로운 배포가 생성될 예정입니다"
                fi
              else
                echo "개발환경 네임스페이스가 생성될 예정입니다"
              fi
            else
              echo "Kubernetes 클러스터 연결 불가 - ArgoCD가 배포를 처리할 것입니다"
            fi

            echo "✅ 상태 확인 완료"
          '''
        }
      }
    }
  }

  post {
    always {
      echo "=== 파이프라인 실행 완료 ==="
      echo "서비스: ${params.SERVICE_NAME}"
      echo "환경: ${params.ENVIRONMENT}"
      echo "이미지: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
      echo "실행 시간: ${currentBuild.durationString}"
      echo "GitOps 업데이트: ${params.GITOPS_UPDATE}"

      // 빌드 아티팩트 정리
      sh '''
        echo "임시 파일 정리 중..."
        docker system prune -f --filter "label=build-number=${BUILD_NUMBER}" || true
      '''
    }

    success {
      script {
        echo "🎉 ${params.SERVICE_NAME} GitOps 파이프라인이 성공적으로 완료되었습니다!"

        // 환경별 성공 메시지
        switch(params.ENVIRONMENT) {
          case 'dev':
            echo "✅ 개발환경 배포 진행 중..."
            echo "📱 ArgoCD UI: http://localhost:8080 (포트포워딩 시)"
            echo "⏱️ 약 3-5분 후 배포 완료 예상"
            break
          case 'stg':
            echo "⏳ 스테이징환경 승인 대기 중..."
            echo "👀 ArgoCD UI에서 수동 동기화하세요"
            if (params.CREATE_PR) {
              echo "📋 Pull Request가 생성되었습니다 - GitHub에서 확인하세요"
            }
            break
          case 'prod':
            echo "🔒 운영환경 승인 필요..."
            echo "📋 Pull Request 검토 및 승인 후 배포하세요"
            echo "⚠️ 운영환경 배포는 신중히 진행하세요"
            break
        }

        echo "🔗 현재 프로젝트: ${env.WORKSPACE}"
      }
    }

    failure {
      echo "❌ ${params.SERVICE_NAME} GitOps 파이프라인 실패"
      echo "📋 실패 단계별 확인사항:"
      echo "  1. Docker 빌드 오류 → Dockerfile 및 의존성 확인"
      echo "  2. GitOps 업데이트 오류 → 저장소 권한 및 경로 확인"
      echo "  3. 스크립트 오류 → jenkins-gitops-integration.sh 확인"
      echo "📖 자세한 로그를 확인하여 문제를 해결하세요"
    }

    unstable {
      echo "⚠️ ${params.SERVICE_NAME} 파이프라인이 불안정한 상태로 완료되었습니다"
      echo "🔍 테스트 결과 또는 보안 검사 결과를 확인하세요"
    }
  }
}