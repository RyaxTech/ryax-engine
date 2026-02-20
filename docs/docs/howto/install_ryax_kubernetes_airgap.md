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

- [ryax-airgap -helm-values](https://raw.githubusercontent.com/RyaxTech/ryax-engine/refs/heads/master/airgap/ryax-airgap-helm-values.yaml)
- [minimal.yaml](https://raw.githubusercontent.com/RyaxTech/ryax-engine/refs/heads/master/chart/env/minimal.yaml) 

### Generate the list of dependencies for the builder

For this step, you need a machine with the same architecture of the targeted cluster, and the package manager nix installed.

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

> Other Ryax actions that might interest you depending on your use case are available in https://gitlab.com/ryax-tech/workflows 
{.is-info}

If you don't have a git server accessible withing the airgap installation, you can directly copy the repository into the ryax-repository pod with `kubectl cp`.

```bash
# Find the name of the ryax-repository pod
$ kubectl -n ryaxns get pod  | grep repository
ryax-repository-97c5554db-jzhdp

# Create an archive for the repogit (assuming the repo containing the actions is names default-actions)
tar cvf default-actions.tar default-actions

# Inject the action repository into /tmp
kubectl cp default-actions.tar -n ryaxns ryax-repository-97c5554db-jzhdp:/tmp/

# Use kubectl exec to untar the copied repository inside the pod
```

<!--
I (adfaure) tested without success:

**Only if you do not have a local Git server** you can inject the actions repository directly into the Ryax Repository service. For example, you import the default action git repository in your `/home/example/myrepos` on the hosting node of your Ryax installation and expose it with a `hostPath` in the `ryax-repository` service using these options in the helm values:
```yaml
repository:
	extraVolumes:
	- name: repos 
  	hostPath:
    	path: /home/example/myrepos
    	type: DirectoryOrCreate
	extraVolumeMounts:
	- mountPath: /data/repos
 		name: repos
```
-->

Now in the web UI Library, create a new repository with this URL: `file:///tmp/default-action`. You can run a scan and see the available actions.

### Build Actions

In order to build Ryax actions, the Ryax Action Builder requires an access to external mirror for Python packages and Nix packages.

Pypi mirror:

- [Morgan](https://github.com/ido50/morgan) open source offline 
- [Nexus](https://www.sonatype.com/products/sonatype-nexus-repository) a popular proprietary tool to host packages
Nixpkgs mirror:
- [nix serve](https://github.com/edolstra/nix-serve) a basic nix binary cache server
- [Attic](https://github.com/zhaofengli/attic) more advanced


#### Nix Build dependencies bundle

Transfert the bundle into the airgapped environment, and inject the bundle into the action builder local store with:
```shell
nix-store --import < ryax-build-deps.nixexport
```

## Offline Updates

!!! warning
    Updates may require some extra steps, be sure that you have read the [release note](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/releases) before proceeding.

To trigger an update of Ryax in n offline environment, you  can reuse the installation process to create new airgapped bundle and then inject the images and run the helm upgrade command:
```sh
sudo k3s ctr images import ./ryax-airgap-images-amd64.tar.gz
helm upgrade --install ryax ./ryax-engine-*.tgz -n ryaxns --reuse-values
```

### With a private registry

You'll also need to have a private registry that can host both container images and Helm charts.
Example tools:

- [Hauler](https://github.com/hauler-dev/hauler)
- [Harbor](https://goharbor.io/)

TODO: explain how to overrride image repo with k3s mirror or helm chart override

