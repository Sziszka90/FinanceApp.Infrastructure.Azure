// FinanceApp infrastructure orchestrator. Service definitions live in individual modules.

type ServiceNames = {
  cache: string
  rabbitMq: string
  llmProcessor: string
  backend: string
  frontend: string
  gateway: string
}

param location string
param keyVaultName string
param keyVaultIdentityName string
param containerRegistryServer string
param containerRegistryUsername string
param rabbitMqUsername string
param revisionSuffix string = utcNow('yyyyMMddHHmmss')
param backendImageTag string
param frontendImageTag string
param llmProcessorImageTag string
param gatewayImageTag string
param gatewayCustomDomain string
param certificateName string
param createGatewayCertificate bool
param resourcePrefix string
param managedEnvironmentName string
param sqlServerName string
param sqlDatabaseName string

@allowed([
  'Enabled'
  'Disabled'
])
param sqlPublicNetworkAccess string

param allowAzureServicesToAccessSql bool
param serviceNames ServiceNames
param projectName string
param managedBy string
param costCenter string

@allowed([
  'development'
  'staging'
  'production'
])
param environment string

var tags = {
  Environment: environment
  Project: projectName
  ManagedBy: managedBy
  CostCenter: costCenter
}
var keyVaultSecretsUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource secretsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: keyVaultIdentityName
  location: location
  tags: tags
}

resource keyVaultSecretsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, secretsIdentity.id, keyVaultSecretsUserRoleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinitionId
    principalId: secretsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${resourcePrefix}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      legacy: 0
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: managedEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }
}

module sqlInfrastructure './modules/sql.bicep' = {
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlPublicNetworkAccess: sqlPublicNetworkAccess
    allowAzureServicesToAccessSql: allowAzureServicesToAccessSql
    sqlAdministratorLogin: keyVault.getSecret('sql-admin-login')
    sqlAdministratorPassword: keyVault.getSecret('sql-admin-password')
  }
}

var secretUrls = {
  authSecretKey: '${keyVault.properties.vaultUri}secrets/auth-secret-key'
  cacheConnectionString: '${keyVault.properties.vaultUri}secrets/cache-connection-string'
  exchangeRateApiAppId: '${keyVault.properties.vaultUri}secrets/exchange-rate-api-app-id'
  financeAppDbConnectionString: '${keyVault.properties.vaultUri}secrets/finance-app-db-connection-string'
  llmProcessorApiToken: '${keyVault.properties.vaultUri}secrets/llm-processor-api-token'
  openAiApiKey: '${keyVault.properties.vaultUri}secrets/openai-api-key'
  rabbitMqPassword: '${keyVault.properties.vaultUri}secrets/rabbitmq-password'
  registryPassword: '${keyVault.properties.vaultUri}secrets/registry-password'
  redisPassword: '${keyVault.properties.vaultUri}secrets/redis-password'
  smtpPassword: '${keyVault.properties.vaultUri}secrets/smtp-password'
}

module cache './modules/cache.bicep' = {
  dependsOn: [
    keyVaultSecretsRoleAssignment
  ]
  params: {
    location: location
    name: serviceNames.cache
    managedEnvironmentId: managedEnvironment.id
    identityId: secretsIdentity.id
    redisCredentialUri: secretUrls.redisPassword
    revisionSuffix: revisionSuffix
    tags: union(tags, {
      Component: 'Cache'
      Service: serviceNames.cache
    })
  }
}

module rabbitMq './modules/rabbitmq.bicep' = {
  dependsOn: [
    keyVaultSecretsRoleAssignment
  ]
  params: {
    location: location
    name: serviceNames.rabbitMq
    managedEnvironmentId: managedEnvironment.id
    identityId: secretsIdentity.id
    rabbitMqCredentialUri: secretUrls.rabbitMqPassword
    rabbitMqUsername: rabbitMqUsername
    revisionSuffix: revisionSuffix
    tags: union(tags, {
      Component: 'Messaging'
      Service: serviceNames.rabbitMq
    })
  }
}

