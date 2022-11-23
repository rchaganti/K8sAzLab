// 7_3-bicepPublicIp.bicep
// Parameters
param vmName string
param location string

// Variables
var pipName = '${vmName}pip'

// Resources
resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: '${vmName}pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${vmName}${uniqueString(resourceGroup().id)}'
    }
    idleTimeoutInMinutes: 10
  }
}

// Variables
var pipIP = reference(resourceId('Microsoft.Network/publicIPAddresses', pipName), '2021-02-01', 'full').properties

// Outputs
output pipInfo object = {
  id: pip.id
  dnsFqdn: pipIP.dnsSettings.fqdn
}
