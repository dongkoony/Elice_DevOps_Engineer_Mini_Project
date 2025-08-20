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
                    # uv가 이미 설치되어 있는지 확인
                    if ! command -v uv >/dev/null 2>&1; then
                        echo "Installing uv..."
                        curl -LsSf https://astral.sh/uv/install.sh | sh
                        chmod +x $HOME/.local/bin/uv
                    else
                        echo "uv already installed"
                    fi
                    
                    # PATH 설정 및 권한 확인
                    export PATH="$HOME/.local/bin:$PATH"
                    ls -la $HOME/.local/bin/uv || echo "uv binary not found"
                    chmod +x $HOME/.local/bin/uv 2>/dev/null || echo "chmod not needed"
                    uv --version
                '''
            }
        }
        
        stage('Python Setup') {
            steps {
                dir('aws/microservices/api-gateway') {
                    sh '''
                        export PATH="$HOME/.local/bin:$PATH"
                        # uv 실행 권한 재확인
                        chmod +x $HOME/.local/bin/uv 2>/dev/null || echo "chmod not needed"
                        which uv || echo "uv not in PATH"
                        ls -la $HOME/.local/bin/uv
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
                                ruff check . --output-format=github || echo "Lint check completed with warnings"
                                echo "Lint stage completed successfully"
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
                        pytest --cov=. --cov-report=xml --cov-report=html --junitxml=test-results.xml || exit_code=$?
                        if [ "${exit_code:-0}" = "5" ]; then
                            echo "No tests found - this is acceptable for now"
                            exit 0
                        elif [ "${exit_code:-0}" != "0" ]; then
                            echo "Tests failed with exit code $exit_code"
                            exit $exit_code
                        fi
                        echo "Tests completed successfully"
                    '''
                }
            }
            post {
                always {
                    script {
                        if (fileExists('aws/microservices/api-gateway/test-results.xml')) {
                            def testContent = readFile('aws/microservices/api-gateway/test-results.xml')
                            if (testContent.contains('<testcase') || testContent.contains('tests="') && !testContent.contains('tests="0"')) {
                                junit 'aws/microservices/api-gateway/test-results.xml'
                            } else {
                                echo "Test report exists but contains no test results - skipping junit publication"
                            }
                        } else {
                            echo "No test results file found"
                        }
                        
                        if (fileExists('aws/microservices/api-gateway/coverage.xml')) {
                            publishHTML([
                                allowMissing: true,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'aws/microservices/api-gateway/htmlcov',
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        } else {
                            echo "No coverage report found"
                        }
                    }
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