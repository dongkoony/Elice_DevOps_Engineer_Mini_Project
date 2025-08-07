pipeline {
    agent any
    
    // 파라미터를 변수로 하드코딩 (테스트용)
    environment {
        SERVICE_NAME = 'api-gateway'
        ENVIRONMENT = 'dev'
        IMAGE_TAG = 'v1.0.0'
        SKIP_TESTS = 'false'
        DEPLOY_TO_K8S = 'false'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 15, unit: 'MINUTES')
    }
    
    stages {
        stage('🔍 환경 확인') {
            steps {
                script {
                    echo "=== Elice DevOps 마이크로서비스 빌드 (하드코딩 버전) ==="
                    echo "서비스: ${env.SERVICE_NAME}"
                    echo "환경: ${env.ENVIRONMENT}"
                    echo "이미지 태그: ${env.IMAGE_TAG}"
                    
                    // 동적 변수 설정
                    env.SERVICE_PATH = "aws/microservices/${env.SERVICE_NAME}"
                    env.IMAGE_NAME = "localhost:5000/${env.SERVICE_NAME}"
                    env.FULL_IMAGE_TAG = "${env.ENVIRONMENT}-${env.BUILD_NUMBER}-${env.IMAGE_TAG}"
                    
                    echo "서비스 경로: ${env.SERVICE_PATH}"
                    echo "이미지명: ${env.IMAGE_NAME}:${env.FULL_IMAGE_TAG}"
                }
            }
        }
        
        stage('📂 파일 시스템 검증') {
            steps {
                sh '''
                    echo "=== 프로젝트 구조 확인 ==="
                    echo "현재 위치: $(pwd)"
                    
                    echo "마이크로서비스 디렉토리:"
                    ls -la aws/microservices/ | head -5
                    
                    echo "API Gateway 서비스 확인:"
                    if [ -d "aws/microservices/api-gateway" ]; then
                        echo "✅ API Gateway 디렉토리 존재"
                        ls -la aws/microservices/api-gateway/
                    else
                        echo "❌ API Gateway 디렉토리 없음"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('📦 의존성 설치') {
            steps {
                dir('aws/microservices/api-gateway') {
                    sh '''
                        echo "=== uv를 이용한 의존성 설치 ==="
                        echo "현재 디렉토리: $(pwd)"
                        
                        # pyproject.toml 확인
                        if [ -f "pyproject.toml" ]; then
                            echo "✅ pyproject.toml 발견"
                            head -5 pyproject.toml
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
                        
                        echo "설치 완료!"
                    '''
                }
            }
        }
        
        stage('🏗️ Docker 이미지 빌드') {
            steps {
                dir('aws/microservices/api-gateway') {
                    sh '''
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
                        IMAGE_TAG="localhost:5000/api-gateway:dev-${BUILD_NUMBER}-v1.0.0"
                        echo "이미지 빌드 시작: $IMAGE_TAG"
                        
                        docker build -t $IMAGE_TAG -t localhost:5000/api-gateway:latest .
                        
                        echo "✅ 빌드된 이미지 확인:"
                        docker images | grep api-gateway | head -3
                    '''
                }
            }
        }
        
        stage('✅ 완료') {
            steps {
                echo "🎉 API Gateway 빌드 완료!"
                echo "생성된 이미지: localhost:5000/api-gateway:dev-${env.BUILD_NUMBER}-v1.0.0"
            }
        }
    }
    
    post {
        always {
            echo "파이프라인 완료 - API Gateway (dev 환경)"
        }
        success {
            echo "🎉 빌드 성공!"
        }
        failure {
            echo "❌ 빌드 실패"
        }
    }
}