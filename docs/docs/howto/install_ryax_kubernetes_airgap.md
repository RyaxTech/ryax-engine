# Install and Configure Ryax for Offline environment

!!! warning
    If you are looking for **Proxy based installation**
    Setup proxy to download containers and helm charts. To enable image pull from the proxy see the [K3s proxy doc](https://docs.k3s.io/advanced#configuring-an-http-proxy).

## Requirements

A kubernetes installed and running following the [Ryax requirements](https://docs.ryax.tech/howto/install_ryax_kubernetes.html#requirements).

If you don't have an airgapped kubernetes environment, we propose to use k3s inside a virutal machine, and disconnect it from internet. K3s features an airgap installation procedure that you can follow: [Air-Gap installation](https://docs.k3s.io/installation/airgap).

A machine with an internet connection, the same architecture as the airgap environment, and the package manager [nix](https://nixos.org/) installed.

## Configuration

The first step, is to gather all the files needed by the installation of ryax airgap. Namely:

- The ryax helm package (ryax-engine-{ryax-version}.tgz) that will be installed on the airgapped kubernetes cluster.
- The list of container images containing ryax code (ryax-airgap-images-amd64.tar.gz).
- The value files necessary to configure Ryax for airgap environment:
    - minimal.yaml (the two last files are value file for the helm installation command);
    - ryax-airgap-helm-values.yaml.
- The closure of nix packages to build actions.

<!-- *We propose the a simple Ryax config for a k3s environement already package for you in the release page **(TODO)**.* -->

### Generate the package helm and the archive containing the folder

To be able to install Ryax in an offline environment, you first need to create a package containing all container images and Helm charts required for your setup.

Optionaly, you can create your Ryax configuration following the Ryax install documentation and run the package generation script on top of it to capture all containers required.

To do so, you will need a set of script to create a list of images a generate all you need.

```bash
git clone https://gitlab.com/ryax-tech/ryax/ryax-engine
cd ryax-engine && git submodule update --init
./airgap/create-airgap-package.sh
```

This script creates two file, one containing the images necessary to run ryax, and the helm package required for the installation. Additionnaly, you need to copy the two following file for your aigap installation:

- [ryax-airgap-helm-values](https://raw.githubusercontent.com/RyaxTech/ryax-engine/refs/heads/master/airgap/ryax-airgap-helm-values.yaml)
- [minimal.yaml](https://raw.githubusercontent.com/RyaxTech/ryax-engine/refs/heads/master/chart/env/minimal.yaml) 

### Generate the list of dependencies for the builder

For this step, you need a machine **with the same architecture of the targeted cluster**, and the package manager nix installed.

First you need to clone the repository [ryax-wrappers](https://gitlab.com/ryax-tech/ryax/ryax-action-wrappers).
For airgapped environment, you can pre-build and package all build dependencies with:

```bash
# Build or download all dependencies
nix build .\#ryaxBuild.buildDeps --impure
# list all dependencies
nix-store --query --requisites ./result
# create a closure binary bundle
nix-store --export $(nix-store --query --requisites ./result) > ryax-build-deps.nixexport
```

After this step, you should have a new file named `ryax-build-deps.nixexport` that is required for the airgap ryax installation.

## Installation

On the offline k3s cluster, you need to import the images and run the installation with Helm.
```sh
# Import the images in the k3s cluster
sudo k3s ctr images import ./ryax-airgap-images-amd64.tar.gz
helm install ryax ./ryax-engine-*.tgz -n ryaxns --create-namespace -f ./minimal.yaml -f ./ryax-airgap-helm-values.yaml
```

!!! warning
    If you don't use k3s you need to manually import the images or setup an internal registry.

## Post-install: Configure the Running Cluster

### Action Repository Import

Ryax gets Action definitions from Git repositories. To inject Ryax default actions you can **use a locally accessible Git server** where you can clone https://gitlab.com/ryax-tech/workflows/default-actions.git

!!! info
    Other Ryax actions that might interest you depending on your use case are available in https://gitlab.com/ryax-tech/workflows 

**If you have a git server accessible withing the airgap installation, you can directly go to following section.**

If you don't have a git server, you can directly copy the repository into the ryax-repository pod with `kubectl cp`.

```bash
# Find the name of the ryax-repository pod
REPOSITORY_POD=$(kubectl -n ryaxns get pod -l ryax.tech/resource-name=repository -o jsonpath='{.items[0].metadata.name}')

# Inject the action repository into /tmp
kubectl cp default-actions -n ryaxns ${REPOSITORY_POD}:/tmp/

# Use kubectl exec to check the content of the copied repository inside the pod
kubectl exec -ti -n ryaxns ${REPOSITORY_POD} -- ls /tmp/default-actions
```

Now in the web UI Library, create a new repository with this URL: `file:///tmp/default-action`. You can run a scan and see the available actions.

### Build Actions

In order to build Ryax actions, the Ryax Action Builder requires an access to software packages inside you airgapped environment.
Depending on the action type you use you need to configure package servers and/or import packages in the Builder

You can configure the build using environement variables in the Builder: All variables prefixed by `RYAX_BUILD_ENV_` are exposed during the build phase.

!!! warning
    The support of action build in airgapped is in **TECHNOLOGICAL PREVIEW**.
    Only the `python3` action type is supported for now.
    You can follow the futur developement here: https://gitlab.com/groups/ryax-tech/ryax/-/epics/33
    

#### Python packages

To support python packages, the builder need to access to a Pypi compatible server.
If don't have one in your environment, here is examples of tools that you can install :

- [pypiserver](https://github.com/pypiserver/pypiserver) minimal pypi server 
- [Morgan](https://github.com/ido50/morgan) open source offline repo
- [Nexus](https://www.sonatype.com/products/sonatype-nexus-repository) a popular proprietary tool to host packages

To use your internal Pypi server, you need to configure the following env variable in the Ryax action builder.
In the Helm chart add the extra env in the `action-builder` section (Change with your server host name):
```yaml
action-builder:
  extraEnv:
    - name: RYAX_BUILD_ENV_UV_INDEX_URL
      value: http://mypipy-server.example.com
    - name: RYAX_BUILD_ENV_UV_TRUSTED_HOST
      value: mypipy-server.example.com
    - name: RYAX_EXTRA_NIX_ARGS
      value: --no-net
```

### Nix packages

To have access to Nix packages inside you airgapped environment you can either use an internal package binary cache or import packages directly in the Builder

#### Using a binary cache:

Install a Nix Binary cache, for example:

- [nix serve](https://github.com/edolstra/nix-serve) a basic nix binary cache server
- [Attic](https://github.com/zhaofengli/attic) more advanced with access rights and storage optimisation

Then configure the Builder to use it as a substituer (Change with server host name): 
```yaml
action-builder:
  extraEnv:
    - name: RYAX_EXTRA_NIX_ARGS
      value: --option substituters my-nix-cache.example.com
```

Now you need to inject, in you cache the bundle created at the end of the configuration step: `ryax-build-deps.nixexport`

#### Inject packages in the Builder

!!! info
   If you have Nix binary cache you can directly import the packages created in the configuration step, and skip the following

If you don't have a server, you can directly import packages into the Ryax Action Builder Nix store with `kubectl cp`.

Transfert the bundle into the airgapped environment, and inject the bundle into the action builder local store with:
```bash
# Find the name of the pod
BUILDER_POD=$(kubectl -n ryaxns get pod -l ryax.tech/resource-name=action-builder -o jsonpath='{.items[0].metadata.name}')

# Inject the nix bundle into the builder
kubectl exec -ti -n ryaxns ${BUILDER_POD} -- nix-store --import < ryax-build-deps.nixexport
```

!!! tip
    If you need extra packages for actions that define `spec.dependencies` in the `ryax_metadata.yaml` create a bundle and import it using the same process:
    ```bash
    # build something and get a ./result link
    # then export it with its dependencies
    nix-store --export $(nix-store --query --requisites ./result) > action-deps.nixexport
    # copy it into the builder and run
    nix-store --import < action-deps.nixexport
    ```

## Offline Updates

!!! warning
    Updates may require some extra steps, be sure that you have read the [release note](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/releases) before proceeding.

To trigger an update of Ryax in n offline environment, you  can reuse the installation process to create new airgapped bundle and then inject the images and run the helm upgrade command:
```sh
sudo k3s ctr images import ./ryax-airgap-images-amd64.tar.gz
helm upgrade --install ryax ./ryax-engine-*.tgz -n ryaxns --reuse-values
```
Don't forget to update Nix build dependencies with the process defined in the configuration.

<!-- ### With a private registry

You'll also need to have a private registry that can host both container images and Helm charts.
Example tools:
- [Hauler](https://github.com/hauler-dev/hauler)
- [Harbor](https://goharbor.io/)
TODO: explain how to overrride image repo with k3s mirror or helm chart override -->

