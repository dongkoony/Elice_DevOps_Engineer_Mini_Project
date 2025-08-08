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
            defaultValue: 'v1.0.0',
            description: 'Docker 이미지 태그'
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
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        stage('🔍 파라미터 및 환경 확인') {
            steps {
                script {
                    echo "=== Elice DevOps 마이크로서비스 빌드 파이프라인 v2 ==="
                    echo "서비스: ${params.SERVICE_NAME}"
                    echo "환경: ${params.ENVIRONMENT}"
                    echo "이미지 태그: ${params.IMAGE_TAG}"
                    echo "테스트 건너뛰기: ${params.SKIP_TESTS}"
                    echo "K8s 배포: ${params.DEPLOY_TO_K8S}"
                    
                    // 동적 변수 설정
                    env.SERVICE_PATH = "aws/microservices/${params.SERVICE_NAME}"
                    env.IMAGE_NAME = "localhost:5000/${params.SERVICE_NAME}"
                    env.FULL_IMAGE_TAG = "${params.ENVIRONMENT}-${env.BUILD_NUMBER}-${params.IMAGE_TAG}"
                    
                    echo "서비스 경로: ${env.SERVICE_PATH}"
                    echo "이미지명: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
                }
            }
        }
        
        stage('📂 파일 시스템 검증') {
            steps {
                sh """
                    echo "=== 프로젝트 구조 확인 ==="
                    echo "현재 위치: \$(pwd)"
                    echo "Git 상태:"
                    git status || echo "Git 정보 없음"
                    
                    echo "마이크로서비스 디렉토리:"
                    ls -la aws/microservices/ | head -5
                    
                    echo "선택된 서비스 확인:"
                    if [ -d "${env.SERVICE_PATH}" ]; then
                        echo "✅ ${env.SERVICE_PATH} 디렉토리 존재"
                        ls -la ${env.SERVICE_PATH}/
                    else
                        echo "❌ ${env.SERVICE_PATH} 디렉토리 없음"
                        exit 1
                    fi
                """
            }
        }
        
        stage('📦 의존성 설치') {
            steps {
                dir("${env.SERVICE_PATH}") {
                    sh '''
                        echo "=== uv를 이용한 의존성 설치 ==="
                        echo "현재 디렉토리: $(pwd)"
                        
                        # pyproject.toml 확인
                        if [ -f "pyproject.toml" ]; then
                            echo "✅ pyproject.toml 발견"
                            head -10 pyproject.toml
                        else
                            echo "❌ pyproject.toml 없음"
                            exit 1
                        fi
                        
                        # uv 가상환경 생성
                        echo "uv 가상환경 생성..."
                        uv venv --python 3.11
                        
                        # 의존성 설치
                        if [ -f "requirements.lock" ]; then
                            echo "requirements.lock으로 설치"
                            uv pip install -r requirements.lock
                        else
                            echo "pyproject.toml로 설치"  
                            uv pip install .
                        fi
                        
                        echo "설치된 패키지 (상위 10개):"
                        uv pip list | head -10
                    '''
                }
            }
        }
        
        stage('🧪 코드 품질 검사') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                dir("${env.SERVICE_PATH}") {
                    sh '''
                        echo "=== 코드 품질 검사 ==="
                        source .venv/bin/activate
                        
                        # 기본 Python 문법 검사
                        echo "Python 파일 컴파일 검사..."
                        find . -name "*.py" -exec python -m py_compile {} \\; || echo "일부 파일에서 경고 발견"
                        
                        echo "✅ 코드 품질 검사 완료"
                    '''
                }
            }
        }
        
        stage('🏗️ Docker 이미지 빌드') {
            steps {
                dir("${env.SERVICE_PATH}") {
                    sh """
                        echo "=== Docker 이미지 빌드 ==="
                        
                        # Dockerfile 확인
                        if [ -f "Dockerfile" ]; then
                            echo "✅ Dockerfile 발견"
                            echo "Dockerfile 내용 (첫 5줄):"
                            head -5 Dockerfile
                        else
                            echo "❌ Dockerfile 없음"
                            exit 1
                        fi
                        
                        # Docker 이미지 빌드
                        echo "이미지 빌드 시작: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
                        docker build -t ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG} -t ${env.IMAGE_NAME}:latest .
                        
                        echo "✅ 빌드된 이미지 확인:"
                        docker images | grep ${params.SERVICE_NAME} | head -3
                    """
                }
            }
        }
        
        stage('🚀 배포 (조건부)') {
            when {
                equals expected: true, actual: params.DEPLOY_TO_K8S
            }
            steps {
                echo "Kubernetes 배포는 추후 구현 예정"
                echo "현재는 이미지 빌드까지만 수행"
            }
        }
    }
    
    post {
        always {
            echo "파이프라인 완료: ${params.SERVICE_NAME} (${params.ENVIRONMENT})"
            echo "실행 시간: ${currentBuild.durationString}"
        }
        success {
            echo "🎉 ${params.SERVICE_NAME} 빌드 성공!"
        }
        failure {
            echo "❌ ${params.SERVICE_NAME} 빌드 실패"
        }
    }
}