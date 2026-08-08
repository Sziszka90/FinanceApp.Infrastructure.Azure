param location string
param name string
param managedEnvironmentId string
param identityId string
param rabbitMqCredentialUri string
param rabbitMqUsername string
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
        targetPort: 5672
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'rabbitmq-password'
          keyVaultUrl: rabbitMqCredentialUri
          identity: identityId
        }
      ]
    }
    template: {
      revisionSuffix: revisionSuffix
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
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
