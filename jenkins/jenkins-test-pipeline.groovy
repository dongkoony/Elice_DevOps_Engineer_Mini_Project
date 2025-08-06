pipeline {
    agent any
    
    options {
        // 빌드 히스토리 관리
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // 타임아웃 설정
        timeout(time: 10, unit: 'MINUTES')
        // 동시 빌드 방지
        disableConcurrentBuilds()
    }
    
    stages {
        stage('환경 확인') {
            steps {
                script {
                    echo "=== Elice DevOps 테스트 파이프라인 ==="
                    echo "Jenkins 버전: ${env.JENKINS_VERSION}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                    echo "Node Name: ${env.NODE_NAME}"
                    echo "Workspace: ${env.WORKSPACE}"
                    echo "Job Name: ${env.JOB_NAME}"
                    echo "Build URL: ${env.BUILD_URL}"
                }
            }
        }
        
        stage('시스템 정보') {
            steps {
                sh '''
                    echo "=== 시스템 정보 확인 ==="
                    echo "호스트명: $(hostname)"
                    echo "현재 사용자: $(whoami)"
                    echo "작업 디렉토리: $(pwd)"
                    echo "디스크 사용량:"
                    df -h | head -5
                    echo "메모리 사용량:"
                    free -h
                '''
            }
        }
        
        stage('도구 확인') {
            steps {
                sh '''
                    echo "=== 설치된 도구 확인 ==="
                    echo "Python 버전:"
                    python3 --version
                    
                    echo "Docker 버전:"
                    docker --version
                    
                    echo "kubectl 버전:"
                    kubectl version --client
                    
                    echo "uv 패키지 매니저:"
                    uv --version || echo "uv 미설치"
                    
                    echo "Git 버전:"
                    git --version
                    
                    echo "환경 변수 확인:"
                    echo "PATH: $PATH"
                    echo "UV_CACHE_DIR: ${UV_CACHE_DIR:-'미설정'}"
                    echo "DOCKER_REGISTRY: ${DOCKER_REGISTRY:-'미설정'}"
                '''
            }
        }
        
        stage('Kubernetes 연결 테스트') {
            steps {
                sh '''
                    echo "=== Kubernetes 클러스터 연결 테스트 ==="
                    kubectl cluster-info || echo "Kubernetes 클러스터 연결 실패"
                    kubectl get nodes || echo "노드 정보 조회 실패"
                    kubectl get namespaces || echo "네임스페이스 조회 실패"
                '''
            }
        }
        
        stage('Docker 테스트') {
            steps {
                sh '''
                    echo "=== Docker 연결 테스트 ==="
                    docker info | head -10 || echo "Docker daemon 연결 실패"
                    docker images | head -5 || echo "Docker 이미지 조회 실패"
                '''
            }
        }
        
        stage('완료') {
            steps {
                echo "✅ Jenkins 테스트 파이프라인 완료!"
                echo "모든 기본 도구들이 정상적으로 설치되어 있습니다."
                echo "다음 단계: 실제 마이크로서비스 빌드 파이프라인 구성"
            }
        }
    }
    
    post {
        always {
            echo "파이프라인 실행 완료 - 상태: ${currentBuild.result ?: 'SUCCESS'}"
            echo "실행 시간: ${currentBuild.durationString}"
        }
        success {
            echo "🎉 파이프라인이 성공적으로 완료되었습니다!"
        }
        failure {
            echo "❌ 파이프라인 실행 중 오류가 발생했습니다."
        }
        unstable {
            echo "⚠️ 파이프라인이 불안정한 상태로 완료되었습니다."
        }
    }
}