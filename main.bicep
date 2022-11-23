// Name        : main.bicep
// Description : Implements template needed to provision a Kubernetes cluster using Ubuntu VMs on Azure
// Version     : 1.0.0
// Author      : github.com/rchaganti

// parameters
@description('Location for all resources.')
param location string = resourceGroup().location

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
var commonPrerequisiteConfig = loadFileAsBase64('scripts/common-prerequisites.sh')
//var cpPrerequisiteConfig = loadFileAsBase64('scripts/cp-prerequisites.sh')
//var workerPrerequisiteConfig = loadFileAsBase64('scripts/worker-prerequisites.sh')

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

// Provision common config
resource cse 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for vm in vmObject: {
  dependsOn: vms
  name: '${vm.name}/commoncse'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: commonPrerequisiteConfig
    }
  }
}]

/*
// Provision initial common config required for kubeadm init/join on all VMs
module commonPrereq 'modules/linuxScript.bicep' = [for (vm, i) in vmObject: {
  name: '${vm.name}copr'
  dependsOn: vms
  params: {
    configType: 'common'
    location: location
    scriptContent: commonPrerequisiteConfig
    vmName: vm.name
  }
}]


// Provision initial common config required for kubeadm init/join on all VMs
module cpPrereq 'modules/linuxScript.bicep' = [for (vm, i) in vmObject: if(vm.role == 'cp') {
  name: '${vm.name}cppr'
  dependsOn: commonPrereq
  params: {
    configType: 'cpPrereq'
    location: location
    scriptContent: cpPrerequisiteConfig
    vmName: vm.name
  }
}]

// Provision initial common config required for kubeadm init/join on all VMs
module workerPrereq 'modules/linuxScript.bicep' = [for (vm, i) in vmObject: if(vm.role == 'worker') {
  name: '${vm.name}wpr'
  dependsOn: commonPrereq
  params: {
    configType: 'workerPrereq'
    location: location
    scriptContent: workerPrerequisiteConfig
    vmName: vm.name
  }
}]
*/

// Retrieve output
output deployment array = [for (vm, i) in vmObject: {
  vmName: vm.name
  vmConnect: 'ssh ${username}@${pip[i].outputs.pipInfo.dnsFqdn}'
}]
