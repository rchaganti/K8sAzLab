// Name        : storage.bicep
// Description : Creates storage account, container, and fileshare
// Version     : 1.0.0
// Author      : github.com/rchaganti

// parameters
@description('Name for the storage account. This has to be globally unique.')
param storageAccountName string

@description('Name for the storage container.')
param storageContainerName string

@description('Name for the file share.')
param storageFileShareName string

@description('Location where this storage account needs to be created.')
param location string

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

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${sa.name}/default/${storageContainerName}'
  properties: {
    publicAccess: 'Container'
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: '${sa.name}/default/${storageFileShareName}'
}

// variables
var blobUri = 'https://${storageAccountName}.blob.${environment().suffixes.storage}/${storageContainerName}'
var shareUnc = '\\${storageAccountName}.file.${environment().suffixes.storage}\${storageFileShareName}'
var blobSuffix = substring(guid(storageContainerName, storageFileShareName),0,5)

// outputs
output storage object = {
  name: sa.name
  blobUri: blobUri
  shareUri: shareUnc
  blobSuffix: blobSuffix
  storageKey: sa.listKeys().keys[0].value
}
