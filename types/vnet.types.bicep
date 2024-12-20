@export()
@sealed()
type virtualNetwork = {
  @description('Name of the virtual network to create.')
  name: string

  @description('Location of the virtual network.')
  location: string
  
  @description('Virtual network address prefix.')
  addressPrefix: string
  
  @description('Subnet name.')
  subnetName: string

  @description('Subnet address prefix.')
  subnetPrefix: string
}
