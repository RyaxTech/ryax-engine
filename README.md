
<div align="center">

  <a href="https://ryax.tech">
    <img src="https://user-images.githubusercontent.com/104617518/167607288-537e67fb-bbd2-460a-b263-2e4c79b69196.png" alt="Logo" height="80">
  </a>
  <h3 align="center">Ryax</h3>

  <p align="center">
    Developers, build your backends in record time; deploy at scale with serverless technology; self-host, install on any cloud or use our hosted platform; Open source, low code.
    <br />
    <a href="https://docs.ryax.tech/"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://www.youtube.com/watch?v=PUVgu8lkNJI">View Demo</a>
    ·
    <a href="https://gitlab.com/ryax-tech/ryax/ryax-main/-/issues/new">Report Bug</a>
    ·
    <a href="https://gitlab.com/ryax-tech/ryax/ryax-main/-/issues/new">Request Feature</a>
    ·
    <a href="https://discord.gg/bg7s7Es8">Talk with the devs</a>
  </p>
</div>

**WARNING: We use GitLab for our development, if you want to see the whole application code see https://gitlab.com/ryax-tech/ryax/**

## ⭐ About the project

![screenshots](https://user-images.githubusercontent.com/104617518/167607552-44354081-c7d7-4f65-bc25-fca4aec65967.png)

Ryax is an open-source platform that streamlines the design, deployment, and
monitoring of Cloud automations and APIs.

## ⚙ The source code

Ryax is composed of multiple micro-services and tools. To learn more about the internal architecture, see [the documentation](https://docs.ryax.tech/reference/architecture.html). The main components are:

**User interfaces**
 - [cli](https://gitlab.com/ryax-tech/ryax/ryax-cli.git): The CLI to command Ryax
 - [front](https://gitlab.com/ryax-tech/ryax/ryax-front.git): The WebUI.
 - [adm](https://gitlab.com/ryax-tech/ryax/ryax-adm.git): The Ryax ADMinistrationn tool. To install, update, backup and more.

**Micro-services**
 - [authorization](https://gitlab.com/ryax-tech/ryax/ryax-authorization.git): Answer to the question: "do you have the rights to do so?".
 - [repository](https://gitlab.com/ryax-tech/ryax/ryax-repository.git): Scan git repositories to find actions.
 - [runner](https://gitlab.com/ryax-tech/ryax/ryax-runner.git): A trigger or an action run? It handles it.
 - [studio](https://gitlab.com/ryax-tech/ryax/ryax-studio.git): Handles the edition of workflows.
 - [action-builder](https://gitlab.com/ryax-tech/ryax/ryax-action-builder.git): Builds actions and triggers.
 - [ryax-action-wrappers](https://gitlab.com/ryax-tech/ryax/ryax-action-wrappers.git): The code between the action code and Ryax.

**Other**
 - [default-actions](https://gitlab.com/ryax-tech/workflows/default-actions.git): Some open-source actions and triggers.
 - [errored-actions](https://gitlab.com/ryax-tech/ryax/errored-actions.git): Actions with errors, very useful to test the robustness of Ryax.
 - [common-helm-charts](https://gitlab.com/ryax-tech/ryax/common-helm-charts): Set of common templates for Ryax services library charts

**Main technologies used by Ryax**

The code: **[Python](https://www.python.org/)**, [dependency-injector](https://python-dependency-injector.ets-labs.org/index.html), [SQLalchemy](https://docs.sqlalchemy.org), [GRPC](https://grpc.io/).

Around the code: [Nix](nixos.org/), [poetry](https://python-poetry.org/), [black](https://black.readthedocs.io/en/stable/), [mypy](https://mypy.readthedocs.io/).

Deploying Ryax: [Kubernetes](https://kubernetes.io/), [Terraform](https://www.terraform.io/), [Helm](https://helm.sh/).


## ⚡ Getting started with Ryax

### Requirements

All you need to install Ryax is a Kubernetes cluster. Supported versions are:

* kubernetes > 1.19; <1.25

Hardware:

* At least 2 CPU core
* 4GB or memory
* 40GB of disk available

Note that depending on the Actions that you run on your cluster you might need
more resources.


### On a local machine

We recommend this option if you wish to test our product with a minimal amount of configuration steps, and if you have enough RAM (~3GB) available.

You need the following dependencies :
- Python 3.9+
- [Helm](https://helm.sh/)
- [Helmfile](https://github.com/roboll/helmfile)
- [Helm-diff](https://github.com/databus23/helm-diff) plugin: `helm plugin add https://github.com/databus23/helm-diff`
- [Poetry](https://python-poetry.org/)
- [Kind](https://github.com/kubernetes-sigs/kind)

Once these are available on your machine:

1) Clone [ryax-adm](https://gitlab.com/ryax-tech/ryax/ryax-adm/) and
  `cd` into the repo's root.
2) Generate a virtual environment for python
```bash
poetry install
```
3) Activate this virtual environment
```bash
poetry shell
```
4) Run `./local_ryax/local-ryax.sh` to deploy a Ryax instance on
  your machine with `kind`. It takes a while.
5) Connect to `http://localhost` on your web browser, default credentials are
user1/pass1.

**/!\ Warning** To make it easier for you to access the cluster from your
browser, we expose the ports 80 (http) and 443 (https) on your local machine.
Make sure these aren't already used!

### On an existing Kubernetes cluster

This is the standard and recommended approach.
It works on most managed Kubernetes, like AWS EKS, Azure AKS, GCP GKE.

There are two ways of running ryax-adm, our administration tool.

Using poetry shell :

```{bash}
# Clone ryax-adm
git clone https://gitlab.com/ryax-tech/ryax/ryax-adm/
cd ryax-adm

# Generate ryax-adm's virtual environment
poetry install

# Activate it
poetry shell
ryax-adm --help
```

Inside a container :

```{bash}
# Create a folder to pass down the kubeconfig.
TMP_RYAX=$(mktemp -d)
cp $KUBECONFIG $TMP_RYAX

# Tweak their permissions so it's accessible in the container
sudo chown -R 1200 $TMP_RYAX

# Run the container interactively.
docker run -v $TMP_RYAX:/data/volume -e KUBECONFIG=/data/volume/$(basename $KUBECONFIG) --entrypoint /bin/sh -ti ryaxtech/ryax-adm
ryax-adm --help
```

Once you are logged to your cluster, you are ready to install Ryax.

1) Get a basic configuration for your new cluster
```bash
ryax-adm init
```
2) Edit the configuration file to set the [https://github.com/RyaxTech/ryax/releases](latest Ryax release) version and your
cluster name:
```bash
vim ryax_values.yaml # Or your favorite text editor
```
3) Install Ryax:
```bash
ryax-adm apply --values ryax_values.yaml --suppress-diff
```
4) Get the external IP of Ryax, and connect to it on your browser:
```bash
kubectl -n kube-system get svc traefik
```

For more details on the configuration, see [our documentation](https://docs.ryax.tech/howto/install_ryax_kubernetes.html).


## 🛹 Roadmap

A more complete roadmap will be published soon.

- [x] Create workflows
- [x] Support actions and triggers made in python
- [x] User and project management
- [x] Create HTTP API with Ryax
- [ ] Manage credentials for the integrations
- [ ] Integrate a data store for users
- [ ] Support actions and triggers made in javascript

## 🤗 Contributing

If you want to say thank you and/or support the active development of Ryax:

1. Add a [GitHub Star](https://github.com/RyaxTech/ryax/) to the project.
2. Tweet about the project on your Twitter.
3. Write a review or tutorial on Medium, Dev.to or personal blog.
4. Share some triggers and actions with the [community](https://discord.gg/bg7s7Es8).
5. Fix bugs and implement features to [our code](https://gitlab.com/ryax-tech/ryax/ryax-main).


[Discord](https://discord.gg/bg7s7Es8),
[Reddit](https://www.reddit.com/r/ryax/),
[Slack](https://join.slack.com/t/ryax/shared_invite/zt-fjx7pud0-GAYiNrDEa1hHyArs5etMiA)
