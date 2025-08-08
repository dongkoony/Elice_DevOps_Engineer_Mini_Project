pipeline {
    agent any
    
    parameters {
        choice(
            name: 'SERVICE_NAME',
            choices: ['api-gateway', 'auth-service', 'user-service'],
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
    }
    
    stages {
        stage('파라미터 확인') {
            steps {
                echo "=== 파라미터 테스트 ==="
                echo "SERVICE_NAME: ${params.SERVICE_NAME}"
                echo "ENVIRONMENT: ${params.ENVIRONMENT}"
                echo "IMAGE_TAG: ${params.IMAGE_TAG}"
                echo "SKIP_TESTS: ${params.SKIP_TESTS}"
            }
        }
        
        stage('기본 빌드 테스트') {
            steps {
                sh '''
                    echo "현재 디렉토리: $(pwd)"
                    echo "Git 상태 확인:"
                    git status || echo "Git 정보 없음"
                    
                    echo "마이크로서비스 디렉토리 확인:"
                    ls -la aws/microservices/ | head -10
                '''
            }
        }
    }
    
    post {
        always {
            echo "테스트 파이프라인 완료"
        }
    }
}