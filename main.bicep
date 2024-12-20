import {k8scluster as k8s} from 'types/K8sCluster.types.bicep'
import {linuxVm as vm} from 'types/linuxvm.types.bicep'

// parameters
@description('Location for all resources.')
param location string = resourceGroup().location

@description('Kubernetes cluster object.')
param k8sInfo k8s = {
  name: ''
  numCP: 1
  numWorker: 2
  cniCidr: '10.244.0.0/16'
  cniPlugin: 'calico'
}

@description('Linux VM parameters')
param linuxInfo vm = {
  username: 'azureuser'
  passwordOrKey: 'Password'
}

var cpVmNames = [for i in range(0, k8sInfo.numCP): {
  name: 'cplane${(i + 1)}'
  role: 'cp'
}]

var workerVmNames = [for i in range(0, k8sInfo.numWorker): {
  name: 'worker${(i + 1)}'
  role: 'worker'
}]
var vmObject = concat(cpVmNames, workerVmNames)


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
module kubeadmInitMrc 'modules/managedRunCmd.bicep' = {
  name: 'kubeadmInitMrc'
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
      {
        value: pip[0].outputs.pipInfo.dnsFqdn
      }
      {
        value: kubeadmInitYml
      }
    ]
  }
}

// Provision storage account, container, and file share
module storageAccount 'modules/storage.bicep' = {
  name: 'sa'
  dependsOn: [
    kubeadmInitMrc
  ]
  params: {
    location: location
    storageAccountName: storageAccountName
    storageFileShareName: storageFileShareName
  }
}

// Install CNI plugin
module cniInstallMrc 'modules/managedRunCmd.bicep' = {
  name: 'CniInstallMrc'
  dependsOn: [
    storageAccount
  ]
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
  }
}

// Generate kubedam join command on control plane
module finalizeDeployCPMrc 'modules/managedRunCmd.bicep' = {
  name: 'finalizeDeployCP'
  dependsOn: [
    cniInstallMrc
  ]
  params: {
    configType: 'finalizeDeployCP'
    location: location
    vmName: 'cplane1'
    scriptContent: finalizeDeploy
    scriptParams: [
      {
        value: storageAccountName
      }
      {
        value: storageAccount.outputs.storage.storageKey
      }
      {
        value: storageAccount.outputs.storage.shareUri
      }
      {
        value: 'cp'
      }
      {
        value: kubeadmJoinYml
      }
    ]
  }
}

// Join nodes to the Kubernetes cluster
module finalizeDeployWorkerMrc 'modules/managedRunCmd.bicep' = [for vm in vmObject: if (vm.role == 'worker') {
  name: '${vm.name}-finalizeDeployWorker'
  dependsOn: [
    finalizeDeployCPMrc
  ]
  params: {
    configType: 'finalizeDeployWorker'
    location: location
    vmName: vm.name
    scriptContent: finalizeDeploy
    scriptParams: [
      {
        value: storageAccountName
      }
      {
        value: storageAccount.outputs.storage.storageKey
      }
      {
        value: storageAccount.outputs.storage.shareUri
      }
      {
        value: 'worker'
      }
    ]
  }
}]

// Retrieve output
output vmInfo array = [for (vm, i) in vmObject: {
  name: vm.name
  connect: 'ssh ${username}@${pip[i].outputs.pipInfo.dnsFqdn}'
}]
