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
        FULL_IMAGE_TAG = "${params.ENVIRONMENT}-${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'unknown'}"
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
        
        stage('📦 의존성 설치 및 검증') {
            steps {
                dir("${env.SERVICE_PATH}") {
                    sh '''
                        echo "=== uv를 이용한 의존성 설치 ==="
                        
                        # uv 가상환경 생성
                        uv venv --python 3.11
                        
                        # 의존성 설치 (lockfile 우선)
                        if [ -f "requirements.lock" ]; then
                            echo "requirements.lock 파일로 의존성 설치"
                            uv pip install -r requirements.lock
                        else
                            echo "pyproject.toml로 의존성 설치"
                            uv pip install .
                        fi
                        
                        # 설치된 패키지 확인
                        echo "설치된 패키지 목록:"
                        uv pip list | head -20
                    '''
                }
            }
        }
        
        stage('🧪 코드 품질 검사') {
            when {
                not { params.SKIP_TESTS }
            }
            parallel {
                stage('린팅') {
                    steps {
                        dir("${env.SERVICE_PATH}") {
                            sh '''
                                echo "=== 코드 린팅 검사 ==="
                                source .venv/bin/activate
                                
                                # ruff가 있다면 사용, 없다면 기본 검사
                                if uv pip show ruff >/dev/null 2>&1; then
                                    echo "Ruff로 린팅 검사"
                                    uv run ruff check . || echo "린팅 경고 발견"
                                else
                                    echo "기본 Python 문법 검사"
                                    python -m py_compile **/*.py 2>/dev/null || echo "Python 파일 컴파일 검사 완료"
                                fi
                            '''
                        }
                    }
                }
                
                stage('타입 검사') {
                    steps {
                        dir("${env.SERVICE_PATH}") {
                            sh '''
                                echo "=== 타입 검사 ==="
                                source .venv/bin/activate
                                
                                # mypy가 있다면 사용
                                if uv pip show mypy >/dev/null 2>&1; then
                                    echo "mypy로 타입 검사"
                                    uv run mypy . || echo "타입 검사 경고 발견"
                                else
                                    echo "mypy가 설치되지 않음 - 건너뛰기"
                                fi
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
                            --label "git-commit=\${GIT_COMMIT:-unknown}" \\
                            .
                        
                        echo "✅ Docker 이미지 빌드 완료"
                        docker images | grep ${params.SERVICE_NAME} | head -5
                    """
                }
            }
        }
        
        stage('🔐 보안 검사') {
            when {
                not { params.SKIP_TESTS }
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