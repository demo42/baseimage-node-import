# Buffering Base Images - Decoupling Dependencies On External Resources

Buffering base images refers to decoupling your compaines dependencies on externally managed images. For instance, images that source from public registries like: [docker hub](https://hub.docker.com), [gcr](https://cloud.google.com/container-registry/), [quay](https://quay.io), [github package registry](https://github.com/features/package-registry) or even other public [Azure Container Registries](https://aka.ms/acr). 

In this demo we'll:

- use [acr tasks](https://aka.ms/acr/tasks) to orchestrate an event driven flow
- pull base images from docker hub, into a corporate managed staging repository
- run unit tests on the staging repository
- if the unit tests pass, copy the image to the corporate base-images repository using [acr import](https://aka.ms/acr/import)

## Demo Setup

The following is required setup, prior to the actual demo

- Create a Docker Hub repo, that will simulate a public base image
- Create a corporate registry, which will host the staging and corporate base images
- Create a development team registry, that will host one more more teams that build and manage images  
  Note: Repository based RBAC is coming this fall, enabling multiple teams to share a single registry, with unique permission sets

### Clone Repos

```sh
git clone https://github.com/demo42/baseimage-node-import.git
```

### Setup Environment Variables for Copy/Paste

  ```sh
  export USER=stevelasker
  export REGION=eastus
  export RESOURCE_GROUP=demo42
  export REGISTRY_CENTRAL=contosobaseimages
  export REGISTRY_DEV=contosodev
  export AKV_NAME=demo42
  ```

### Create a Central Base Image ACR

Regardless of the size of the company, you'll likely want to have a separate registry for managing base images. While it's possible to share a registry with multiple development teams, it's difficult to know how each team may work, possibly requiring VNet features, or other registry specific capabilities. To avoid future registry migration, we'll assume a separate registry for these centrally managed base images.

- Create Azure Container Registries  
  With environment variables set, create two registries. Note, the central registry is a Standard SKU as it doesn't require advanced configurations. The Dev registry will be put in a VNet, requiring the Premium SKU.
  > Note: consumption based tier is coming, easing these choices. 

```sh
az group create --name $RESOURCE_GROUP --location $REGION
az acr create --resource-group $RESOURCE_GROUP --name $REGISTRY_CENTRAL --sku Standard
az acr create --resource-group $RESOURCE_GROUP --name $REGISTRY_DEV --sku Premium
```

### Create a Simulated Public Image

Normally, this step wouldn't be needed as you would create a buffered image directly from the official node image. However, in this demo, we want to show what happens when the "official" node image is updated. Since we can't, or shouldn't update the official node image, just for us, we'll create a simulated `public/node:9-alpine` image.

While we could put the image on our personal `docker.io/[user]/node` repository, ACR Task base image notifications from Docker Hub have a random value between 10 and 60 minutes, making it hard to see changes quickly. Tasks base image notifications from Azure Container Registries are event driven, making them near immediate, and easy to demo.

To simulate a public image, we'll simply push the node image to `[registry].azurecr.io/public/node:9-alpine`. As with any cloud-naive experience, we'll automate this with an ACR Task.

- Push/Pull the Node image to this repository

```sh
az acr task create \
    --name simulated-public-node \
    --image public/node:9-alpine \
    --registry $REGISTRY_CENTRAL \
    --file ./public-node-dockerfile \
    --context https://github.com/demo42/baseimage-node-import.git \
    --commit-trigger-enabled false

az acr task run -r $REGISTRY_CENTRAL --name simulated-public-node
```

## Demo Steps

> The following are the steps for the actual demo.

With our central and dev registries created, setup the workflow for importing, testing, promoting base images

### Automate Public Image Importing to a Staging Repository

- Create an ACR Tasks to monitor the *public (simulated)* base image

```sh
az acr task create \
    --name import-node-to-staging \
    --registry $REGISTRY_CENTRAL \
    --file ./public-node-task.yaml \
    --set USER=$USER \
    --set AKV_NAME=$AKV_NAME \
    --set REGISTRY_CENTRAL=$REGISTRY_CENTRAL \
    --context https://github.com/demo42/baseimage-node-import.git \
    --commit-trigger-enabled false \
    --assign-identity
```

- A task that:
  - builds the image, to enable base image tracking
  - az login, so the az acr import has context (*actually, I shouldn't have to do this if the task as an identity*)
  - imports the source image, from docker hub using az acr import