# KijaniKiosk Payments Capstone

## Overview
This repository automates infrastructure provisioning and deployment for the KijaniKiosk Payments mock API. It uses Terraform to create AWS infrastructure, Ansible to deploy Kubernetes manifests to EKS, and Jenkins to orchestrate CI/CD for staging and production. The end result is a working Kubernetes deployment with environment-specific configuration and a gated release flow.

## What This Repo Achieves
- Provisions a VPC, EKS cluster, and S3 bucket for receipt storage.
- Creates an IAM role and Kubernetes service account for secure access to S3.
- Deploys the payments API to Kubernetes with per-environment ConfigMaps.
- Automates staging deployment, smoke testing, and a manual production approval gate.

## High-Level Flow
1. Terraform builds AWS infrastructure (VPC, EKS, S3, IAM).
2. Jenkins connects to EKS and runs Ansible.
3. Ansible applies Kubernetes manifests and environment configuration.
4. Jenkins runs a staging smoke test and gates production.

## Terraform (Infrastructure)
Located in `terraform/`:
- **Networking**: Creates a VPC with public subnets and routes. NAT is disabled, so nodes and services are public by default.
- **EKS**: Provisions an EKS cluster and a managed node group for staging workloads.
- **S3**: Creates a receipts bucket with an environment-specific name.
- **IAM/IRSA**: Creates an IAM policy for S3 access and an IAM role for service accounts (IRSA) to allow the app to access the bucket securely.
- **Kubernetes bootstrap**: Creates a namespace and a service account in the cluster.

Key outputs include the cluster name, cluster endpoint, S3 bucket name, and IAM role ARN.

## Ansible (Deployment)
Located in `ansible/playbook.yaml`:
- **Namespace**: Ensures `kijani-<env>` exists.
- **Registry secret**: Builds a Docker Hub pull secret from Jenkins-provided environment variables.
- **ConfigMap**: Renders `k8s/manifests/kk-payments-configmap.yaml.j2` with the target environment and fetched S3 bucket name.
- **Workload + service**: Applies the Deployment and Service manifests that expose the application via a LoadBalancer.

Ansible expects `env` to be `staging` or `production` and depends on AWS CLI access to look up the receipts bucket.

## Jenkins Pipeline
Defined in `Jenkinsfile`:
- **Checkout**: Pulls source from SCM.
- **Cluster access**: Runs `aws eks update-kubeconfig` to connect to the EKS cluster.
- **Deploy to staging**: Runs Ansible with `env=staging`.
- **Smoke test**: Resolves the service LoadBalancer hostname and checks `/api/health` with retries.
- **Approval gate**: Requires manual approval before production.
- **Deploy to production**: Runs Ansible with `env=production`.

## Application Artifacts
- **Source**: `kk-payments/src` is the mock API.
- **Build output**: The build script copies JS and HTML into `dist/`.
- **Docker**: The Dockerfile builds a production image, installs runtime dependencies only, and exposes port 8067.

## Getting Started
### Prerequisites
- AWS CLI configured with credentials that can create VPC, EKS, S3, IAM.
- Terraform >= 1.5
- kubectl
- Ansible with the Kubernetes collection:
  - `ansible-galaxy collection install kubernetes.core`
- Docker Hub account for image hosting

### Build and Push the App Image
The deployment manifest references a Docker image. Build and push the image tag you want to run:
```bash
npm install
npm run build

docker build -t <dockerhub-user>/kk-payments-cloud:<tag> .
docker push <dockerhub-user>/kk-payments-cloud:<tag>
```
Update the image tag in `k8s/manifests/kk-payments-deployment.yaml`.

### Provision Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### Deploy to Staging Manually
```bash
aws eks update-kubeconfig --region eu-west-1 --name kijani-staging-cluster
export DOCKER_HUB_USER=<your-user>
export DOCKER_HUB_PASSWORD=<your-password>
export DOCKER_HUB_EMAIL=<your-email>

cd ansible
ansible-playbook playbook.yaml -e env=staging
```

### Deploy to Production Manually
```bash
cd ansible
ansible-playbook playbook.yaml -e env=production
```

## Production Gaps (4 points)
1. **Network isolation**: EKS nodes and services live in public subnets without NAT. Production should use private subnets, NAT gateways, and restricted security groups.
2. **Autoscaling and resilience**: Node and pod autoscaling are not enabled. Production should add Cluster Autoscaler, HPA, and multi-AZ node groups.
3. **Ingress and TLS**: The service is a public LoadBalancer without TLS termination. Production should use an Ingress controller with TLS certificates and hostname routing.
4. **Secrets management**: Docker Hub credentials are injected via Jenkins and stored in a Kubernetes secret. Production should use a secrets manager (AWS Secrets Manager or SSM) and short-lived credentials.

## Repo Structure
- `terraform/` - AWS infrastructure provisioning
- `ansible/` - Deployment automation to EKS
- `k8s/` - Kubernetes manifests and config templates
- `kk-payments/` - Application source code
- `Jenkinsfile` - CI/CD pipeline
