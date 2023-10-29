targetScope = 'subscription'

param name string
param location string
//param managedBy string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${name}'
  location: location
//  managedBy: managedBy
}

output resourceId string = rg.id
