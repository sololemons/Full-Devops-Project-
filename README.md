**TRACK A CAPSTONE**
---

**What the project is**

KijaniKiosk Payments is a mock payments API deployed to AWS using a three-tool stack: Terraform provisions the cloud infrastructure, Ansible handles the Kubernetes deployment, and Jenkins ties it all together with a CI/CD pipeline that includes a gated production release.

---

**Layer 1 — Terraform builds the foundation**

Before any code runs, Terraform creates everything the app needs to live in AWS:

- A **VPC** with public subnets so the cluster nodes can reach the internet 
- An **EKS cluster** with a managed node group to run Kubernetes workloads
- **EC2 Instances** which will work as worker nodes for the cluster so in my case i have spun 3 (t3.micro) which will be useful in running the pods
- An **S3 bucket** named per environment for receipt storage
- An **IAM role with IRSA** (IAM Roles for Service Accounts) — Instead of embedding AWS credentials in the app, the Kubernetes service account gets an IAM role attached which is attached to the pods through the deployment manifest. The pod can now read/write S3 without any hardcoded secrets.

Terraform outputs the cluster name, endpoint, bucket name, and IAM role ARN.These outputs get picked up by other files.

## Show VPC In Aws

![vpc](/screenshots/VPC.png)

## Show IAM role in Aws(kijanikiosk-payments-role)

![IAM-role](/screenshots/ROLES.png)

## Show Policies attached to the Role
 
![Policies](/screenshots/POLICIES.png)

## Show THe S3 bucket used to store receipts

![S3-buckets](/screenshots/S3BUCKETS.png)




---

**Layer 2 — Jenkins orchestrates the whole pipeline**

The `Jenkinsfile` defines five sequential stages:

1. **Checkout** — pulls the source from SCM
2. **Cluster access** — runs `aws eks update-kubeconfig` to connect `kubectl` to the EKS cluster
3. **Deploy to staging** — runs the Ansible playbook with `env=staging`
4. **Smoke test** — resolves the LoadBalancer hostname and hits `/api/health` with retries until it responds to make sure the pod is not only running but it is also healthy
5. **Approval gate** — pauses and waits for a human to approve before going further
6. **Deploy to production** — runs Ansible again with `env=production` if approved in the previous stage.

To see the jenkins logs during a full pipeline run with  approval to production check the .txt below 
- Link: [full-jenkins-output.txt](full-jenkins-output.txt)

---

**Layer 3 — Ansible handles Kubernetes deployment**

Ansible's playbook does four things for each environment:

- Creates the `kijani-<env>` namespace if it doesn't exist
- Builds a Docker Hub image pull secret from Jenkins-injected credentials
- Renders a **Jinja2 ConfigMap template** that injects `TARGET_ENV` and `S3_BUCKET_NAME` into the app's config
- Applies the Deployment and Service manifests 

---

**Layer 4 — What runs in Kubernetes**

The final running state in the `kijani-<env>` namespace includes a ConfigMap with environment-specific values, a Docker pull secret, a Deployment running the payments API image on port 8067, and a LoadBalancer Service pointing at it. The pod uses the IRSA-linked service account which is called **kk-payments-sa** to access S3 bucket without credentials to upload the receipt.

## Show Resources in both environments 

![show-resources](/screenshots/SHOWBOTHPRODUCTIONANDSTAGING%20]RESOURCES.png)

-Above You can see Pods,deployment,service,replicaaset for both environments this is assuming in my jenkins i approved the pipeline to productions hence the **kijani-production** namespace.

## Show The Eks Cluster in AWS evidence 

![eks-cluster](/screenshots/KIJANIEKSCLUSTER.png)

## Show The EC2 instances ie the worker-nodes

![ec2-worker-nodes](/screenshots/EC2WORKERNODES.png)





---

**Layer 5 — Monitoring and health checks**

Prometheus is intentionally not installed to keep the cluster lightweight for free-tier usage. Instead, there is a manual monitoring script you can run on demand:

- **Manual SLO checker**: The script in [k8s/manifests/check_slo_errors.sh](k8s/manifests/check_slo_errors.sh) pulls recent logs from the target namespace and calculates an error rate over the last 2 minutes. If the rate is above 5%, it flags an alert.
- **Jenkins smoke test**: The pipeline resolves the LoadBalancer hostname and runs a `curl` against `/api/health` with retries. This is a synthetic, post-deploy check that verifies the service is reachable and responding before moving on to production.
- **Kubernetes probes**: The Deployment defines readiness and liveness probes on `/api/health`. If the app stops responding, Kubernetes will remove it from service or restart it.
- **Docker health check**: The Docker image has a `HEALTHCHECK` that hits the same endpoint inside the container. This is an extra runtime signal if you run the container outside Kubernetes.

Run the script manually like this:
```bash
cd k8s/manifests
./check_slo_errors.sh staging
```


---

**Layer 6 — Serverless S3 integration**

The payments API writes receipt objects to Amazon S3.Access is granted through IRSA, so the pod uses the Kubernetes service account IAM role to write receipts without hardcoded AWS keys.



Below is evidence of a successful receipt write to the S3 bucket:

After we click **pay** in my Mock api a receipt is uploaded to our bucket and below we can see it 
![successful-receipt](/screenshots/SUCESSFULLRECEIPT.png)

Evidence of the receipt in the S3 bucket in aws 

![successful-receipt](/screenshots/RECEIPT.png)



---

**Layer 7 — SLO script validation**

To validate the monitoring logic, an error was intentionally simulated in the app logs. The SLO script detected the spike and produced a report showing the error rate and status. The output is saved in:

- [monitoring_summary_staging.txt](monitoring_summary_staging.txt)

We opted for this option but in production we would definitely go with prometheus alerts.THe disadavantage of prometheus is its heavyweight for a free tier AWS account.

---

**Production Gaps**


| Gap | Why it matters |
|---|---|
| Public subnets, no NAT | EKS nodes are directly internet-exposed. Production needs private subnets + NAT gateways + tight security groups.I opted not to use for NAT gateways due to its high cost which was incomaptible wit the free tier |
| No autoscaling | Neither pods (HPA) nor nodes (Cluster Autoscaler) scale up under load. One traffic spike can take the service down |
| LoadBalancer with no TLS | All traffic is unencrypted HTTP. Production needs an Ingress controller, ACM certificate, and HTTPS routing |


