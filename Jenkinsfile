pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = credentials('docker-hub-creds')
        DOCKER_HUB_EMAIL = "solohlemons75@gamil.com" 
        
        AWS_DEFAULT_REGION = "eu-west-1"
        CLUSTER_NAME = "kijani-staging-cluster"

        AWS_ACCESS_KEY_ID     = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Connect to EKS') {
            steps {
                sh "aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${CLUSTER_NAME}"
            }
        }
        

        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                sh """
                export DOCKER_HUB_PASSWORD=\$DOCKER_HUB_USER_PSW
                export DOCKER_HUB_USER=\$DOCKER_HUB_USER_USR
                cd ansible
                ansible-playbook playbook.yaml -e env=staging
                """
            }
        }

        stage('Smoke Test Staging') {
            steps {
                script {
                    echo "Waiting for the Load Balancer to stabilize..."
                    sleep time: 10, unit: 'SECONDS'
                    
                    def stagingUrl = sh(
                        script: "kubectl get svc kk-payments-service -n kijani-staging -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                        returnStdout: true
                    ).trim()

                    echo "Running smoke test against: http://${stagingUrl}:8067/api/health"
                    sh "curl -f -s --retry 10 --retry-delay 5 --retry-connrefused http://${stagingUrl}:8067/api/health"
                }
            }
        }

        stage('Production Approval Gate') {
            steps {
                input message: 'Staging Smoke Test Passed! Approve deployment to Production?', ok: 'Deploy to Prod'
            }
        }

        stage('Deploy to Production') {
            steps {
                sh """
                export DOCKER_HUB_PASSWORD=\$DOCKER_HUB_USER_PSW
                export DOCKER_HUB_USER=\$DOCKER_HUB_USER_USR
                cd ansible
                ansible-playbook playbook.yaml -e env=production
                """
            }
        }
    }
}