import {storageAccount as stg} from '../types/storage.types.bicep'

// parameters
param storageAccountName stg.name
param location stg.location
param storageFileShareName stg.shareName

// resources
resource sa 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Cool'
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: '${sa.name}/default/${storageFileShareName}'
}

// outputs
output storage object = {
  name: storageAccountName
  shareUri: '//${storageAccountName}.file.${environment().suffixes.storage}/${storageFileShareName}'
  storageKey: sa.listKeys().keys[0].value
}
