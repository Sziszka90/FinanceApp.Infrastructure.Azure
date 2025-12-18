// FinanceApp Infrastructure - Azure Container Apps
// Bicep template for deploying microservices architecture

// Parameters
@description('Location for all resources')
param location string = 'polandcentral'

@description('SQL Server administrator login')
param sqlAdministratorLogin string

@description('SQL Server administrator password')
@secure()
param sqlAdministratorPassword string

param containerRegistryServer string = 'ghcr.io'
param containerRegistryUsername string

@description('Container registry password')
@secure()
param containerRegistryPassword string

@secure()
param openAiApiKey string

@secure()
param authenticationSecretKey string

param authenticationAudience string
param authenticationIssuer string

param smtpHost string
param smtpPort int = 587
param smtpUser string

@secure()
param smtpPassword string

param smtpFromEmail string

param exchangeRateApiUrl string
param exchangeRateApiEndpoint string

@secure()
param exchangeRateApiAppId string

param rabbitMqUsername string

@secure()
param rabbitMqPassword string

@secure()
param redisConnectionString string

@secure()
param redisPassword string

@secure()
param llmProcessorApiToken string

param backendImageTag string = 'latest'
param frontendImageTag string = 'latest'
param llmProcessorImageTag string = 'latest'
param gatewayImageTag string = 'latest'

@description('Custom domain for gateway (leave empty to use default)')
param gatewayCustomDomain string = 'www.financeapp.fun'

@description('Whether to create a new managed certificate (false to use existing)')
param createGatewayCertificate bool = true

@description('Environment name for resource tagging')
@allowed([
  'development'
  'staging'
  'production'
])
param environment string = 'production'

// Variables
var resourcePrefix = 'finance-app'
var managedEnvironmentName = 'FinanceApp'
var commonTags = {
  Environment: environment
  Project: 'FinanceApp'
  ManagedBy: 'Bicep-Template'
  CostCenter: 'Finance'
}
var logAnalyticsWorkspaceName = '${resourcePrefix}-logs'
var sqlServerName = 'projects-server-sziszka90'
var sqlDatabaseName = 'FinanceAppDB'
var containerAppBackendName = 'finance-app-backend'
var containerAppFrontendName = 'finance-app-frontend'
var containerAppCacheName = 'finance-app-cache'
var containerAppRabbitMQName = 'finance-app-rabbitmq'
var containerAppLLMProcessorName = 'finance-app-llmprocessor'
var containerAppGatewayName = 'finance-app-gateway'

// Resources

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: commonTags
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

// Managed Environment
resource managedEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: managedEnvironmentName
  location: location
  tags: commonTags
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

// Managed Certificate for Gateway (only if creating new)
resource gatewayCertificate 'Microsoft.App/managedEnvironments/managedCertificates@2023-05-01' = if (!empty(gatewayCustomDomain) && createGatewayCertificate) {
  parent: managedEnvironment
  name: gatewayCustomDomain
  location: location
  properties: {
    subjectName: gatewayCustomDomain
    domainControlValidation: 'CNAME'
  }
}

// Reference existing certificate (if not creating new)
resource existingGatewayCertificate 'Microsoft.App/managedEnvironments/managedCertificates@2023-05-01' existing = if (!empty(gatewayCustomDomain) && !createGatewayCertificate) {
  parent: managedEnvironment
  name: gatewayCustomDomain
}

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: sqlServerName
  location: location
  tags: commonTags
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: commonTags
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: 60
    requestedBackupStorageRedundancy: 'Local'
    minCapacity: json('0.5')
    isLedgerOn: false
    useFreeLimit: true
    freeLimitExhaustionBehavior: 'BillOverUsage'
  }
}

