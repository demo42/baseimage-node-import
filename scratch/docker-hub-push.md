### Setup Environment Variables for Copy/Paste

  ```sh
  export USER=stevelasker
  export REGION=eastus
  export RESOURCE_GROUP=demo42
  export REGISTRY_CENTRAL=contosobaseimages
  export REGISTRY_DEV=contosodev
  export AKV_NAME=demo42
  export DOCKER_HUB_USER=stevelasker
  export DOCKER_HUB_TOKEN=[REPLACE-TOKEN-VALUE]
  ```

### Create Key Vault Entries

- For Docker Hub Credentials

  ```sh
  az keyvault create --resource-group $RESOURCE_GROUP --name $AKV_NAME
  az keyvault secret set \
  --vault-name $AKV_NAME \
  --name docker-hub-username \
  --value $DOCKER_HUB_USER

  az keyvault secret set \
  --vault-name $AKV_NAME \
  --name docker-hub-token \
  --value $DOCKER_HUB_TOKEN

  az keyvault secret set \
  --vault-name $AKV_NAME \
  --name github-token \
  --value $GITHUB_TOKEN
  ```

### Create a Docker Hub Base Image Repo

- Under your own org, create a new repository for node  
  ![](./media/create-base-image-docker-hub.png)

- Push/Pull the Node image to this repository

## Snippets

```sh
cd ./baseimage-node-import
docker build -t ${USER}/node:9-alpine -f public-node-dockerfile .
docker push ${USER}/node:9-alpine
```

```sh
$(az storage account show-connection-string \
               -n demo42${ENV_NAME}${LOCATION_TLA} \
               -g $RESOURCE_GROUP -o tsv)
```
