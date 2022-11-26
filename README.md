# Kubernetes lab on Azure

As a part of this experiment to automate Kubernetes deployment on Azure, I created a set of Bicep modules and a Bicep template that uses these modules.

Here is how you use this template. First, start by cloning this repository.

```shell
git clone https://github.com/rchaganti/K8sAzLab.git
```

This repository contains a devcontainer definition that you can use to start a container (assuming you have Docker Desktop installed) with the necessary tooling to build and deploy Bicep templates. This is my preferred way of development these days. If you do not have Docker Desktop or do not prefer devcontainers, you can simply install Bicep binary on the local machine to provision this template.

Before you deploy template, the `main.bicep` template contains a few parameters that are needed for template deployment.

| Parameter Name       | Description                                                  | Default Value            |
| -------------------- | ------------------------------------------------------------ | ------------------------ |
| location             | Location for all resources created using this template       | resourceGroup().location |
| storageAccountName   | Specifies the name of the Azure Storage account              |                          |
| storageFileShareName | Specifies the SMB share name for sharing files between nodes | temp                     |
| numCP                | Number of control plane VMs                                  | 1                        |
| numWorker            | Number of worker VMs                                         | 3                        |
| username             | Username for the Linux VM                                    | ubuntu                   |
| authenticationType   | Type of authentication to use on the Virtual Machine. SSH key is recommended | password                 |
| passwordOrKey        | SSH Key or password for the Virtual Machine. SSH key is recommended |                          |
| cniPlugin            | CNI plugin to install                                        | calico                   |
| cniCidr              | CNI Pod Network CIDR                                         | 10.244.0.0/16            |

This is still a very early version of my work and gets you from nothing to a fully functional Kubernetes cluster with a single control plane node in under 8 minutes. 

At the moment, this can only support single control plane node. I have not added HA configuration yet and will do that in the coming days/weeks. For CNI, Calico is supported and I plan to add Cilium support soon. The overall structure of the module enables extending the overall automation in a easy manner. A storage account and an SMB share are created for the purpose of sharing the `kubeadm join` command between control plane and worker nodes.

Here is how you provision the template using Azure CLI.

```shell
az deployment group create --template-file main.bicep \
              --parameters storageAccountName=someUniqueName \
              --resource-group k8s
```

The resource group that you specify in the above command must already exist. You will be prompted to enter a password / ssh key.

At the end of deployment, you will see the ssh commands to connect to each node in the cluster. You can query the deployment output using the following command.

```shell
vscode ➜ /workspaces/azk8slab $ az deployment group show -g k8s -n main --query properties.outputs
{
  "vmInfo": {
    "type": "Array",
    "value": [
      {
        "connect": "ssh ubuntu@cplane1lmwuauibze44k.eastus.cloudapp.azure.com",
        "name": "cplane1"
      },
      {
        "connect": "ssh ubuntu@worker1lmwuauibze44k.eastus.cloudapp.azure.com",
        "name": "worker1"
      },
      {
        "connect": "ssh ubuntu@worker2lmwuauibze44k.eastus.cloudapp.azure.com",
        "name": "worker2"
      },
      {
        "connect": "ssh ubuntu@worker3lmwuauibze44k.eastus.cloudapp.azure.com",
        "name": "worker3"
      }
    ]
  }
}
```

You can connect to the control plane node as the user you specified (default is ubuntu.) and verify if all nodes are in ready state or not and if all control plane pods are running or not.
