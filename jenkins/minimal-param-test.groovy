pipeline {
    agent any
    
    parameters {
        string(name: 'TEST_PARAM', defaultValue: 'hello', description: '테스트 파라미터')
    }
    
    stages {
        stage('테스트') {
            steps {
                echo "파라미터 값: ${params.TEST_PARAM}"
            }
        }
    }
}