# Buffering Base Images - Decoupling Dependencies On External Resources

Buffering base images refers to decoupling your companies dependencies on externally managed images. For instance, images that source from public registries like: [docker hub](https://hub.docker.com), [gcr](https://cloud.google.com/container-registry/), [quay](https://quay.io), [github package registry](https://github.com/features/package-registry) or even other public [Azure Container Registries](https://aka.ms/acr).

Consider balancing these two, possibly conflicting goals:

- Do you really want an unexpected upstream change to possibly take out your production system?
- Do you want upstream security fixes, for the versions you depend upon, to be automatically deployed?

In this demo we'll:

- use [acr tasks](https://aka.ms/acr/tasks) to orchestrate an event driven flow
- pull base images from *docker hub*, into a corporate managed staging repository
- run unit tests on the staging repository
- if the unit tests pass, copy the image to company-wide base-images repository using [acr import](https://aka.ms/acr/import)
- once the base-images repo is updated, trigger rebuilds of the images that depend on this upstream change
- sit back, and watch magic happen - we hope

## Demo Setup

The following is required setup, prior to the actual demo

- Create a central registry, which will host the staging and corporate base images
  >NOTE: To enable updating of the public base image, we'll simulate a public image in this same central registry

- Create a development team registry, that will host one more more teams that build and manage images  
  > Note: [Repository based RBAC is coming this fall](https://aka.ms/acr/roadmap), enabling multiple teams to share a single registry, with unique permission sets

### Fork & Clone Repos

* https://github.com/demo42/baseimage-node-import


### Setup Environment Variables for Copy/Paste

  Populate these variables, for ease of snippets below
  ```sh
  export USER=stevelasker
  export REGION=eastus
  export RESOURCE_GROUP=demo42
  export REGISTRY_CENTRAL=contosobaseimages
  export REGISTRY_DEV=contosodev
  export AKV_NAME=demo42
  export GITHUB_TOKEN=[TOKEN]
  export GITHUB_REPO=https://github.com/demo42/baseimage-node-import.git
  ```

### Create Key Vault Entries

- GitHub Token secret

  ```sh
  az keyvault create --resource-group $RESOURCE_GROUP --name $AKV_NAME

  az keyvault secret set \
  --vault-name $AKV_NAME \
  --name github-token \
  --value $GITHUB_TOKEN
  ```

### Clone the forked repo

  ```sh
  git clone $GITHUB_REPO
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
    --git-access-token $(az keyvault secret show \
                         --vault-name $AKV_NAME \
                         --name github-token \
                         --query value -o tsv)

az acr task run -r $REGISTRY_CENTRAL --name simulated-public-node
```

### Demo Setup Verification

At this point you should have:

- Two registries (central for all images), (dev for your development teams)  

  ```sh
  az acr list -o table
  ```
  should return
  ```sh
  NAME               RESOURCE GROUP     LOCATION    SKU       LOGIN SERVER                  CREATION DATE         ADMIN ENABLED
  -----------------  -----------------  ----------  --------  ----------------------------  --------------------  ---------------
  contosobaseimages  demo42             eastus      Standard  contosobaseimages.azurecr.io  2019-10-08T19:38:39Z
  contosodev         demo42             eastus      Premium   contosodev.azurecr.io         2019-10-08T19:38:39Z
  ```

- An Azure Key Vault for storing secrets, and avoiding attendees from viewing your secrets

  ```sh
  az keyvault list -o table
  ```
  should return
  ```sh
  Location    Name                      ResourceGroup
  ----------  ------------------------  ------------------
  eastus      demo42                    demo42
  ```
- A simulated base image, you can update

  ```sh
  az acr repository list -n $REGISTRY_CENTRAL -o jsonc
  ```
  should return
  ```jsonc
  [
    "public/node",
    "staging/node"
  ]
  ```
## Demo Steps

> The following are the steps for the actual demo.

With our central and dev registries created, setup the workflow for importing, testing, promoting base images

### Automate Public Image Importing to a Staging Repository

In [import-node-staging-task.yaml](./import-node-staging-task.yaml) we do a build, but only to get the base image, tag and digest for tracking. Once the build is done, we use [az acr import](https://aka.ms/acr/import) to copy the *public* image to our staging repo. Since we only use the git repo to store our task.yaml, we don't actually trigger builds (imports) if content in the repository changes. (`--commit-trigger-enabled false`)  
   We do require an identity for the task, as [az acr import](https://aka.ms/acr/import) must first `az login --identity` in order to run import.

- Create a task.yaml, for the graph execution  
  View [import-node-staging-task.yaml](./import-node-staging-task.yaml) in VS Code
- Create an ACR Tasks to monitor the *public (simulated)* base image
  
  ```sh
  az acr task create \
      --name import-node-to-staging \
      --registry $REGISTRY_CENTRAL \
      --context https://github.com/demo42/baseimage-node-import.git \
      --file ./import-node-staging-task.yaml \
      --commit-trigger-enabled false \
      --set REGISTRY_CENTRAL=$REGISTRY_CENTRAL \
      --assign-identity
  ```

- Assign the identity of the task, access to the registry

  ```sh
  az role assignment create \
    --assignee $(az acr task show \
                  --name import-node-to-staging \
                  --registry $REGISTRY_CENTRAL \
                  --query identity.principalId \
                  --output tsv) \
    --scope $(az acr show \
              --name $REGISTRY_CENTRAL \
              --query id --output tsv) \
    --role contributor
  ```

  > Note: `--role contributor` See [Issue #281: acr import fails with acrpush role](https://github.com/Azure/acr/issues/281)  
  > Note: `az role assignment` See [Issue #283: az acr task create w/--use-identity to support role assignment](https://github.com/Azure/acr/issues/283) for incorporating the `az role assignment` into the task creation

- Manually run the task to start tracking the base image

  ```sh
  az acr task run -r $REGISTRY_CENTRAL --name import-node-to-staging
  ```

### Test Base Image Notifications, w/Importing to Staging

- Monitor base image updates of our `import-node-to-staging` task

```sh
watch -n1 az acr task list-runs
```

- Trigger a rebuild of the *public* base image  
  To ease context switching, change the [import-node-dockerfile](./import-node-dockerfile) directly in GitHub, commiting directly to master. This will trigger a base image change, which should trigger the `import-node-to-staging` task

- Once committed, you should see the `simulated-public-node` updating, with a trigger of `Commit`

  ```sh
  RUN ID    TASK                       PLATFORM    STATUS     TRIGGER       STARTED               DURATION
  --------  -------------------------  ----------  ---------  ------------  --------------------  ----------
  ca19      simulated-public-node      linux       Succeeded  Commit        2019-10-09T04:56:05Z  
  ```

- Once complete, `import-node-to-staging` should start, with a Trigger of `Image Update`

  ```sh
  RUN ID    TASK                       PLATFORM    STATUS     TRIGGER       STARTED               DURATION
  --------  -------------------------  ----------  ---------  ------------  --------------------  ----------
  ca1a      import-node-to-staging     linux       Running    Image Update  2019-10-09T04:56:21Z
  ```

### Checking In

At this point, we've successfully automated the importing of a base image to a registry under your control. If your connectivity to the public registry is down, your development & production systems will continue to function.
If you need to implement a security fix, rather than changing all the dev projects to point at a newly patched image, you can simply patch your own base image. Once the change is moved upstream, you can resume upstream changes being automatically migrated through your system.

## Adding Validation Testing to `staging\node`

Now that we've successfully automated the importing of a base image to our staging repo, we should run some tests to validate this image performs as we expect.
