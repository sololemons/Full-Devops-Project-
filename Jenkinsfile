pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = credentials('docker-hub-creds')
        DOCKER_HUB_EMAIL = "solohlemons75@gmail.com" 
        
        AWS_DEFAULT_REGION = "eu-west-1"
        CLUSTER_NAME = "kijani-staging-cluster"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Connect to EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh "aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${CLUSTER_NAME}"
                }
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
                    echo "Waiting for the Load Balancer to be stable..."
                    sleep time: 30, unit: 'SECONDS'
                    
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