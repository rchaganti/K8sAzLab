@export()
@sealed()
type linuxVm = {
  @description('Name of the VM to be created.')
  name: string

  @description('The size of the VM')
  vmSize: string

  @description('Network interface resource Id.')
  nicId: string

  @description('Location for VM resource.')
  location: string
  
  @description('Username for the VM.')
  username: string

  @description('Linux OS version.')
  osVersion: string

  @description('Linux OS offer.')
  osOffer: string

  @description('Linux OS publisher')
  osPublisher: string

  @description('Disk type for OS disk')
  osDiskType: string

  @description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
  authenticationType: 'sshPublicKey' | 'password'

  @description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
  @secure()
  passwordOrKey: string
}
