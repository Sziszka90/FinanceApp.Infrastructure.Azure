param location string
param name string
param managedEnvironmentId string
param identityId string
param registryServer string
param registryUsername string
param imageTag string
param revisionSuffix string
param identityClientId string
param tags object
param registryPasswordSecretUrl string

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
        targetPort: 8000
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
          keyVaultUrl: registryPasswordSecretUrl
          identity: identityId
        }
      ]
    }
    template: {
      revisionSuffix: revisionSuffix
      containers: [
        {
          name: 'llmprocessor'
          image: '${registryServer}/${registryUsername}/${name}:${imageTag}'
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: identityClientId
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 2
        maxReplicas: 10
        cooldownPeriod: 900
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

output fqdn string = app.properties.configuration.ingress.fqdn
