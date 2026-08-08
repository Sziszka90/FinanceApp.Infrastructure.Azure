using 'main.bicep'

// Production infrastructure configuration.
param location = 'polandcentral'
param keyVaultName = 'finance-app-key-vault'
param keyVaultIdentityName = 'finance-app-secrets'
param containerRegistryServer = 'ghcr.io'
param containerRegistryUsername = 'sziszka90'
param rabbitMqUsername = 'admin'
param backendImageTag = 'latest'
param frontendImageTag = 'latest'
param llmProcessorImageTag = 'latest'
param gatewayImageTag = 'latest'
param gatewayCustomDomain = 'www.financeapp.fun'
param certificateName = 'www.financeapp.fun'
param createGatewayCertificate = false
param resourcePrefix = 'finance-app'
param managedEnvironmentName = 'FinanceApp'
param sqlServerName = 'projects-server-sziszka90'
param sqlDatabaseName = 'FinanceAppDB'
// Current Container Apps networking requires the public SQL endpoint. Set both
// values to disable public access only after private endpoint routing is deployed.
param sqlPublicNetworkAccess = 'Enabled'
param allowAzureServicesToAccessSql = true
param serviceNames = {
  cache: 'finance-app-cache'
  rabbitMq: 'finance-app-rabbitmq'
  llmProcessor: 'finance-app-llmprocessor'
  backend: 'finance-app-backend'
  frontend: 'finance-app-frontend'
  gateway: 'finance-app-gateway'
}
param projectName = 'FinanceApp'
param managedBy = 'Bicep-Template'
param costCenter = 'Finance'
param environment = 'production'
