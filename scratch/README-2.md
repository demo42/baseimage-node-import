# baseimage-node-import
Demonstrates how to import a public base image into a central registry, to decouple external dependencies

## Create A Public Node Image

Since we can't actually change the official node images, just for our demo, we'll create a simulated public node image that we'll update.

```sh
docker build -t stevelasker/node:9-alpine -f public-node-dockerfile .
docker push stevelasker/node:9-alpine
```

{{.Run.Registry}}/node:9-alpine
az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force

az acr run -r contosobaseimages --cmd "mcr.microsoft.com/azure-cli az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force" /dev/null

The resource with name 'contosobaseimages.azurecr.io' and type 'Microsoft.ContainerRegistry/registries' could not be found in subscription 'SteveLas-Internal (daae1e1a-63dc-454f-825d-b39289070f79)'.


az acr run -r contosobaseimages --cmd "echo hello" /dev/null




az acr task create --name simulate-public-node-test --registry contosobaseimages --file ./public-node-task.yaml --set USER=stevelasker --context https://github.com/demo42/baseimage-node-import.git --commit-trigger-enabled false --assign-identity

az acr task run --registry contosobaseimages -n simulate-public-node-test

- Create the task
```sh
az acr task create \
    --name simulate-public-node-test \
    --registry $REGISTRY_CENTRAL \
    --file ./public-node-task.yaml \
    --set USER=stevelasker \
    --context https://github.com/demo42/baseimage-node-import.git \
    --commit-trigger-enabled false \
    --assign-identity

az acr task create \
    --name public-node-staging-test \
    --registry $REGISTRY_CENTRAL \
    --file ./public-node-task.yaml \
    --set USER=$USER
    --context /dev/null \
    --assign-identity
```


- Get the principal ID, saving in vars, running a 4th command to configure
  Worse, is if you ever re-create or update the task, the below commands will need to be re-run, and likely get forgotten by users, until they remember the pain of not resetting

```sh
principalID=$(az acr task show --name import-node --registry contosobaseimages --query identity.principalId --output tsv)
registryID=$(az acr show --name contosobaseimages --query id --output tsv)
az role assignment create --assignee $principalID --scope $registryID --role contributor
```

az acr task run -r contosobaseimages -n import-node


"/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myUserAssignedIdentity"

az acr task run -r contosobaseimages -n import-node

az acr task credential add \
    --name import-node \
    --registry contosobaseimages \
    --login-server targetregistry.azurecr.io \
    --use-identity acrpush

ERROR: The resource with name 'contosobaseimages' and type 'Microsoft.ContainerRegistry/registries' could not be found in subscription 'SteveLas-Internal (daae1e1a-63dc-454f-825d-b39289070f79)'.

az acr run -r contosobaseimages --cmd "mcr.microsoft.com/azure-cli az login --identity && az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force" /dev/null

az acr task run -r contosobaseimages -n az-version
watch -n1 az acr task list-runs


az acr run -r contosobaseimages --cmd "mcr.microsoft.com/azure-cli az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force" /dev/null


