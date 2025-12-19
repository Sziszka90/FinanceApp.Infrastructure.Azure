// Stage 2: Bind SSL certificate to custom domain
// Run this after stage 1 creates the certificate

@description('Azure region for resources')
param location string = 'polandcentral'

@description('Container registry server')
param containerRegistryServer string = 'ghcr.io'

@description('Container registry username')
param containerRegistryUsername string

@secure()
@description('Container registry password')
param containerRegistryPassword string

@description('Gateway container image tag')
param gatewayImageTag string = 'latest'

@description('Custom domain for gateway')
param gatewayCustomDomain string = 'www.financeapp.fun'

@description('Name of the existing managed certificate')
param certificateName string = 'www.financeapp.fun'

@description('LLM Processor URL for gateway routing')
param llmProcessorUrl string

@description('Backend URL for gateway routing')
param backendUrl string

@description('Frontend URL for gateway routing')
param frontendUrl string

@description('Environment tag')
@allowed([
  'development'
  'staging'
  'production'
])
param environment string = 'production'

// Variables
var gatewayName = 'finance-app-gateway'
var managedEnvironmentName = 'FinanceApp'

var commonTags = {
  Environment: environment
  Project: 'FinanceApp'
  ManagedBy: 'Bicep'
  CostCenter: 'FinanceTeam'
}

// Reference existing managed environment
resource managedEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: managedEnvironmentName
}

// Reference existing certificate
resource gatewayCertificate 'Microsoft.App/managedEnvironments/managedCertificates@2023-05-01' existing = {
  parent: managedEnvironment
  name: certificateName
}

// Update Gateway Container App with SSL binding
resource containerAppGateway 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: gatewayName
  location: location
  tags: commonTags
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
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'gateway'
          image: '${containerRegistryServer}/sziszka90/financeapp-gateway:${gatewayImageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'LLM_PROCESSOR_URL'
              value: llmProcessorUrl
            }
            {
              name: 'BACKEND_URL'
              value: backendUrl
            }
            {
              name: 'FRONTEND_URL'
              value: frontendUrl
            }
          ]
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

output gatewayUrl string = containerAppGateway.properties.configuration.ingress.fqdn
output customDomainUrl string = 'https://${gatewayCustomDomain}'
