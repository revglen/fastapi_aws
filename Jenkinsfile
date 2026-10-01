pipeline {
    agent any

    environment {
        AWS_REGION   = 'eu-west-1'
        PROJECT_NAME = 'fastapi-cicd'
        ECS_CLUSTER  = "${PROJECT_NAME}-cluster"
        ECS_SERVICE  = "${PROJECT_NAME}-service"
        TASK_FAMILY  = "${PROJECT_NAME}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
            }
        }

        stage('Lint & Test') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -q -r requirements-dev.txt
                    ruff check src/fastapi_aws
                    
                    pip install -q pip-audit
                    pip-audit -r requirements.txt
                '''
            }
        }

        stage('Build Image') {
            steps {
                sh "docker build -t ${PROJECT_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Scan Image') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed \
                    ${PROJECT_NAME}:${IMAGE_TAG}
                """
            }
        }

        stage('Terraform Infra') {
            steps {
                dir('terraform') {
                    withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            terraform init -input=false
                            terraform apply -input=false -auto-approve
                        '''

                        script {
                            env.ECR_REPO_URL = sh(script: 'terraform output -raw ecr_repository_url', returnStdout: true).trim()
                            env.ALB_DNS = sh(script: 'terraform output -raw alb_dns_name', returnStdout: true).trim()
                        }
                    }
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} \
                        | docker login --username AWS --password-stdin ${ECR_REPO_URL}
                        docker tag ${PROJECT_NAME}:${IMAGE_TAG} ${ECR_REPO_URL}:${IMAGE_TAG}
                        docker push ${ECR_REPO_URL}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        set -e
                        CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
                            --task-definition $TASK_FAMILY --region $AWS_REGION --query 'taskDefinition')

                        NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | jq \
                            --arg IMAGE "$ECR_REPO_URL:$IMAGE_TAG" \
                            '.containerDefinitions[0].image = $IMAGE
                             | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
                                   .compatibilities, .registeredAt, .registeredBy)')

                        NEW_ARN=$(aws ecs register-task-definition --region $AWS_REGION \
                            --cli-input-json "$NEW_TASK_DEF" \
                            --query 'taskDefinition.taskDefinitionArn' --output text)

                        aws ecs update-service --region $AWS_REGION \
                            --cluster $ECS_CLUSTER --service $ECS_SERVICE \
                            --task-definition "$NEW_ARN" --force-new-deployment

                        aws ecs wait services-stable --region $AWS_REGION \
                            --cluster $ECS_CLUSTER --services $ECS_SERVICE
                    '''
                }
            }
        }

        stage('Smoke test') {
            steps {
                sh """
                    curl -sf --retry 5 --retry-delay 10 --retry-connrefused \
                    http://${ALB_DNS}/health
                """
            }
        }

        stage('Cleanup local Docker Cache') {
            steps {
                sh 'docker image prune -af --filter "until=24h" || true'
            }
        }
    }

    post {
        success {
            echo "Deployed ${IMAGE_TAG}. App is live at http://${ALB_DNS}"
        }

        failure {
            echo "Deploy failed. Previous task definition revision is still running, nothing was torn down."
        }
    }
}