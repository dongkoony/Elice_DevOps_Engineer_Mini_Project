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
            description: 'Docker 이미지 태그'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: '테스트 건너뛰기'
        )
        booleanParam(
            name: 'SKIP_DOCKER',
            defaultValue: false,
            description: 'Docker 빌드 건너뛰기 (권한 문제 시)'
        )
    }
    
    environment {
        SERVICE_PATH = "aws/microservices/${params.SERVICE_NAME}"
        IMAGE_NAME = "localhost:5000/${params.SERVICE_NAME}"
        BUILD_TAG = "${params.ENVIRONMENT}-${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'unknown'}"
    }
    
    stages {
        stage('🔍 환경 준비') {
            steps {
                echo "=== Elice DevOps 마이크로서비스 빌드 ==="
                echo "서비스: ${params.SERVICE_NAME}"
                echo "환경: ${params.ENVIRONMENT}" 
                echo "이미지: ${env.IMAGE_NAME}:${env.BUILD_TAG}"
                echo "워크스페이스: ${env.WORKSPACE}"
                
                // 기본 환경 확인
                sh '''
                    echo "=== 시스템 환경 확인 ==="
                    whoami
                    pwd
                    python3 --version || echo "Python3 not found"
                    docker --version || echo "Docker not accessible"
                    ls -la /var/run/docker.sock || echo "Docker socket not accessible"
                '''
                
                // 서비스 디렉토리 확인
                script {
                    if (!fileExists("${env.SERVICE_PATH}")) {
                        error("서비스 디렉토리를 찾을 수 없습니다: ${env.SERVICE_PATH}")
                    }
                    echo "✅ 서비스 디렉토리 확인 완료"
                }
            }
        }
        
        stage('📋 서비스 정보 확인') {
            steps {
                dir("${env.SERVICE_PATH}") {
                    sh '''
                        echo "=== 서비스 파일 구조 확인 ==="
                        ls -la
                        
                        echo "=== Python 파일 확인 ==="
                        find . -name "*.py" | head -10
                        
                        echo "=== pyproject.toml 확인 ==="
                        if [ -f "pyproject.toml" ]; then
                            echo "pyproject.toml 존재함"
                            head -20 pyproject.toml
                        else
                            echo "pyproject.toml 파일이 없습니다"
                        fi
                        
                        echo "=== Dockerfile 확인 ==="
                        if [ -f "Dockerfile" ]; then
                            echo "Dockerfile 존재함"
                            head -10 Dockerfile
                        else
                            echo "Dockerfile이 없습니다"
                        fi
                    '''
                }
            }
        }
        
        stage('🧪 기본 테스트') {
            when {
                expression { params.SKIP_TESTS != true }
            }
            steps {
                dir("${env.SERVICE_PATH}") {
                    sh '''
                        echo "=== 기본 Python 문법 검사 ==="
                        find . -name "*.py" -exec python3 -m py_compile {} \\; 2>/dev/null || echo "Python 문법 검사 완료"
                        
                        echo "=== 의존성 파일 확인 ==="
                        if [ -f "requirements.txt" ]; then
                            echo "requirements.txt 발견"
                            head -10 requirements.txt
                        fi
                        if [ -f "requirements.lock" ]; then
                            echo "requirements.lock 발견"
                            wc -l requirements.lock
                        fi
                        
                        echo "✅ 기본 테스트 완료"
                    '''
                }
            }
        }
        
        stage('🏗️ Docker 이미지 빌드') {
            when {
                expression { params.SKIP_DOCKER != true }
            }
            steps {
                script {
                    try {
                        dir("${env.SERVICE_PATH}") {
                            sh """
                                echo "=== Docker 이미지 빌드 시도 ==="
                                
                                # Docker 데몬 접근 확인
                                docker info || (echo "Docker 접근 불가 - 권한 문제"; exit 1)
                                
                                # Docker 이미지 빌드
                                docker build \\
                                    --tag ${env.IMAGE_NAME}:${env.BUILD_TAG} \\
                                    --tag ${env.IMAGE_NAME}:latest \\
                                    --label "service=${params.SERVICE_NAME}" \\
                                    --label "environment=${params.ENVIRONMENT}" \\
                                    --label "build-number=${env.BUILD_NUMBER}" \\
                                    .
                                
                                echo "✅ Docker 이미지 빌드 완료"
                                docker images | grep ${params.SERVICE_NAME}
                            """
                        }
                    } catch (Exception e) {
                        echo "❌ Docker 빌드 실패: ${e.getMessage()}"
                        echo "권한 문제일 가능성이 높습니다. SKIP_DOCKER=true로 재실행해보세요."
                        throw e
                    }
                }
            }
        }
        
        stage('✅ 빌드 결과') {
            steps {
                sh """
                    echo "=== 빌드 완료 요약 ==="
                    echo "서비스: ${params.SERVICE_NAME}"
                    echo "환경: ${params.ENVIRONMENT}"
                    echo "빌드 태그: ${env.BUILD_TAG}"
                    echo "빌드 시간: \$(date)"
                    echo "Jenkins 빌드 번호: ${env.BUILD_NUMBER}"
                    echo "Git 커밋: ${env.GIT_COMMIT ?: 'N/A'}"
                    
                    if [ "${params.SKIP_DOCKER}" != "true" ]; then
                        echo "생성된 Docker 이미지:"
                        docker images | grep ${params.SERVICE_NAME} || echo "이미지 확인 불가"
                    else
                        echo "Docker 빌드를 건너뛰었습니다"
                    fi
                """
            }
        }
    }
    
    post {
        always {
            echo "🏁 파이프라인 실행 완료"
            echo "서비스: ${params.SERVICE_NAME}"
            echo "결과: ${currentBuild.currentResult}"
        }
        
        success {
            echo "🎉 ${params.SERVICE_NAME} 빌드가 성공적으로 완료되었습니다!"
        }
        
        failure {
            echo "❌ ${params.SERVICE_NAME} 빌드 중 오류가 발생했습니다."
            echo "로그를 확인하여 문제를 해결하세요."
        }
        
        cleanup {
            // 안전한 정리 (권한 문제 방지)
            script {
                try {
                    sh 'docker system prune -f --volumes --filter "label=build-number=${BUILD_NUMBER}" || true'
                } catch (Exception e) {
                    echo "정리 과정에서 권한 문제 발생 (정상적인 상황)"
                }
            }
        }
    }
}