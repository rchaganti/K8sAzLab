@export()
@sealed()

type storageAccount = {
    @description('The name of the storage account')
    @minLength(3)
    @maxLength(24)
    name: string

    @description('The location of the storage account')
    location: string
    
    @description('The SMB share name for sharing files between nodes.')
    shareName: 'temp'
}
