import {virtualNetwork as vnet} from '../types/vnet.types.bicep'

// parameters
@description('Create a new virtual network or use an existing one.')
@allowed([
  'new'
  'existing'
])
param newOrExisting string = 'new'

@description('Name of the virtual network to create.')
param vNetName vnet.name

@description('Location of the virtual network.')
param location string

@description('Virtual network address prefix.')
param vNetAddressPrefix string

@description('Virtual network address prefix.')
param subnetName string

@description('Subnet address prefix.')
param subnetPrefix string

// resources
resource vnetwork 'Microsoft.Network/virtualNetworks@2021-02-01' = if (newOrExisting == 'new') {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }

  resource subnet 'subnets' existing = {
    name: subnetName
  }
}

// outputs
output subnetId string = vnet::subnet.id