module llmProcessor './modules/llm-processor.bicep' = {
  dependsOn: [
    keyVaultSecretsRoleAssignment
  ]
  params: {
    location: location
    name: serviceNames.llmProcessor
    managedEnvironmentId: managedEnvironment.id
    identityId: secretsIdentity.id
    registryServer: containerRegistryServer
    registryUsername: containerRegistryUsername
    imageTag: llmProcessorImageTag
    revisionSuffix: revisionSuffix
    rabbitMqHost: rabbitMq.outputs.fqdn
    keyVaultUri: keyVault.properties.vaultUri
    identityClientId: secretsIdentity.properties.clientId
    tags: union(tags, {
      Component: 'AI'
      Service: serviceNames.llmProcessor
    })
    keyVaultUris: secretUrls
  }
}

module backend './modules/backend.bicep' = {
  dependsOn: [
    sqlInfrastructure
    keyVaultSecretsRoleAssignment
  ]
  params: {
    location: location
    name: serviceNames.backend
    managedEnvironmentId: managedEnvironment.id
    identityId: secretsIdentity.id
    registryServer: containerRegistryServer
    registryUsername: containerRegistryUsername
    imageTag: backendImageTag
    revisionSuffix: revisionSuffix
    rabbitMqHost: rabbitMq.outputs.fqdn
    llmProcessorUrl: 'https://${llmProcessor.outputs.fqdn}'
    tags: union(tags, {
      Component: 'Backend'
      Service: serviceNames.backend
    })
    keyVaultUris: secretUrls
  }
}

module frontend './modules/frontend.bicep' = {
  dependsOn: [
    keyVaultSecretsRoleAssignment
  ]
  params: {
    location: location
    name: serviceNames.frontend
    managedEnvironmentId: managedEnvironment.id
    identityId: secretsIdentity.id
    registryServer: containerRegistryServer
    registryUsername: containerRegistryUsername
    imageTag: frontendImageTag
    revisionSuffix: revisionSuffix
    registryCredentialUri: secretUrls.registryPassword
    tags: union(tags, {
      Component: 'Frontend'
      Service: serviceNames.frontend
    })
  }
}

// Certificate creation and binding are completed by cert-binding.bicep after this stage.
var gatewayCustomDomains = []

module gateway './modules/gateway.bicep' = {
  dependsOn: [
    keyVaultSecretsRoleAssignment
  ]
  params: {
    location: location
    name: serviceNames.gateway
    managedEnvironmentId: managedEnvironment.id
    identityId: secretsIdentity.id
    registryServer: containerRegistryServer
    registryUsername: containerRegistryUsername
    imageTag: gatewayImageTag
    revisionSuffix: revisionSuffix
    registryCredentialUri: secretUrls.registryPassword
    customDomains: gatewayCustomDomains
    routingEnvironment: [
      {
        name: 'LLM_PROCESSOR_URL'
        value: 'https://${llmProcessor.outputs.fqdn}'
      }
      {
        name: 'BACKEND_URL'
        value: 'https://${backend.outputs.fqdn}'
      }
      {
        name: 'FRONTEND_URL'
        value: 'https://${frontend.outputs.fqdn}'
      }
    ]
    tags: union(tags, {
      Component: 'Gateway'
      Service: serviceNames.gateway
    })
  }
}

resource gatewayCertificate 'Microsoft.App/managedEnvironments/managedCertificates@2023-05-01' = if (!empty(gatewayCustomDomain) && createGatewayCertificate) {
  parent: managedEnvironment
  name: certificateName
  location: location
  properties: {
    subjectName: gatewayCustomDomain
    domainControlValidation: 'CNAME'
  }
  dependsOn: [
    gateway
  ]
}

output managedEnvironmentId string = managedEnvironment.id
output sqlServerFqdn string = sqlInfrastructure.outputs.sqlServerFqdn
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output backendUrl string = backend.outputs.fqdn
output frontendUrl string = frontend.outputs.fqdn
output gatewayUrl string = gateway.outputs.fqdn
output llmProcessorUrl string = llmProcessor.outputs.fqdn
output cacheUrl string = cache.outputs.fqdn
output rabbitMqUrl string = rabbitMq.outputs.fqdn
