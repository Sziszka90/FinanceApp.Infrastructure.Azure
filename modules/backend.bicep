param location string
param name string
param managedEnvironmentId string
param identityId string
param registryServer string
param registryUsername string
param imageTag string
param revisionSuffix string
param rabbitMqHost string
param llmProcessorUrl string
param tags object
param keyVaultUris object

resource app 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8080
        transport: 'http'
      }
      registries: [
        {
          server: registryServer
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          keyVaultUrl: keyVaultUris.registryPassword
          identity: identityId
        }
        {
          name: 'openai-api-key'
          keyVaultUrl: keyVaultUris.openAiApiKey
          identity: identityId
        }
        {
          name: 'auth-secret-key'
          keyVaultUrl: keyVaultUris.authSecretKey
          identity: identityId
        }
        {
          name: 'smtp-password'
          keyVaultUrl: keyVaultUris.smtpPassword
          identity: identityId
        }
        {
          name: 'exchange-rate-api-app-id'
          keyVaultUrl: keyVaultUris.exchangeRateApiAppId
          identity: identityId
        }
        {
          name: 'rabbitmq-password'
          keyVaultUrl: keyVaultUris.rabbitMqPassword
          identity: identityId
        }
        {
          name: 'llm-processor-api-token'
          keyVaultUrl: keyVaultUris.llmProcessorApiToken
          identity: identityId
        }
        {
          name: 'cache-connection-string'
          keyVaultUrl: keyVaultUris.cacheConnectionString
          identity: identityId
        }
        {
          name: 'finance-app-db-connection-string'
          keyVaultUrl: keyVaultUris.financeAppDbConnectionString
          identity: identityId
        }
      ]
    }
    template: {
      revisionSuffix: revisionSuffix
      containers: [
        {
          name: 'backend'
          image: '${registryServer}/${registryUsername}/${name}:${imageTag}'
          env: [
            {
              name: 'ConnectionStrings__MsSql'
              secretRef: 'finance-app-db-connection-string'
            }
            {
              name: 'CacheSettings__ConnectionString'
              secretRef: 'cache-connection-string'
            }
            {
              name: 'LLMClientSettings__ApiKey'
              secretRef: 'openai-api-key'
            }
            {
              name: 'AuthenticationSettings__SecretKey'
              secretRef: 'auth-secret-key'
            }
            {
              name: 'SmtpSettings__SmtpPass'
              secretRef: 'smtp-password'
            }
            {
              name: 'ExchangeRateSettings__AppId'
              secretRef: 'exchange-rate-api-app-id'
            }
            {
              name: 'RabbitMqSettings__HostName'
              value: rabbitMqHost
            }
            {
              name: 'RabbitMqSettings__Port'
              value: '5672'
            }
            {
              name: 'RabbitMqSettings__Password'
              secretRef: 'rabbitmq-password'
            }
            {
              name: 'LLMProcessorSettings__Token'
              secretRef: 'llm-processor-api-token'
            }
            {
              name: 'LLMProcessorSettings__ApiUrl'
              value: llmProcessorUrl
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        cooldownPeriod: 300
        pollingInterval: 30
        rules: [
          {
            name: 'http-scaler'
            custom: {
              type: 'http'
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

output fqdn string = app.properties.configuration.ingress.fqdn
