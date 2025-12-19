# 🏗️ Finance App - Azure Infrastructure

## ☁️ Bicep Infrastructure-as-Code for deploying containerized microservices to Azure Container Apps

This repository contains the infrastructure-as-code for deploying the complete Finance App microservices architecture to Azure. The infrastructure is written in Bicep, providing a clean, maintainable, and type-safe deployment experience with proper secret management and CI/CD integration via GitHub Actions.

## 🎯 What Gets Deployed

When you deploy this template, Azure will create the following resources:

### **Core Infrastructure**

- **1 Log Analytics Workspace** - Centralized logging for all container apps
- **1 Container Apps Environment** - Managed environment for all microservices

### **Microservices (6 Container Apps)**

1. **Backend** - Main API service (.NET)

2. **Frontend** - Web UI

3. **LLM Processor** - AI/ML processing service

4. **Gateway** - API Gateway/Reverse Proxy

5. **RabbitMQ** - Message queue

6. **Redis (Cache)** - In-memory cache

### **Database**

- **1 Azure SQL Server** - Auto-named with unique suffix
- **1 SQL Database** - `FinanceAppDB`
  - SKU: GP_S_Gen5 (General Purpose Serverless)
  - 2 vCores, 0.5 min capacity
  - 32 GB max size
  - Free limit enabled
  - Auto-pause after 60 minutes of inactivity

## **Multi-Repo Architecture**

This infrastructure repo is designed to work with separate service repositories:

- **Backend repo** - Builds and publishes backend container image
- **Frontend repo** - Builds and publishes frontend container image
- **LLM Processor repo** - Builds and publishes LLM processor container image
- **Gateway repo** - Builds and publishes gateway container image
- **Infrastructure repo** (this repo) - Deploys infrastructure with specified image tags

Each service repo builds and tags images independently. This infrastructure deployment workflow accepts image tags as inputs to deploy specific versions.

## 🔐 GitHub Secrets Required

Configure these secrets in your GitHub repository before deployment:

| Secret Name                | Description                              |
| -------------------------- | ---------------------------------------- |
| `AZURE_CLIENT_ID`          | Azure Service Principal client ID (OIDC) |
| `AZURE_TENANT_ID`          | Azure tenant ID (OIDC)                   |
| `AZURE_SUBSCRIPTION_ID`    | Azure subscription ID (OIDC)             |
| `SQL_ADMIN_LOGIN`          | SQL Server administrator username        |
| `SQL_ADMIN_PASSWORD`       | SQL Server administrator password        |
| `GHCR_USERNAME`            | GitHub Container Registry username       |
| `GHCR_TOKEN`               | GitHub Personal Access Token             |
| `OPENAI_API_KEY`           | OpenAI API key                           |
| `AUTH_SECRET_KEY`          | JWT authentication secret                |
| `SMTP_USER`                | SMTP username                            |
| `SMTP_PASSWORD`            | SMTP password                            |
| `SMTP_FROM_EMAIL`          | Email sender address                     |
| `EXCHANGE_RATE_API_APP_ID` | Exchange rate API app ID                 |
| `RABBITMQ_USERNAME`        | RabbitMQ username                        |
| `RABBITMQ_PASSWORD`        | RabbitMQ password                        |
| `REDIS_PASSWORD`           | Redis password                           |
| `LLM_PROCESSOR_API_TOKEN`  | LLM Processor API token                  |

## 🚀 Deployment

### **Deploy via GitHub Actions**

1. Go to **Actions** → **Deploy Infrastructure**
2. Click **Run workflow**
3. Specify image tags (or use defaults):
   - Backend image tag (default: `latest`)
   - Frontend image tag (default: `latest`)
   - LLM Processor image tag (default: `latest`)
   - Gateway image tag (default: `latest`)
4. Click **Run workflow**

**Deployment Flow:**

1. **Push to main** or **Manual trigger** → Triggers GitHub Actions workflow
2. **Authenticate** → Uses OIDC authentication with Azure
3. **Check Certificate** → Verifies if SSL certificate exists
4. **Deploy Bicep Template** → Provisions all Azure resources
5. **Bind Certificate** (if needed) → Configures SSL for custom domain
6. **Output URLs** → Returns service endpoints for verification

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/infrastructure-improvement`)
3. Commit your changes (`git commit -m 'Add infrastructure improvement'`)
4. Push to the branch (`git push origin feature/infrastructure-improvement`)
5. Open a Pull Request

## 👤 Author

**Szilard Ferencz**  
🌐 [szilardferencz.dev](https://www.szilardferencz.dev)  
💼 [LinkedIn](https://www.linkedin.com/in/szilard-ferencz/)  
🐙 [GitHub](https://github.com/Sziszka90)

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

⭐ **Star this repo if you find it helpful!** ⭐
