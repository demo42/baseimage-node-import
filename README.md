# baseimage-node-import
Demonstrates how to import a public base image into a central registry, to decouple external dependencies



{{.Run.Registry}}/node:9-alpine
az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force

az acr run -r contosobaseimages --cmd "mcr.microsoft.com/azure-cli az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force" /dev/null

The resource with name 'contosobaseimages.azurecr.io' and type 'Microsoft.ContainerRegistry/registries' could not be found in subscription 'SteveLas-Internal (daae1e1a-63dc-454f-825d-b39289070f79)'.


az acr run -r contosobaseimages --cmd "mcr.microsoft.com/azure-cli az --version" /dev/null

az acr task create \
    --image hello-world:{{.Run.ID}} \
    --name hello-world \
    --registry contosobaseimages \
    --context https://github.com/Azure-Samples/acr-build-helloworld-node.git \
    --file Dockerfile \
    --assign-identity


az acr task create \
    --cmd "mcr.microsoft.com/azure-cli az --version" \
    --name az-version-no-auth \
    --registry contosobaseimages \
    --context /dev/null 

az acr task run -r contosobaseimages -n az-version-no-auth

az acr task create \
    --cmd "mcr.microsoft.com/azure-cli az --version" \
    --name az-version-no-auth \
    --registry contosobaseimages \
    --context /dev/null \
    --assign-identity

az acr task create \
    --cmd "mcr.microsoft.com/azure-cli az login --identity && az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force" \
    --name import-node \
    --registry contosobaseimages \
    --context /dev/null \
    --assign-identity

az acr task run -r contosobaseimages -n import-node

az acr task create \
    -f tasks.yaml \
    --name import-node \
    --registry contosobaseimages \
    --context /dev/null \
    --assign-identity

az acr task create -f tasks.yaml --name import-node --registry contosobaseimages --context /dev/null --assign-identity


az acr run -r contosobaseimages --cmd "mcr.microsoft.com/azure-cli az login --identity && az acr import --name contosobaseimages --source docker.io/library/node:9-alpine -t staging/node:9-alpine --force" /dev/null

az acr task run -r contosobaseimages -n az-version
