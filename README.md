# End-to-End DevSecOps CI/CD Pipeline on AWS

A practical DevSecOps implementation that automates source control integration, code-quality analysis, vulnerability scanning, container image delivery, Kubernetes deployment, monitoring, and build notifications.

The pipeline was demonstrated using **AstroHunt** as its sample application. The workflow is designed around reusable DevOps practices and can be adapted to other containerized applications by changing the source repository, image names, build commands, and Kubernetes manifests.

> **Project emphasis:** secure and repeatable software delivery, not just running a Jenkins job. The pipeline connects GitHub, Jenkins, SonarQube, Trivy, Docker Hub, Amazon EKS, Prometheus, Grafana, and email notifications.

---

## Table of contents

- [Project goals](#project-goals)
- [Architecture](#architecture)
- [Technology stack](#technology-stack)
- [End-to-end pipeline](#end-to-end-pipeline)
- [Infrastructure design](#infrastructure-design)
- [Jenkins configuration](#jenkins-configuration)
- [Pipeline stages in detail](#pipeline-stages-in-detail)
- [Container image workflow](#container-image-workflow)
- [Amazon EKS deployment](#amazon-eks-deployment)
- [Demo evidence](#demo-evidence)

---

## Project goals

This project demonstrates how to build a delivery workflow that:

1. Starts automatically when code is pushed to GitHub.
2. Checks code quality with SonarQube.
3. Scans the source workspace and built container images with Trivy.
4. Builds and publishes Docker images to Docker Hub.
5. Deploys application workloads to Amazon EKS using Kubernetes manifests.
6. Collects Kubernetes and node metrics with Prometheus and visualizes them in Grafana.
7. Sends pipeline status notifications by email.
8. Uses infrastructure automation for the supporting AWS compute environment.

### What this project demonstrates

- CI/CD orchestration with Jenkins and GitHub webhooks.
- Static analysis and quality-gate integration.
- Filesystem and container-image vulnerability scanning.
- Docker image build, tagging, registry authentication, and publishing.
- Kubernetes Deployments, Services, replicas, and rollout verification.
- EKS access configuration and Jenkins-to-cluster authentication.
- Metrics collection and dashboards for cluster observability.
- Troubleshooting real deployment failures across Git, Docker, Jenkins, IAM, DNS, Kubernetes, and Nginx.

---

## Architecture

```mermaid
flowchart TD
    Dev[Developer] -->|git push| Git[GitHub Repository]
    Git -->|push webhook| Jenkins[Jenkins Pipeline]

    Jenkins --> Clean[Clean Workspace & Checkout]
    Clean --> Sonar[SonarQube Analysis]
    Sonar --> Gate[Quality Gate]
    Gate --> FS[Trivy Filesystem Scan]
    FS --> Build[Docker Build]
    Build --> Registry[Docker Hub]
    Registry --> ImageScan[Trivy Image Scan]
    ImageScan --> Deploy[Jenkins Deploy Stage]

    Deploy -->|kubectl apply| EKS[Amazon EKS]
    EKS --> Front[Frontend Deployment]
    EKS --> Back[Backend Deployment]
    Front --> LB[Frontend LoadBalancer Service]
    Back --> ClusterIP[Backend ClusterIP Service]

    EKS --> Prom[Prometheus]
    Prom --> Grafana[Grafana Dashboards]
    Jenkins --> Email[Email Notifications]
```

### Request path

- The frontend is served by Nginx on container port `80` and exposed using a Kubernetes `LoadBalancer` Service.
- The backend runs FastAPI/Uvicorn on container port `8000` and is exposed internally using a Kubernetes `ClusterIP` Service.
- Prometheus and Grafana run inside the EKS cluster in a dedicated `prometheus` namespace.
- Jenkins connects to EKS using a Kubernetes kubeconfig credential and an AWS identity authorized for the target cluster.

**Frontend/backend routing note:** Kubernetes DNS names such as `astrohunt-backend-service` are only resolvable inside the cluster. Browser JavaScript cannot call a ClusterIP service directly. A same-origin Nginx `/api` reverse proxy, Ingress, or another secured API entry point is needed for browser-to-backend traffic. The Nginx SPA fallback is for frontend routes and is not, by itself, an API reverse proxy.

---

## Technology stack

| Area | Technology | Purpose |
|---|---|---|
| Source control | Git, GitHub | Version control and source repository |
| Trigger | GitHub Webhooks | Notify Jenkins on repository pushes |
| CI/CD | Jenkins | Automate build, scan, publish, deploy, and notifications |
| Code quality | SonarQube | Static analysis and Quality Gate evaluation |
| Security scanning | Trivy | Filesystem and container-image scanning |
| Containers | Docker | Package application components into images |
| Image registry | Docker Hub | Store and distribute container images |
| Infrastructure as Code | Terraform | Provision supporting AWS infrastructure such as EC2 and security groups |
| Kubernetes provisioning | eksctl | Create and manage the EKS cluster used in the demonstration |
| Orchestration | Amazon EKS, Kubernetes | Run application workloads and Services |
| Metrics | Prometheus | Scrape and store metrics |
| Dashboards | Grafana | Visualize infrastructure and Kubernetes metrics |
| Cluster metrics | Node Exporter, kube-state-metrics | Expose node and Kubernetes object metrics |
| Notifications | Jenkins Email Extension / SMTP | Send build and deployment status emails |

**Provisioning distinction:** Terraform was used for the supporting EC2 environment. The demonstration EKS cluster was created with `eksctl`. The application workloads were deployed with Kubernetes YAML manifests. Do not describe the EKS cluster itself as Terraform-provisioned unless Terraform EKS resources are added to the infrastructure code.

---

## End-to-end pipeline

```text
Developer Push
      |
      v
GitHub Webhook
      |
      v
Jenkins Pipeline
      |
      +--> Clean Workspace
      |
      +--> Checkout Source
      |
      +--> SonarQube Analysis
      |
      +--> Quality Gate
      |
      +--> Trivy Filesystem Scan
      |
      +--> Docker Build & Push
      |
      +--> Trivy Image Scan
      |
      +--> Deploy to Amazon EKS
      |
      +--> Email Notification
```

The stages are intended to make feedback available throughout delivery: source quality and security checks happen before deployment, while deployment and rollout checks verify the Kubernetes release.

---

## Infrastructure design

### Supporting EC2 environment

An EC2 instance was used to host the CI tools, including Jenkins, SonarQube, Docker, and Trivy. A separate monitoring EC2 environment was also used during the project for monitoring-related services and access.

Terraform was used to automate supporting AWS infrastructure such as:

- EC2 instance provisioning.
- Security group configuration.
- Region and provider configuration.
- Instance bootstrap through a user-data installation script.

Example Terraform lifecycle:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Review the plan before applying it. Do not commit state files, private keys, access keys, or secret variables.

### Amazon EKS environment

The demonstration cluster was created with `eksctl`, using three `t2.small` worker nodes in `ap-south-1`:

```bash
eksctl create cluster \
  --name <cluster-name> \
  --region ap-south-1 \
  --node-type t2.small \
  --nodes 3
```

Configure the local or management-host kubeconfig:

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name <cluster-name>
```

Verify cluster connectivity:

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

The cluster name is intentionally shown as a placeholder. Use the name created in your own AWS account.

---

## Jenkins configuration

### Jenkins plugins and integrations

The Jenkins environment used these integrations (plugin names can vary slightly by plugin release):

- Pipeline
- Git and GitHub integration
- SonarQube Scanner for Jenkins
- Docker Pipeline / Docker-related pipeline support
- Kubernetes CLI (`kubeconfig` integration)
- Credentials Binding
- Email Extension
- Workspace Cleanup

Install plugins from **Manage Jenkins → Plugins** and restart Jenkins when the plugin installation requires it.

### Global tools

Configure the tools under **Manage Jenkins → Tools**:

- JDK installation used by the SonarQube analysis stage (the project used JDK 21).
- SonarQube Scanner installation.

### SonarQube server configuration

Under **Manage Jenkins → System → SonarQube installations**, configure a server entry such as:

- Name: `SonarQube-Server`
- Server URL: the reachable SonarQube URL from the Jenkins host
- Authentication: a SonarQube token stored in Jenkins Credentials

Do not place the token directly in the Jenkinsfile.

### Jenkins credentials

Create credentials in **Manage Jenkins → Credentials**. The pipeline used credential IDs similar to:

| Credential ID | Credential purpose | Recommended storage |
|---|---|---|
| `dockerhub` | Docker Hub login | Username/password credential with an access token as the password |
| `SonarQube-Token` | SonarQube authentication | Secret text |
| `kubernetes` | Kubeconfig for EKS deployment | Secret file |

The Jenkins host also needs an AWS IAM identity authorized to authenticate to the target EKS cluster. A kubeconfig file alone does not grant AWS permissions. When an EKS cluster is recreated, refresh the kubeconfig and update the Jenkins Secret file credential; keep the credential ID used by the pipeline consistent.

### GitHub webhook trigger

Configure the GitHub repository webhook to point to the Jenkins webhook endpoint:

```text
http://<jenkins-host>:8080/github-webhook/
```

In the Jenkins pipeline job, enable **GitHub hook trigger for GITScm polling**. Use HTTPS, a webhook secret, and restricted Jenkins access for a production deployment. A successful webhook delivery means GitHub reached Jenkins; verify that a new Jenkins build actually starts.

---

## Pipeline stages in detail

### 1. Clean Workspace

The pipeline removes stale files from the previous run so that a build uses a clean workspace.

Typical Jenkins step:

```groovy
cleanWs()
```

### 2. Checkout from Git

Jenkins checks out the configured GitHub repository and branch. This makes each pipeline run traceable to a repository revision.

### 3. SonarQube Analysis

The SonarQube Scanner analyzes the checked-out source code and uploads the analysis report to the configured SonarQube server.

The results can include:

- Bugs and reliability issues.
- Vulnerabilities and security hotspots.
- Code smells and maintainability issues.
- Duplication metrics.

Coverage results require a coverage report to be generated and supplied to SonarQube; running a scanner alone does not create test coverage.

### 4. Quality Gate

Jenkins waits for SonarQube's Quality Gate result. This provides a quality checkpoint before later stages.

**Policy note:** if the pipeline uses `waitForQualityGate(abortPipeline: false)`, an unsuccessful Quality Gate is reported but does not abort the pipeline. Set `abortPipeline: true` when the desired policy is to block subsequent stages on a failed gate.

### 5. Trivy Filesystem Scan

Trivy scans the source workspace for supported vulnerabilities, misconfigurations, secrets, and related findings depending on the scan options and configuration.

The pipeline can preserve the output as a report file for review and email attachment.

### 6. Docker Build and Push

The frontend and backend are built separately using their Dockerfiles and pushed to Docker Hub.

Images used by the Kubernetes manifests:

```text
<dockerhub-username>/astrohunt-frontend:latest
<dockerhub-username>/astrohunt-backend:latest
```

The pipeline authenticates using a Jenkins credential rather than a hard-coded token.

### 7. Trivy Image Scan

Trivy scans the built container images for operating-system and language-package vulnerabilities. The report can be retained as a build artifact or attached to the notification email.

**Policy note:** the demonstration pipeline used `--exit-code 0` for image scanning. This allows the stage to complete while reporting findings; it does not enforce a vulnerability-based deployment block. For stricter enforcement, define severity thresholds and a non-zero exit code after reviewing and tuning the policy.

### 8. Deploy to Kubernetes / Amazon EKS

Jenkins uses the Kubernetes kubeconfig credential and runs commands such as:

```bash
kubectl get nodes
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl get deployments
kubectl get pods -o wide
kubectl get services
```

The pipeline also checks application rollout status:

```bash
kubectl rollout status deployment/astrohunt-frontend --timeout=180s
kubectl rollout status deployment/astrohunt-backend --timeout=180s
```

### 9. Post-build actions and email

The post-build section uses Jenkins Email Extension to send build status notifications. The configured message can include the console log and Trivy reports.

Use an SMTP app password or dedicated mail credential stored in Jenkins Credentials. Never store an email password in the pipeline source.

---

## Container image workflow

Build commands should be run from the repository root so the Docker build context matches the `COPY` paths in the Dockerfiles.

### Frontend image

```bash
docker build \
  -f frontend/frontend/Dockerfile \
  -t <dockerhub-username>/astrohunt-frontend:<tag> \
  .
```

The frontend Dockerfile:

1. Uses Node.js to install dependencies and build the Vite application.
2. Copies the production build into an Nginx image.
3. Copies the custom Nginx configuration into the image.
4. Serves the static frontend on port `80`.

The Nginx configuration includes SPA fallback routing:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### Backend image

```bash
docker build \
  -f backend/backend/Dockerfile \
  -t <dockerhub-username>/astrohunt-backend:<tag> \
  .
```

The backend image uses Python 3.11, installs the packages in `backend/requirements.txt`, and starts the FastAPI application with Uvicorn on port `8000`.

### Recommended image tagging

The demonstration used the `latest` tag. For stronger traceability, publish an immutable tag as well, for example:

```text
astrohunt-frontend:<git-commit-sha>
astrohunt-backend:<git-commit-sha>
```

Update the Kubernetes deployment to reference that exact tag. This makes it easier to identify which source revision is running in the cluster.

---

## Amazon EKS deployment

The Kubernetes manifests are stored in the `Kubernetes/` directory.

### Deploy the application

From the repository root, after configuring access to the target EKS cluster:

```bash
kubectl apply -f Kubernetes/deployment.yml
kubectl apply -f Kubernetes/service.yml
```

### Workload layout

| Resource | Type | Replicas / Port |
|---|---|---|
| `astrohunt-frontend` | Deployment | 2 replicas, container port 80 |
| `astrohunt-backend` | Deployment | 2 replicas, container port 8000 |
| `astrohunt-frontend-service` | LoadBalancer Service | External port 80 → target port 80 |
| `astrohunt-backend-service` | ClusterIP Service | Internal port 8000 → target port 8000 |

### Verify the deployment

```bash
kubectl get nodes -o wide
kubectl get deployments
kubectl get pods -o wide
kubectl get services
kubectl get endpoints
```

Wait for the frontend AWS LoadBalancer hostname:

```bash
kubectl get svc astrohunt-frontend-service --watch
```

Retrieve the hostname:

```bash
kubectl get svc astrohunt-frontend-service \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the resulting hostname using HTTP for the demonstration. The DNS name can change when the Service or cluster is recreated.

### Backend connectivity check

The backend Service is internal to the cluster. A temporary curl pod can test Kubernetes DNS and the FastAPI docs route:

```bash
kubectl run backend-test \
  --rm -i \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -i http://astrohunt-backend-service:8000/docs
```

A `200 OK` response indicates that the in-cluster request reached FastAPI and returned the docs page.

---

## Demo evidence

Add links to the recorded walkthrough and screenshots when they are published:

- **Project demo video:** _Add YouTube link_

---

## Acknowledgements

Built as a hands-on project to practise cloud infrastructure, CI/CD automation, software supply-chain security, containerization, Kubernetes orchestration, and observability.
