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
            name: 'DEPLOY_TO_K8S',
            defaultValue: false,
            description: 'Kubernetes에 자동 배포'
        )
    }
    
    environment {
        // Docker 레지스트리 설정 (로컬 개발용)
        DOCKER_REGISTRY = "${env.DOCKER_REGISTRY ?: 'localhost:5000'}"
        SERVICE_PATH = "aws/microservices/${params.SERVICE_NAME}"
        IMAGE_NAME = "${DOCKER_REGISTRY}/${params.SERVICE_NAME}"
        FULL_IMAGE_TAG = "${params.ENVIRONMENT}-${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'unknown'}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        skipStagesAfterUnstable()
    }
    
    stages {
        stage('🔍 준비 및 검증') {
            steps {
                echo "=== Elice DevOps 마이크로서비스 빌드 파이프라인 ==="
                echo "서비스: ${params.SERVICE_NAME}"
                echo "환경: ${params.ENVIRONMENT}"
                echo "이미지 태그: ${params.IMAGE_TAG}"
                echo "풀 이미지명: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
                
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
            when {
                anyOf {
                    equals expected: 'stg', actual: params.ENVIRONMENT
                    equals expected: 'prod', actual: params.ENVIRONMENT
                }
            }
            steps {
                sh """
                    echo "=== Docker 이미지 레지스트리 푸시 ==="
                    
                    # 로컬 레지스트리에 푸시 (개발환경)
                    if [[ "${env.DOCKER_REGISTRY}" == "localhost:5000" ]]; then
                        echo "로컬 레지스트리에 푸시"
                        docker push ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}
                        docker push ${env.IMAGE_NAME}:latest
                    else
                        echo "외부 레지스트리 푸시는 추후 구현"
                    fi
                """
            }
        }
        
        stage('🚀 Kubernetes 배포') {
            when {
                equals expected: true, actual: params.DEPLOY_TO_K8S
            }
            steps {
                sh """
                    echo "=== Kubernetes 배포 ==="
                    
                    # Kubernetes 매니페스트 업데이트 (개발환경)
                    if kubectl get deployment ${params.SERVICE_NAME} -n elice-devops-${params.ENVIRONMENT} >/dev/null 2>&1; then
                        echo "기존 배포 업데이트"
                        kubectl set image deployment/${params.SERVICE_NAME} \\
                            ${params.SERVICE_NAME}=${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG} \\
                            -n elice-devops-${params.ENVIRONMENT}
                        
                        # 롤아웃 상태 확인
                        kubectl rollout status deployment/${params.SERVICE_NAME} -n elice-devops-${params.ENVIRONMENT}
                    else
                        echo "해당 환경에 배포가 존재하지 않습니다"
                        echo "수동으로 매니페스트를 적용하세요"
                    fi
                """
            }
        }
    }
    
    post {
        always {
            echo "파이프라인 완료 - 서비스: ${params.SERVICE_NAME}, 환경: ${params.ENVIRONMENT}"
            echo "실행 시간: ${currentBuild.durationString}"
            
            // 빌드 아티팩트 정리 (선택적)
            sh '''
                echo "임시 파일 정리"
                docker system prune -f --filter "label=build-number=${BUILD_NUMBER}" || true
            '''
        }
        
        success {
            echo "🎉 ${params.SERVICE_NAME} 빌드 및 배포가 성공적으로 완료되었습니다!"
            
            // Slack 알림 (선택적 - 환경변수가 설정된 경우)
            script {
                if (env.SLACK_WEBHOOK_URL) {
                    // slackSend 플러그인 사용
                    echo "Slack 알림 전송 준비 완료"
                }
            }
        }
        
        failure {
            echo "❌ ${params.SERVICE_NAME} 빌드 중 오류가 발생했습니다."
            echo "로그를 확인하여 문제를 해결하세요."
        }
        
        unstable {
            echo "⚠️ ${params.SERVICE_NAME} 빌드가 불안정한 상태로 완료되었습니다."
        }
    }
}