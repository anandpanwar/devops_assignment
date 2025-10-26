# NPHC DevOps Engineer Assignment

This repo contains my submission for the NPHC DevOps Engineer assignment.  
I split it into two main parts — one for AWS (Scenario 1) and one for Kubernetes (Scenario 2).

---

## 🚀 Scenario 1 – AWS Infra + Terraform + GitLab CI/CD

### What I did
For this part, I used Terraform to set up the whole infrastructure on AWS.  
It provisions:
- Application Load Balancer (public)
- Auto Scaling Group with 3 EC2 instances (Amazon Linux 2)
- Private S3 bucket that holds the website files
- IAM roles and policies so EC2 can pull the files from S3
- Proper security groups (only allow port 80 inbound)
- A VPC endpoint for S3 (so the instances can access it even in private subnet)

The EC2 instances install nginx automatically through the user_data script and then sync the website content from the S3 bucket.

The load balancer serves the site publicly over port 80.  
I used `ap-southeast-1` (Singapore) region for all resources.

---

### CI/CD setup
I created a GitLab pipeline with two jobs:

1. **build-uppercase** – takes the existing HTML site and uppercases all text using a simple awk command  
2. **deploy** – uploads the changed files to the private S3 bucket and triggers an EC2 instance refresh in the ASG

That way, every time the code changes on main, the ASG refreshes itself and new instances pull the updated content.

---

### Files for Scenario 1

| File | Description |
|------|--------------|
| `scenario1/main.tf` | All AWS infra resources |
| `scenario1/userdata.sh` | installs nginx & syncs from S3 |
| `scenario1/outputs.tf` | shows ALB DNS, bucket name, etc. |
| `scenario01/.gitlab-ci.yml` | pipeline definition |
| `scenario01/website-src/` | small HTML + JS counter app |

---

### How to test

1. Run `terraform init && terraform apply`
2. After deployment, note the ALB DNS name from the output.
3. Visit `http://<alb_dns>` → you should see the counter page.
4. Push code to GitLab → the pipeline runs and uppercases all the text.
5. Wait a few mins for the ASG to refresh → refresh browser → uppercase version appears.

---

### Required GitLab CI Variables

| Variable | Example | Notes |
|-----------|----------|------|
| `AWS_ACCESS_KEY_ID` | (your key) | Needs S3 + EC2 perms |
| `AWS_SECRET_ACCESS_KEY` | (your secret) |  |
| `AWS_DEFAULT_REGION` | `ap-southeast-1` |  |
| `S3_BUCKET` | your bucket name from terraform output |  |
| `ASG_NAME` | autoscaling group name from output |  |

---

### Screenshots (in `docs/screenshots/`)
- `original_webpage.png` → before CI runs  
- `uppercase_webpage.png` → after CI pipeline deployment  

---

## ☸️ Scenario 2 – Kubernetes + Prometheus + Grafana

For the Kubernetes part I dockerized the same counter app and deployed it with a simple Deployment and Service.

I also added a PostgreSQL pod (the app doesn’t use it yet but can connect to it inside the cluster).

Then I set up Prometheus + Grafana using the `kube-prometheus-stack` Helm chart to monitor both the app and database resources.

---

### What’s included

| File | Description |
|------|--------------|
| `scenario2/Dockerfile` | nginx image with static site |
| `scenario2/k8s/deployment.yaml` | app deployment (2 replicas) |
| `scenario2/k8s/service.yaml` | exposes the app on NodePort |
| `scenario2/k8s/postgres.yaml` | postgres deployment + svc |
| `scenario2/k8s/configmap.yaml` | injects FIRST_NAME env var |
| `scenario2/deploy-local.sh` | bash script to deploy to local cluster |
| `scenario2/k8s/prometheus-grafana-values.yaml` | basic Helm values |

---

### How to run locally

1. Build docker image  
   ```bash
   docker build -t registry.gitlab.com/<your-username>/nphc-site:latest scenario2/

---

### Improvements Areas

After doing this assignment I realized a few things I could’ve done better or made cleaner.

- I’d definitely add HTTPS using ACM instead of leaving the ALB on plain HTTP.  
- The Terraform code works but it’s kinda messy in one file — I’d split it into modules next time.  
- The GitLab pipeline does the job, but I’d like to add a step to validate Terraform and maybe tag versions of the site before pushing to S3.  
- The EC2 setup is fine for demo, but honestly this static site could just live on S3 + CloudFront (no need for servers).  
- For the Kubernetes part, I’d switch to using an Ingress controller instead of NodePort and use Helm to manage manifests properly.  
- I also didn’t set up real Prometheus scraping for nginx — I’d add that plus Grafana dashboards later.  
- And yeah, better logging and cost optimization (like spot instances) would help too.

Overall it works, but it’s more of a proof of concept than production ready.  
If I had more time, I’d focus on making it more secure, automated, and cleaner to maintain.