// SQL Firewall Rule - Allow Azure Services
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Cache Container App (Redis)
resource containerAppCache 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppCacheName
  location: location
  tags: union(commonTags, {
    Component: 'Cache'
    Service: containerAppCacheName
  })
  properties: {
    managedEnvironmentId: managedEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 6379
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'redis-password'
          value: redisPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'redis'
          image: 'docker.io/redis:latest'
          command: [
            'redis-server'
            '--requirepass'
            redisPassword
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// RabbitMQ Container App
resource containerAppRabbitMQ 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppRabbitMQName
  location: location
  tags: union(commonTags, {
    Component: 'Messaging'
    Service: containerAppRabbitMQName
  })
  properties: {
    managedEnvironmentId: managedEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 5672
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'rabbitmq-password'
          value: rabbitMqPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'rabbitmq'
          image: 'docker.io/rabbitmq:3-management'
          env: [
            {
              name: 'RABBITMQ_DEFAULT_USER'
              value: rabbitMqUsername
            }
            {
              name: 'RABBITMQ_DEFAULT_PASS'
              secretRef: 'rabbitmq-password'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// LLM Processor Container App
resource containerAppLLMProcessor 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppLLMProcessorName
  location: location
  tags: union(commonTags, {
    Component: 'AI'
    Service: containerAppLLMProcessorName
  })
  properties: {
    managedEnvironmentId: managedEnvironment.id
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
        {
          name: 'llm-processor-api-token'
          value: llmProcessorApiToken
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'llmprocessor'
          image: '${containerRegistryServer}/sziszka90/${containerAppLLMProcessorName}:${llmProcessorImageTag}'
          env: [
            {
              name: 'ApiToken'
              secretRef: 'llm-processor-api-token'
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

// Backend Container App
resource containerAppBackend 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppBackendName
  location: location
  tags: union(commonTags, {
    Component: 'Backend'
    Service: containerAppBackendName
  })
  properties: {
    managedEnvironmentId: managedEnvironment.id
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
        {
          name: 'openai-api-key'
          value: openAiApiKey
        }
        {
          name: 'auth-secret-key'
          value: authenticationSecretKey
        }
        {
          name: 'smtp-password'
          value: smtpPassword
        }
        {
          name: 'exchange-rate-api-app-id'
          value: exchangeRateApiAppId
        }
        {
          name: 'rabbitmq-password'
          value: rabbitMqPassword
        }
        {
          name: 'llm-processor-api-token'
          value: llmProcessorApiToken
        }
        {
          name: 'redis-password-backend'
          value: redisPassword
        }
        {
          name: 'cache-connection-string'
          value: redisConnectionString
        }
        {
          name: 'sql-connection-string'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: '${containerRegistryServer}/sziszka90/${containerAppBackendName}:${backendImageTag}'
          env: [
            {
              name: 'ConnectionStrings__MsSql'
              secretRef: 'sql-connection-string'
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
              name: 'AuthenticationSettings__Audience'
              value: authenticationAudience
            }
            {
              name: 'AuthenticationSettings__Issuer'
              value: authenticationIssuer
            }
            {
              name: 'SmtpSettings__SmtpHost'
              value: smtpHost
            }
            {
              name: 'SmtpSettings__SmtpPort'
              value: string(smtpPort)
            }
            {
              name: 'SmtpSettings__SmtpUser'
              value: smtpUser
            }
            {
              name: 'SmtpSettings__SmtpPass'
              secretRef: 'smtp-password'
            }
            {
              name: 'SmtpSettings__FromEmail'
              value: smtpFromEmail
            }
            {
              name: 'ExchangeRateSettings__ApiUrl'
              value: exchangeRateApiUrl
            }
            {
              name: 'ExchangeRateSettings__ApiEndpoint'
              value: exchangeRateApiEndpoint
            }
            {
              name: 'ExchangeRateSettings__AppId'
              secretRef: 'exchange-rate-api-app-id'
            }
            {
              name: 'RabbitMqSettings__HostName'
              value: containerAppRabbitMQName
            }
            {
              name: 'RabbitMqSettings__Port'
              value: '5672'
            }
            {
              name: 'RabbitMqSettings__UserName'
              value: rabbitMqUsername
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
              value: 'http://${containerAppLLMProcessorName}'
            }
            {
              name: 'CacheSettings__ConnectionString'
              value: '${containerAppCacheName}:6379,password=${redisPassword}'
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
  dependsOn: [
    sqlDatabase
    containerAppCache
    containerAppRabbitMQ
    containerAppLLMProcessor
  ]
}

// Frontend Container App
resource containerAppFrontend 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppFrontendName
  location: location
  tags: union(commonTags, {
    Component: 'Frontend'
    Service: containerAppFrontendName
  })
  properties: {
    managedEnvironmentId: managedEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
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
          name: 'frontend'
          image: '${containerRegistryServer}/sziszka90/${containerAppFrontendName}:${frontendImageTag}'
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

// Gateway Container App
resource containerAppGateway 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppGatewayName
  location: location
  tags: union(commonTags, {
    Component: 'Gateway'
    Service: containerAppGatewayName
  })
  properties: {
    managedEnvironmentId: managedEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
        customDomains: !empty(gatewayCustomDomain)
          ? [
              {
                name: gatewayCustomDomain
                bindingType: 'SniEnabled'
                certificateId: createGatewayCertificate ? gatewayCertificate.id : existingGatewayCertificate.id
              }
            ]
          : []
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
          image: '${containerRegistryServer}/sziszka90/${containerAppGatewayName}:${gatewayImageTag}'
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
  dependsOn: [
    containerAppFrontend
  ]
}

// Outputs
output managedEnvironmentId string = managedEnvironment.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output backendUrl string = containerAppBackend.properties.configuration.ingress.fqdn
output frontendUrl string = containerAppFrontend.properties.configuration.ingress.fqdn
output gatewayUrl string = containerAppGateway.properties.configuration.ingress.fqdn
output llmProcessorUrl string = containerAppLLMProcessor.properties.configuration.ingress.fqdn
output cacheUrl string = containerAppCache.properties.configuration.ingress.fqdn
output rabbitMqUrl string = containerAppRabbitMQ.properties.configuration.ingress.fqdn
