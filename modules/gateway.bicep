param location string
param name string
param managedEnvironmentId string
param identityId string
param registryServer string
param registryUsername string
param imageTag string
param revisionSuffix string
param registryCredentialUri string
param customDomains array
param routingEnvironment array
param tags object

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
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
        customDomains: customDomains
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
          keyVaultUrl: registryCredentialUri
          identity: identityId
        }
      ]
    }
    template: {
      revisionSuffix: revisionSuffix
      containers: [
        {
          name: 'gateway'
          image: '${registryServer}/${registryUsername}/${name}:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: routingEnvironment
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

output fqdn string = app.properties.configuration.ingress.fqdn
