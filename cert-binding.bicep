// Stage 2: Bind SSL certificate to custom domain
// Run this after stage 1 creates the certificate

// Parameters: deployment and identity
@description('Azure region for resources')
param location string

@description('Name of the existing Key Vault containing application secrets')
param keyVaultName string

@description('Name of the existing user-assigned identity used by Container Apps to read Key Vault secrets')
param keyVaultIdentityName string

// Parameters: container registry
@description('Container registry server')
param containerRegistryServer string

@description('Container registry username')
param containerRegistryUsername string

// Parameters: gateway and certificate
@description('Gateway container image tag')
param gatewayImageTag string

@description('Custom domain for gateway')
param gatewayCustomDomain string

@description('Name of the existing managed certificate')
param certificateName string

@description('Name of the existing Container Apps environment')
param managedEnvironmentName string

@description('Name of the gateway Container App')
param gatewayName string

@description('Name of the backend Container App')
param backendName string

@description('Name of the frontend Container App')
param frontendName string

@description('Name of the LLM Processor Container App')
param llmProcessorName string

@description('Project tag value')
param projectName string

@description('Managed-by tag value')
param managedBy string

@description('Cost-center tag value')
param costCenter string

// Parameters: environment
@description('Environment tag')
@allowed([
  'development'
  'staging'
  'production'
])
param environment string

// Variables: shared tags
var commonTags = {
  Environment: environment
  Project: projectName
  ManagedBy: managedBy
  CostCenter: costCenter
}

// Variables: Key Vault secret reference
var registryPasswordUrl = '${keyVault.properties.vaultUri}secrets/registry-password'

// Resources: existing dependencies
resource managedEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: managedEnvironmentName
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource secretsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: keyVaultIdentityName
}

resource backend 'Microsoft.App/containerApps@2025-10-02-preview' existing = {
  name: backendName
}

resource frontend 'Microsoft.App/containerApps@2025-10-02-preview' existing = {
  name: frontendName
}

resource llmProcessor 'Microsoft.App/containerApps@2025-10-02-preview' existing = {
  name: llmProcessorName
}

var gatewayRoutingEnvironment = [
  {
    name: 'LLM_PROCESSOR_URL'
    value: 'https://${llmProcessor.properties.configuration.ingress.fqdn}'
  }
  {
    name: 'BACKEND_URL'
    value: 'https://${backend.properties.configuration.ingress.fqdn}'
  }
  {
    name: 'FRONTEND_URL'
    value: 'https://${frontend.properties.configuration.ingress.fqdn}'
  }
]

resource gatewayCertificate 'Microsoft.App/managedEnvironments/managedCertificates@2023-05-01' existing = {
  parent: managedEnvironment
  name: certificateName
}

// Resources: gateway SSL binding
resource containerAppGateway 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: gatewayName
  location: location
  tags: commonTags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${secretsIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
        customDomains: [
          {
            name: gatewayCustomDomain
            bindingType: 'SniEnabled'
            certificateId: gatewayCertificate.id
          }
        ]
      }
      registries: [
        {
          server: containerRegistryServer
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          keyVaultUrl: registryPasswordUrl
          identity: secretsIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'gateway'
          image: '${containerRegistryServer}/sziszka90/finance-app-gateway:${gatewayImageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: gatewayRoutingEnvironment
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs: gateway endpoints
output gatewayUrl string = containerAppGateway.properties.configuration.ingress.fqdn
output customDomainUrl string = 'https://${gatewayCustomDomain}'
