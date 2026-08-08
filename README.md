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

### Service Wake-Up Rules

Scaling rules match the protocol used by each service:

| Service | Ingress | Wake-up rule |
| --- | --- | --- |
| Redis | Internal TCP `6379` | TCP concurrent connections |
| RabbitMQ | Internal TCP `5672` | TCP concurrent connections |
| Backend | Internal HTTP `8080` | HTTP concurrent requests |
| LLM Processor | Internal HTTP `8000` | HTTP concurrent requests |
| Frontend | External HTTP `80` | HTTP concurrent requests |
| Gateway | External HTTP `80` | HTTP concurrent requests |

TCP services use TCP scale rules so a connection can activate a zero-scaled revision. HTTP services use native HTTP scale rules. Applying TCP rules to every service would be incorrect because the application protocol and ingress transport must match.

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

## 🔐 GitHub Actions Configuration

Configure these secrets in your GitHub repository before deployment:

| Secret Name             | Description                              |
| ----------------------- | ---------------------------------------- |
| `AZURE_CLIENT_ID`       | Azure Service Principal client ID (OIDC) |
| `AZURE_TENANT_ID`       | Azure tenant ID (OIDC)                   |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID (OIDC)             |

GitHub Actions only supplies Azure OIDC credentials and the image-tag workflow inputs. It does not supply infrastructure configuration, application settings, registry credentials, or secret values.

## Production Configuration

Set the non-secret infrastructure and deployment values in the checked-in parameter files:

- `main.production.bicepparam`
- `cert-binding.production.bicepparam`

These files contain the production values for the Azure region, Key Vault, managed identity, registry, service names, SQL names, SQL network access, image defaults, gateway domain, certificate name, environment, and resource tags. GitHub Actions reads the Container Apps environment and gateway domain from `main.production.bicepparam`; it can override only image tags, the revision suffix, and certificate creation state for a particular deployment.

The current production registry username is `sziszka90`; update it in both parameter files if the registry account changes. The registry password remains in Key Vault as `registry-password`.

The configured Key Vault is `finance-app-key-vault` (`https://finance-app-key-vault.vault.azure.net/`). Bicep derives the vault URI from the existing Key Vault resource, so the URL is not passed as a separate parameter.

Service repositories own fixed non-secret application settings such as authentication issuer/audience, SMTP configuration, exchange-rate API URLs, RabbitMQ user and vhost, and MCP configuration. Those applications load the values from their packaged configuration; this infrastructure workflow does not pass them as environment variables.

The following versionless Key Vault secrets are read by Container Apps through the shared `finance-app-secrets` managed identity:

- `auth-secret-key`
- `cache-connection-string`
- `exchange-rate-api-app-id`
- `finance-app-db-connection-string`
- `llm-processor-api-token`
- `openai-api-key`
- `rabbitmq-password`
- `registry-password`
- `redis-password`
- `sql-admin-password`
- `sql-admin-login`
- `smtp-password`

Gateway routing values are not secrets and are not GitHub Actions inputs. The gateway receives `LLM_PROCESSOR_URL`, `BACKEND_URL`, and `FRONTEND_URL` from the `gatewayRoutingEnvironment` variable in the Bicep templates. Those values are derived from the deployed Container App FQDNs, so they stay correct across deployments without maintaining a separate `.env` file.

The GitHub Actions OIDC identity must be allowed to create role assignments on the Key Vault and must have the `Microsoft.KeyVault/vaults/deploy/action` permission on the Key Vault or resource group. **Contributor** or **Owner** includes this deployment action; a least-privilege custom role containing only this action is also suitable. The workflow enables Key Vault template deployment access and sets the required `AzureServices` network ACL bypass before running the Bicep deployment. The template separately grants the Container Apps identity the **Key Vault Secrets User** role for runtime secret reads. The SQL module reads `sql-admin-login` and `sql-admin-password` during deployment, while the Redis container reads `redis-password` at runtime.

The LLM Processor loads secrets directly with Azure Identity and Key Vault SDKs. Its Container App receives `KEY_VAULT_URI` and `AZURE_CLIENT_ID` from Bicep. `AZURE_CLIENT_ID` selects the `finance-app-secrets` user-assigned identity, while `KEY_VAULT_URI` points to `finance-app-key-vault`.

### SQL Network Access

`main.production.bicepparam` explicitly controls `sqlPublicNetworkAccess` and `allowAzureServicesToAccessSql`. The current deployment keeps public access enabled because the Container Apps environment is not VNet-integrated. Set both values to disable public access only after adding Container Apps VNet integration, a SQL private endpoint, and private DNS routing.

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
4. **Deploy Bicep Template** → Uses `az deployment group create` with the checked-in `.bicepparam` file
5. **Bind Certificate** → Creates the SSL binding after the certificate exists, whether it was newly created or already present
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
