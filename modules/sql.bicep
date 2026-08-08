// SQL Server, database, and firewall resources

param location string
param sqlServerName string
param sqlDatabaseName string

@allowed([
  'Enabled'
  'Disabled'
])
param sqlPublicNetworkAccess string

param allowAzureServicesToAccessSql bool

@secure()
param sqlAdministratorLogin string

@secure()
param sqlAdministratorPassword string

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: sqlPublicNetworkAccess
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
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

resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01' = if (allowAzureServicesToAccessSql) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
