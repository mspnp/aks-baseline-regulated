param name string
param location string 


resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'umi-${name}'
  location: location
}





