// Name        : main.bicep
// Description : Implements template needed to provision a Kubernetes cluster using Ubuntu VMs on Azure
// Version     : 1.0.0
// Author      : github.com/rchaganti

// parameters
@description('Location for all resources.')
param location string = resourceGroup().location

@description('Specifies the name of the Azure Storage account.')
param storageAccountName string = 'k8sbicepstore'

@description('Specifies the prefix of the blob container name.')
param storageContainerName string = 'logs'

@description('Specifies the prefix of the blob container name.')
param storageFileShareName string = 'share'

@description('Number of control plane VMs.')
@allowed([
  1
  3
  5
])
param numCP int = 1

@description('Number of worker VMs.')
@minValue(1)
param numWorker int = 1

@description('Username for the Linux VM')
param username string = 'ubuntu'

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param passwordOrKey string

@description('CNI plugin to install.')
param cniPlugin string = 'calico'

@description('CNI Pod Network CIDR.')
param cniCidr string = '10.244.0.0/16'

// variables
var cpVmNames = [for i in range(0, numCP): {
  name: 'cplane${(i + 1)}'
  role: 'cp'
}]

var workerVmNames = [for i in range(0, numWorker): {
  name: 'worker${(i + 1)}'
  role: 'worker'
}]
var vmObject = concat(cpVmNames, workerVmNames)

// Script content for Kubernetes cluster creation
var commonPrerequisiteConfig = loadTextContent('scripts/common-prerequisites.sh', 'utf-8')
var kubeadmInit = loadTextContent('scripts/kubeadmInit.sh','utf-8')
var cniInstall = loadTextContent('scripts/cniPlugin.sh','utf-8')

// Provision storage account, container, and file share
module storageAccount 'modules/storage.bicep' = {
  name: 'sa'
  params: {
    location: location
    storageAccountName: storageAccountName
    storageContainerName: storageContainerName
    storageFileShareName: storageFileShareName
  }
}

// Provision NSG and allow 22 and 6443
module nsg 'modules/nsg.bicep' = {
  name: 'k8s-nsg'
  params: {
    nsgName: 'k8s-nsg'
    location: location
    nsgProperties: [
      {
        name: 'ssh'
        priority: 1001
        protocol: 'tcp'
        access: 'allow'
        direction: 'inbound'
        destinationPortRange: 22 
      }
      {
        name: 'k8s'
        priority: 1002
        protocol: 'tcp'
        access: 'allow'
        direction: 'inbound'
        destinationPortRange: 6443
      }
    ]
  }
}

// Provision virtual network
module vnet 'modules/vnet.bicep' = {
  name: 'k8s-vnet'
  params: {
   location: location
   subnetName: 'k8s-subnet'
   vNetName: 'k8s-vnet'
   vNetAddressPrefix: '10.0.0.0/16'
   subnetPrefix: '10.0.1.0/27'
  }
}

// Provision public IP resources for each virtual machine
module pip 'modules/pip.bicep' = [for vm in vmObject: {
  name: '${vm.name}pip'
  params: {
    vmName: vm.name
    location: location
  }
}]

// Provision network interface for each virtual machine
module nic 'modules/nic.bicep' = [for (vm, i) in vmObject: {
  name: '${vm.name}nic'
  params: {
    location: location
    subnetId: vnet.outputs.subnetId
    netInterfacePrefix: vm.name
    nsgId: nsg.outputs.id
    publicIPId: pip[i].outputs.pipInfo.id
  }
}]

// Provision VMs
module vms 'modules/linuxvm.bicep' = [for (vm, i) in vmObject: {
  name: vm.name
  params: {
    location: location
    passwordOrKey: passwordOrKey
    username: username
    vmName: vm.name
    authenticationType: authenticationType
    nicId: nic[i].outputs.id
    osOffer: '0001-com-ubuntu-server-focal'
    osPublisher: 'canonical'
    osVersion: '20_04-lts'
  }
}]

// Provision common config using custom script extension
resource cse 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vm, i) in vmObject: {
  name: '${vm.name}/commonfcse'
  dependsOn: vms
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64(commonPrerequisiteConfig)
    }
  }
}]

// Perform kubeadm init on cplane1
var blobUri = storageAccount.outputs.storage.blobUri
var blobSuffix = storageAccount.outputs.storage.blobSuffix

module kubeadm 'modules/managedRunCmd.bicep' = {
  name: 'kubeadminit'
  dependsOn: cse
  params: {
    configType: 'kubeadminit'
    location: location
    vmName: 'cplane1'
    scriptContent: kubeadmInit
    scriptParams: [
      {
        value: cniCidr
      }
    ]
    errorBlobUri: '${blobUri}/cplane1-kubeadminit-${blobSuffix}-err.txt' 
    outputBlobUri: '${blobUri}/cplane1-kubeadminit-${blobSuffix}-out.txt' 
  }
}

// Install CNI plugin
module cniInstallMrc 'modules/managedRunCmd.bicep' = {
  name: '${kubeadm.name}Cni'
  params: {
    configType: 'cniInstall'
    location: location
    vmName: 'cplane1'
    scriptContent: cniInstall
    scriptParams: [
      {
        value: username
      }
      {
        value: cniPlugin
      }
      {
        value: cniCidr
      }
    ]
    errorBlobUri: '${blobUri}/cplane1-cniInstall-${blobSuffix}-err.txt' 
    outputBlobUri: '${blobUri}/cplane1-cniInstall-${blobSuffix}-out.txt' 
  }
}

// TODO: Join the worker nodes

// Retrieve output
output vmInfo array = [for (vm, i) in vmObject: {
  name: vm.name
  connect: 'ssh ${username}@${pip[i].outputs.pipInfo.dnsFqdn}'
}]

output storageInfo object = {
  saName: storageAccount.outputs.storage.name
  saKey: storageAccount.outputs.storage.storageKey
  shareUnc: storageAccount.outputs.storage.shareUri
  blobUri: storageAccount.outputs.storage.blobUri
}
