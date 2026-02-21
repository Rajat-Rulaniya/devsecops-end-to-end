# DevSecOps End-to-End Pipeline

![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white)
![SonarQube](https://img.shields.io/badge/SonarQube-4E9BCD?style=for-the-badge&logo=sonarqube&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=for-the-badge&logo=aquasecurity&logoColor=white)
![ArgoCD](https://img.shields.io/badge/Argo_CD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)
![Slack](https://img.shields.io/badge/Slack-4A154B?style=for-the-badge&logo=slack&logoColor=white)

Production-grade DevSecOps pipeline for a 3-tier web application. Integrates **security scanning at every stage** — secret detection (GitLeaks), static analysis (SonarQube), filesystem & container image vulnerability scanning (Trivy) — with automated Docker builds, GitOps-based Kubernetes deployments via Argo CD, and full AWS EKS infrastructure provisioned through Terraform.

---

## Table of Contents

- [Pipeline Overview](#pipeline-overview)
- [How It Works — Developer Workflow](#how-it-works--developer-workflow)
- [CI Pipeline Stages](#ci-pipeline-stages)
- [GitOps — Continuous Delivery](#gitops--continuous-delivery)
- [Security Scanning Stack](#security-scanning-stack)
- [AWS Infrastructure (Terraform)](#aws-infrastructure-terraform)
  - [VPC Module](#vpc-module)
  - [EKS Module](#eks-module)
  - [Customization Module](#customization-module)
- [Kubernetes Manifests](#kubernetes-manifests)
- [Application Architecture](#application-architecture)
- [Docker Setup](#docker-setup)
- [Slack Notifications](#slack-notifications)
- [Project Structure](#project-structure)
- [Tools & Technologies](#tools--technologies)

---

## Pipeline Overview

The project implements a complete **DevSecOps lifecycle** from code commit to production deployment:

1. **Code** → Push to `main` triggers Jenkins CI pipeline
2. **Validate** → Syntax checks for frontend (React) and backend (Node.js)
3. **Scan** → GitLeaks (secrets), SonarQube (SAST + Quality Gate), Trivy (filesystem vulnerabilities)
4. **Build** → Docker images built, tagged with build number, scanned by Trivy before push
5. **Push** → Images pushed to Docker Hub (`rajatrulaniya/devsecops-backend`, `rajatrulaniya/devsecops-frontend`)
6. **Update** → Image tags updated in a separate GitOps manifest repo via SSH
7. **Deploy** → Argo CD watches the GitOps repo and syncs changes to EKS cluster
8. **Notify** → Slack webhook sends rich build status notifications

---

## How It Works — Developer Workflow

A developer fixes a bug in the backend API. Here's exactly what happens from code change to production:

**1. Push** — Developer commits the fix and pushes to the `main` branch. This triggers the Jenkins CI pipeline automatically.

**2. Validate** — Jenkins checks out the code and runs syntax validation (`node --check`) on all JavaScript files in both `client/` and `api/` to catch errors early.

**3. Secret Scan** — GitLeaks scans the entire codebase for accidentally committed secrets, API keys, or tokens. The pipeline fails immediately if anything is found.

**4. Code Quality** — SonarQube performs static application security testing (SAST) and code quality analysis. The pipeline waits for the Quality Gate result before proceeding.

**5. Dependency Scan** — Trivy scans the filesystem for known CVEs in npm dependencies and generates an HTML report archived in Jenkins.

**6. Build & Scan Images** — Docker builds two images — `devsecops-backend:v1-build-42` and `devsecops-frontend:v1-build-42`. Before pushing, Trivy scans each image for OS-level and application-level vulnerabilities. Both scan reports are archived.

**7. Push to Registry** — Both images are pushed to Docker Hub with the versioned tag and a `latest` tag.

**8. Update GitOps Repo** — Jenkins clones the separate [`k8s-gitops-manifests`](https://github.com/Rajat-Rulaniya/k8s-gitops-manifests) repo via SSH, uses `sed` to update the image tags in `backend.yaml` and `frontend.yaml` to `v1-build-42`, commits as `jenkins-ci`, and pushes.

**9. Argo CD Syncs** — Argo CD (running on the EKS cluster) detects the new commit in the GitOps repo. It syncs the updated manifests to the `prod` namespace, triggering a rolling update — new pods come up with the `v1-build-42` images while old pods gracefully terminate.

**10. Live** — Within seconds, `devsecops.rajatrulaniya.com` serves the updated code. Nginx Ingress routes `/api/*` to the backend and `/*` to the frontend, with TLS certificates automatically managed by cert-manager and Let's Encrypt.

**11. Notify** — Slack receives a rich notification with the build status, job name, build number, and a direct link to Jenkins.

> **Zero manual steps.** The developer only pushes code — everything from security scanning to production deployment is fully automated.

---

## CI Pipeline Stages

The Jenkins CI pipeline (`Jenkinsfile_CI`) executes **11 stages** with security integrated at multiple layers:

| # | Stage | Tool | Purpose |
|---|-------|------|---------|
| 1 | **Checkout** | Git | Clone source from `main` branch |
| 2 | **Frontend Syntax Validation** | Node.js | `node --check` on all `.js` files in `client/` |
| 3 | **Backend Syntax Validation** | Node.js | `node --check` on all `.js` files in `api/` |
| 4 | **GitLeaks Scan** | GitLeaks | Scans `client/` and `api/` for hardcoded secrets, tokens, API keys |
| 5 | **SonarQube Analysis** | SonarQube + sonar-scanner | Static Application Security Testing (SAST) and code quality analysis |
| 6 | **Quality Gate Check** | SonarQube | Enforces quality gate — waits up to 1 hour for results |
| 7 | **Trivy FS Scan** | Trivy | Scans entire filesystem for known vulnerabilities; generates HTML report |
| 8 | **Build & Push Backend Image** | Docker + Trivy | Builds `devsecops-backend`, scans image with Trivy, pushes to Docker Hub |
| 9 | **Build & Push Frontend Image** | Docker + Trivy | Builds `devsecops-frontend`, scans image with Trivy, pushes to Docker Hub |
| 10 | **Update K8s Manifest Image Tag** | Git (SSH) | Clones GitOps repo, updates image tags via `sed`, commits and pushes |
| 11 | **Post-build Notifications** | Slack Webhook | Sends success/failure notifications with build details and direct links |

### Docker Image Tagging Strategy

Each build produces two tags per image:
- **Versioned**: `v1-build-<BUILD_NUMBER>` — immutable, tracks every build
- **Latest**: `latest` — rolling tag for convenience

Both tags are scanned with Trivy **before** being pushed to Docker Hub.

---

## GitOps — Continuous Delivery

The CI pipeline does **not** deploy directly to the cluster. Instead, it follows the **GitOps pattern**:

1. Jenkins clones a separate repository — [`k8s-gitops-manifests`](https://github.com/Rajat-Rulaniya/k8s-gitops-manifests)
2. Uses `sed` to update image tags in `backend.yaml` and `frontend.yaml` with the new build number
3. Commits as `jenkins-ci` and pushes to `main`
4. **Argo CD** (deployed on the EKS cluster via Terraform/Helm) detects the change and syncs the updated manifests to the `prod` namespace

This separation of concerns ensures:
- **Audit trail** — every deployment is a Git commit
- **Rollbacks** — revert a deployment by reverting a commit
- **Separation of CI and CD** — the CI pipeline never needs direct cluster access

---

## Security Scanning Stack

| Tool | Scan Type | What It Catches | Report |
|------|-----------|-----------------|--------|
| **GitLeaks** | Secret Detection | API keys, tokens, passwords, private keys committed to source | Console output (exit code 1 on findings) |
| **SonarQube** | SAST + Code Quality | Bugs, code smells, security hotspots, duplications, coverage | SonarQube dashboard + Quality Gate |
| **Trivy (FS)** | Filesystem Vulnerability Scan | Known CVEs in project dependencies (npm packages) | `trivy-fs-report.html` archived in Jenkins |
| **Trivy (Image)** | Container Image Scan | OS-level and app-level CVEs in Docker images | `trivy-backend-image-report.html`, `trivy-frontend-image-report.html` |

All HTML reports are **archived as Jenkins build artifacts** for traceability and audit purposes.

---

## AWS Infrastructure (Terraform)

The entire EKS cluster and supporting AWS infrastructure is provisioned using Terraform with a **modular architecture** (`eks/` directory):

```
eks/
├── main.tf              # Orchestrates VPC → EKS → Customization modules
├── variables.tf         # Cluster config (region, CIDRs, node groups, K8s version)
├── outputs.tf           # Exposes cluster endpoint, name, VPC ID
├── provider.tf          # AWS + Kubernetes + Helm providers
├── data.tf              # EKS cluster data sources + TLS certificate
└── modules/
    ├── vpc/             # VPC, subnets, NAT, IGW, route tables
    ├── eks/             # EKS cluster, IAM roles, managed node groups
    └── customization/   # OIDC, IRSA, Helm charts (ALB, EBS CSI, Ingress, Cert-Manager, Argo CD)
```

### VPC Module

Creates a production-ready VPC with:

| Resource | Details |
|----------|---------|
| **VPC** | `172.0.0.0/16` with DNS hostnames + DNS support enabled |
| **Public Subnets** | 3 subnets across `us-east-1a`, `1b`, `1c` — tagged for ELB |
| **Private Subnets** | 3 subnets across 3 AZs — tagged for internal ELB; EKS nodes run here |
| **Internet Gateway** | Attached to VPC for public subnet internet access |
| **NAT Gateway** | Single NAT in public subnet — allows private subnet outbound traffic |
| **Route Tables** | Separate public (→ IGW) and private (→ NAT) route tables with associations |

### EKS Module

| Resource | Details |
|----------|---------|
| **EKS Cluster** | Kubernetes `v1.33`, deployed in private subnets |
| **Cluster IAM Role** | `AmazonEKSClusterPolicy` attached |
| **Worker Node IAM Role** | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |
| **Managed Node Group** | `t3.medium` ON_DEMAND instances; scaling: min 2 → desired 3 → max 5 |

### Customization Module

After the EKS cluster is created, this module configures it with essential add-ons:

| Component | Method | Purpose |
|-----------|--------|---------|
| **OIDC Provider** | `aws_iam_openid_connect_provider` | Enables IAM Roles for Service Accounts (IRSA) |
| **AWS Load Balancer Controller** | Helm chart + IRSA | Provisions ALBs/NLBs for Kubernetes Services and Ingress |
| **AWS EBS CSI Driver** | Helm chart + IRSA | Enables dynamic EBS volume provisioning for StatefulSets |
| **Nginx Ingress Controller** | Helm chart | Internet-facing ingress with AWS LB annotation |
| **cert-manager** | Helm chart (OCI) | Automated TLS certificate management via Let's Encrypt |
| **Argo CD** | Helm chart | GitOps continuous delivery — watches manifest repo for changes |

IRSA (IAM Roles for Service Accounts) is configured using the [`terraform-aws-modules/iam`](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest) module, with dedicated service accounts for the ALB controller and EBS CSI driver.

---

## Kubernetes Manifests

All manifests deploy to the `prod` namespace:

| Manifest | Kind | Details |
|----------|------|---------|
| **backend.yaml** | Secret + ConfigMap + Deployment + Service | 3 replicas, ClusterIP on port 5000, env from Secret/ConfigMap, resource limits (500m CPU, 512Mi) |
| **frontend.yaml** | Deployment + Service | 3 replicas, ClusterIP on port 80, resource limits (200m CPU, 256Mi) |
| **mysql.yaml** | Service + ConfigMap + Secret + StatefulSet | Single replica StatefulSet, 5Gi PVC on `ebs-sc` StorageClass, init SQL via ConfigMap |
| **sc.yaml** | StorageClass | `ebs-sc` — AWS EBS CSI `gp3` volumes, `Retain` reclaim policy, `WaitForFirstConsumer` binding |
| **ingress.yaml** | Ingress | Nginx Ingress class, host-based routing (`devsecops.rajatrulaniya.com`), TLS via cert-manager |
| **clusterIssuer.yaml** | ClusterIssuer | Let's Encrypt production ACME server, HTTP-01 challenge via Nginx ingress |

### Ingress Routing

```
devsecops.rajatrulaniya.com
├── /api/*  → backend-svc:5000
└── /*      → frontend-svc:80
```

TLS is automated — cert-manager obtains and renews Let's Encrypt certificates using the `letsencrypt-prod` ClusterIssuer.

---

## Application Architecture

A **3-tier web application** containerized for Kubernetes:

| Tier | Technology | Container |
|------|-----------|-----------|
| **Frontend** | React 19, React Router v7, Axios, Chart.js | Multi-stage Docker build → Nginx Alpine serving static SPA |
| **Backend** | Node.js 23, Express, JWT auth, bcrypt | Alpine-based, `npm ci --only=production` |
| **Database** | MySQL 8 | Official image, initialized via SQL ConfigMap |

### Backend API Endpoints

| Method | Route | Auth | Access |
|--------|-------|------|--------|
| `POST` | `/api/auth/register` | None | Public |
| `POST` | `/api/auth/login` | None | Public |
| `GET` | `/api/users` | JWT | Viewer + Admin |
| `POST` | `/api/users` | JWT | Viewer + Admin |
| `PUT` | `/api/users/:id` | JWT | Admin only |
| `DELETE` | `/api/users/:id` | JWT | Admin only |

### Nginx Reverse Proxy

Two configs handle routing depending on the environment:

| Config | Environment | Backend Upstream |
|--------|-------------|------------------|
| `nginx.conf` | Docker Compose (local dev) | `backend:5000` (Docker network) |
| `default.conf` | Kubernetes (production) | `backend-svc:5000` (K8s Service DNS) |

The production config includes `1y` cache headers for static assets and SPA fallback (`try_files $uri /index.html`).

---

## Docker Setup

### Frontend — Multi-stage Build
```dockerfile
# Stage 1: Build React app
FROM node:23-alpine AS builder
RUN npm ci && npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf
```

### Backend
```dockerfile
FROM node:23-alpine
RUN npm ci --only=production
EXPOSE 5000
CMD ["node", "app.js"]
```

### Docker Compose (Local Development)

`docker-compose.yaml` brings up all 3 services locally:

| Service | Image | Port |
|---------|-------|------|
| mysql | mysql:8 | 3306 |
| backend | rajatrulaniya/devsecops-backend | 5000 |
| frontend | rajatrulaniya/devsecops-frontend | 80 → host 80 |

MySQL data persists via a named volume, and the schema is initialized from `mysql-init/init.sql`.

---

## Slack Notifications

The pipeline sends **rich Slack notifications** via incoming webhook on both success and failure:

- **Success** — green attachment with job name, build number, environment, and a "View Build" button linking to Jenkins
- **Failure** — red attachment with `@here` mention and a "View Build Logs" button
- Both include Jenkins footer icon and timestamp

---

## Project Structure

```
devsecops-end-to-end/
├── Jenkinsfile_CI               # 11-stage DevSecOps CI pipeline
├── docker-compose.yaml          # Local development (3 services)
│
├── api/                         # Node.js Express backend
│   ├── Dockerfile
│   ├── app.js                   # Entry point — Express server with DB retry logic
│   ├── controllers/             # Auth (register/login) + CRUD controllers
│   ├── middleware/               # JWT verification + role-based access (admin/viewer)
│   ├── models/                  # MySQL connection pool (mysql2)
│   └── routes/                  # Auth routes + user CRUD routes
│
├── client/                      # React 19 frontend
│   ├── Dockerfile               # Multi-stage: Node build → Nginx serve
│   ├── nginx.conf               # Reverse proxy config (Docker Compose)
│   ├── default.conf             # Reverse proxy config (Kubernetes)
│   └── src/
│       ├── components/          # Layout, UserForm, AnimatedBanner, InfoPopup
│       └── pages/               # Dashboard, Login, Register, UserDashboard
│
├── mysql-init/
│   └── init.sql                 # DB schema — users table with RBAC fields
│
├── eks/                         # Terraform — AWS EKS infrastructure
│   ├── main.tf                  # Module orchestration (VPC → EKS → Customization)
│   ├── variables.tf             # Cluster config (region, subnets, node groups)
│   ├── provider.tf              # AWS + Kubernetes + Helm providers
│   └── modules/
│       ├── vpc/                 # VPC, 6 subnets (3 public + 3 private), NAT, IGW
│       ├── eks/                 # EKS cluster, IAM roles, managed node groups
│       └── customization/       # OIDC/IRSA, ALB Controller, EBS CSI, Ingress, cert-manager, Argo CD
│
└── k8s-manifests/               # Kubernetes deployment manifests
    ├── backend.yaml             # Secret + ConfigMap + Deployment (3 replicas) + ClusterIP Service
    ├── frontend.yaml            # Deployment (3 replicas) + ClusterIP Service
    ├── mysql.yaml               # StatefulSet + PVC (5Gi EBS gp3) + init SQL ConfigMap
    ├── sc.yaml                  # StorageClass — AWS EBS CSI gp3
    ├── ingress.yaml             # Nginx Ingress with TLS (cert-manager + Let's Encrypt)
    └── clusterIssuer.yaml       # Let's Encrypt ACME ClusterIssuer
```

---

## Tools & Technologies

| Category | Tools |
|----------|-------|
| **CI/CD** | Jenkins (Declarative Pipeline), Argo CD (GitOps) |
| **Security** | GitLeaks (secret scanning), SonarQube (SAST), Trivy (FS + image vulnerability scanning) |
| **Containerization** | Docker (multi-stage builds), Docker Hub |
| **Orchestration** | Kubernetes (EKS v1.33), Helm |
| **Infrastructure** | Terraform (modular), AWS (VPC, EKS, EBS, IAM, NAT Gateway) |
| **Kubernetes Add-ons** | Nginx Ingress Controller, cert-manager (Let's Encrypt TLS), AWS Load Balancer Controller, AWS EBS CSI Driver |
| **Notifications** | Slack (incoming webhook with rich attachments) |
| **Application** | React 19, Node.js 23, Express, MySQL 8, JWT, bcrypt |
| **IAM & Security** | IRSA (IAM Roles for Service Accounts), OIDC Provider, RBAC (admin/viewer roles) |
