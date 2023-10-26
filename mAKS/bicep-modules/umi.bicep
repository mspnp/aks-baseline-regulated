param name string
param location string 


resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'umi-${name}'
  location: location
}

output id string = umi.id
output name string = umi.name
output principalId string = umi.properties.principalId
