// Name        : linuxScript.bicep
// Description : Linux custom script extension for post OS install configuration
// Version     : 1.0.0
// Author      : github.com/rchaganti

@description('Custom script content.')
param scriptContent string

@description('VM on which the script needs to execute.')
param vmName string

@description('Location where the VM is located.')
param location string

@description('Type of configuration.')
param configType string

resource cse 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: '${vmName}/${configType}cse'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64(scriptContent)
    }
  }
}
