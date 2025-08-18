pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'localhost:5000'
        IMAGE_NAME = 'api-gateway'
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.substring(0,7)}"
        UV_CACHE_DIR = "${WORKSPACE}/.uv-cache"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                }
            }
        }
        
        stage('Install uv') {
            steps {
                sh '''
                    curl -LsSf https://astral.sh/uv/install.sh | sh
                    export PATH="$HOME/.local/bin:$PATH"
                    uv --version
                '''
            }
        }
        
        stage('Python Setup') {
            steps {
                dir('aws/microservices/api-gateway') {
                    sh '''
                        export PATH="$HOME/.local/bin:$PATH"
                        uv venv
                        . .venv/bin/activate
                        uv pip install -e .[dev]
                        # pip가 설치되었는지 확인하고 없으면 설치
                        python -m pip --version || uv pip install pip
                    '''
                }
            }
        }
        
        stage('Lock Dependencies') {
            steps {
                dir('aws/microservices/api-gateway') {
                    sh '''
                        export PATH="$HOME/.local/bin:$PATH"
                        . .venv/bin/activate
                        uv pip compile pyproject.toml -o requirements.lock
                        uv pip compile pyproject.toml --extra dev -o requirements-dev.lock
                    '''
                }
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Lint') {
                    steps {
                        dir('aws/microservices/api-gateway') {
                            sh '''
                                export PATH="$HOME/.local/bin:$PATH"
                                . .venv/bin/activate
                                ruff check . --output-format=github
                                ruff format --check .
                            '''
                        }
                    }
                }
                stage('Type Check') {
                    steps {
                        dir('aws/microservices/api-gateway') {
                            sh '''
                                export PATH="$HOME/.local/bin:$PATH"
                                . .venv/bin/activate
                                mypy . --install-types --non-interactive --ignore-missing-imports --allow-untyped-defs || echo "Type check completed with warnings"
                            '''
                        }
                    }
                }
                stage('Security Scan') {
                    steps {
                        dir('aws/microservices/api-gateway') {
                            sh '''
                                export PATH="$HOME/.local/bin:$PATH"
                                . .venv/bin/activate
                                bandit -r . -f json -o bandit-report.json || true
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Test') {
            steps {
                dir('aws/microservices/api-gateway') {
                    sh '''
                        export PATH="$HOME/.local/bin:$PATH"
                        . .venv/bin/activate
                        pytest --cov=. --cov-report=xml --cov-report=html --junitxml=test-results.xml
                    '''
                }
            }
            post {
                always {
                    publishTestResults testResultsPattern: 'aws/microservices/api-gateway/test-results.xml'
                    publishCoverage adapters: [coberturaAdapter('aws/microservices/api-gateway/coverage.xml')]
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    dir('aws/microservices/api-gateway') {
                        def image = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
                        docker.withRegistry("http://${DOCKER_REGISTRY}") {
                            image.push()
                            image.push("latest")
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Dev') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    sed -i "s|IMAGE_TAG_PLACEHOLDER|${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}|g" aws/kubernetes/dev/api-gateway-deployment.yaml
                    kubectl apply -f aws/kubernetes/dev/ --namespace=elice-devops-dev
                '''
            }
        }
        
        stage('Health Check') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // kubeconfig 확인 후 헬스체크 실행
                    def kubeconfigExists = sh(
                        script: 'kubectl cluster-info >/dev/null 2>&1',
                        returnStatus: true
                    ) == 0
                    
                    if (kubeconfigExists) {
                        timeout(time: 5, unit: 'MINUTES') {
                            sh '''
                                until kubectl get pods -n elice-devops-dev -l app=api-gateway -o jsonpath='{.items[0].status.phase}' | grep Running; do
                                    echo "Waiting for pod to be ready..."
                                    sleep 10
                                done
                                
                                POD_NAME=$(kubectl get pods -n elice-devops-dev -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
                                kubectl port-forward -n elice-devops-dev $POD_NAME 8080:8080 &
                                sleep 5
                                curl -f http://localhost:8080/health || exit 1
                            '''
                        }
                    } else {
                        echo "⚠️ kubeconfig not configured - skipping health check"
                        echo "Health check requires kubectl access to Kubernetes cluster"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                if (env.NODE_NAME) {
                    try {
                        archiveArtifacts artifacts: '**/requirements*.lock', allowEmptyArchive: true
                    } catch (Exception e) {
                        echo "Artifact archiving failed: ${e.getMessage()}"
                    }
                    cleanWs()
                } else {
                    echo "Skipping artifact archiving - no node context"
                }
            }
        }
        success {
            echo "Pipeline succeeded! Image: ${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed. Check logs for details."
        }
    }
}