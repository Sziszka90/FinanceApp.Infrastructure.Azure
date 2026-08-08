param location string
param name string
param managedEnvironmentId string
param identityId string
param redisCredentialUri string
param revisionSuffix string
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
        external: false
        targetPort: 6379
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'redis-password'
          keyVaultUrl: redisCredentialUri
          identity: identityId
        }
      ]
    }
    template: {
      revisionSuffix: revisionSuffix
      containers: [
        {
          name: 'redis'
          image: 'docker.io/redis:latest'
          command: [
            'sh'
            '-c'
          ]
          args: [
            'exec redis-server --requirepass "$REDIS_PASSWORD"'
          ]
          env: [
            {
              name: 'REDIS_PASSWORD'
              secretRef: 'redis-password'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
