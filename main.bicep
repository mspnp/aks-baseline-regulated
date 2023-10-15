targetScope = 'subscription'

param location string = 'westeurope'

param geoRedundancyLocation string = 'northeurope'

param appGatewayListenerCertificate string = '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%'

param aksIngressControllerCertificate string = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURaVENDQWsyZ0F3SUJBZ0lVSnY4VnpCd25uUHVPeVJBRzZMak5QK2dXY0ZBd0RRWUpLb1pJaHZjTkFRRUwKQlFBd1FqRWlNQ0FHQTFVRUF3d1pLaTVoYTNNdGFXNW5jbVZ6Y3k1amIyNTBiM052TG1OdmJURWNNQm9HQTFVRQpDZ3dUUTI5dWRHOXpieUJCUzFNZ1NXNW5jbVZ6Y3pBZUZ3MHlNekV3TVRFeE1qRXpNRGRhRncweU5ERXdNVEF4Ck1qRXpNRGRhTUVJeElqQWdCZ05WQkFNTUdTb3VZV3R6TFdsdVozSmxjM011WTI5dWRHOXpieTVqYjIweEhEQWEKQmdOVkJBb01FME52Ym5SdmMyOGdRVXRUSUVsdVozSmxjM013Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQgpEd0F3Z2dFS0FvSUJBUURLWHo1K1hDU1FPc3NaenB3V0dkQ2F1SDMvTVBERUJCcDFqWHJLMzhmY3lUSzlHZlFUCkh4T2Y5eHFXME9oZk45Umk4OFpwNXRoN01iRXhBVXhEbTZkdWg0Mzc0SGJzY3VINDlvRGlMMGRqaW1LaWt4eHUKNVEycW8vVWM5Q1NKZk13czFkUHRWZ2pDRm5PbUxYSWQxTUhvS2Y3QlpIKzVUb0w4NmpFeXExN1Q0THhTbGRaVwo0ekRXN2tqc3V1R0hSVTZEREU2SkU2aXR0cFZDY1BkNzZ2Unh1d2JCbDBabnFYRkh3NjVpM01jUGs1S2pkYU9LCnhlQU5PdktKaTloeGVLbExaVzBJQ3h6YUhLZ1RHUC9zUFhjYXNKOGp6LzFDdStJcTRqRzdvOU81UUl5dUV2NnUKYi9qY1ptMnREbGNtbWxhMXNjQzU3cHlnb2did0xMWmVja1YvQWdNQkFBR2pVekJSTUIwR0ExVWREZ1FXQkJSawpscFdFbjNVaWZVTzBVRHdMTFN1VlJBQU5tREFmQmdOVkhTTUVHREFXZ0JSa2xwV0VuM1VpZlVPMFVEd0xMU3VWClJBQU5tREFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUFOSFZmcEk3VGkKR1ZyUmxSR3lvSkVkenJFZ1FkYnNhd2FNOEMwV29sY2RzZUFWeUlqSXNPZDh6blI4VUlMVDV4TkJ5WWNwcUduQQp3SGUwNDZHWW1TTG5LRm5xVHB2S0dzd084SjJoQlhuclVQNXIwTlU5RVpod3V6WEVPbFhkVCtZeStSZnNweHlTCno5cFJaeHFIYzJCcTZvaXNuRUc4d0dqUnNZTk1HYWJBU3BHcGQ0ejhTQ3ZOQUUxYUJvVHAyS2dSVVpxSEl5L1kKbnJvd1RJUGpqWmVhYU1ocHhiNVY0TGFnNzdaZnhOWWJnOHN0KytpeTJ5dDdmSnk4T29iRzMxZFFWK2UxKzltYgpxTXhETFg1NVFaY1ZSTnR3WkhhZTlTSlJidXRoUk16d1ZYZjJwTUlUcm1KaHdEdGlnWDcxRlBJRlVhVG96UndJCm1iZzcxSGFNakYrNgotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==%'

resource rghub 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${location}-hub'
  location: location
}

resource rgspoke 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${location}-spoke'
  location: location
}

resource rgaks 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${location}-aks'
  location: location
}

module hub 'networking/hub-region.v2.bicep' = {
  name: 'testhub'
  scope: rghub
  params: {
    //nodepoolSubnetResourceIds: spoke.outputs.nodepoolSubnetResourceIds
    location: location
  }
}

module spoke 'networking/spoke-BU0001A0005-01.bicep' = {
  name: 'testspoke'
  scope: rgspoke
  params: {
    hubVnetResourceId: hub.outputs.hubVnetId
    location: location
  }
}


module preclusterstamp 'pre-cluster-stamp.bicep' = {
  name: 'testpreclusterstamp'
  scope: rgaks
  params: {
    location: location
    geoRedundancyLocation: geoRedundancyLocation
    aksIngressControllerCertificate: aksIngressControllerCertificate
    targetVnetResourceId: spoke.outputs.clusterVnetResourceId
  }
}

module clusterstamp 'cluster-stamp.bicep' = {
  name: 'clusterstamp'
  scope: rgaks
  params: {
    location: location
    appGatewayListenerCertificate: appGatewayListenerCertificate
    clusterAdminAadGroupObjectId: '56d2b35d-23cd-43e9-bef9-7b1e4b2fdf5b'
    gitOpsBootstrappingRepoHttpsUrl: 'https://github.com/mspnp/aks-baseline-regulated'
    k8sControlPlaneAuthorizationTenantId: 'cf36141c-ddd7-45a7-b073-111f66d0b30c'
    targetVnetResourceId: spoke.outputs.clusterVnetResourceId
  }
}
