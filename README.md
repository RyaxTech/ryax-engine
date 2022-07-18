
<div align="center">

  <a href="https://ryax.tech">
    <img src="https://user-images.githubusercontent.com/104617518/167607288-537e67fb-bbd2-460a-b263-2e4c79b69196.png" alt="Logo" height="80">
  </a>
  <h3 align="center">Ryax</h3>

  <p align="center">
    Ryax is an open-source platform that streamlines the design, deployment, and monitoring of Cloud automations and APIs.
    <br />
    <a href="https://docs.ryax.tech/"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://youtu.be/IL40ruhuDUI">View Demo</a>
    ·
    <a href="https://gitlab.com/ryax-tech/dev/ryax/-/issues">Report Bug</a>
    ·
    <a href="https://gitlab.com/ryax-tech/dev/ryax/-/issues">Request Feature</a>
  </p>
</div>

## ⭐ About the project

![screenshots](https://user-images.githubusercontent.com/104617518/167607552-44354081-c7d7-4f65-bc25-fca4aec65967.png)

Ryax is an open-source platform that streamlines the design, deployment, and
monitoring of Cloud automations and APIs.

## ⚙ Built With

The code:

- [Python](https://www.python.org/)
- [dependency-injector](https://python-dependency-injector.ets-labs.org/index.html)
- [SQLalchemy](https://docs.sqlalchemy.org)
- [GRPC](https://grpc.io/)

Around the code:

- [Nix](nixos.org/)
- [poetry](https://python-poetry.org/)
- [black](https://black.readthedocs.io/en/stable/)
- [mypy](https://mypy.readthedocs.io/)

Deploying Ryax:

- [Kubernetes](https://kubernetes.io/)
- [Terraform](https://www.terraform.io/)
- [Helm](https://helm.sh/)

## Getting started with Ryax

We describe here two possible ways to install Ryax.

**On your local machine** : We recommend this option if you wish to test our
product with a minimal amount of configuration steps. You will have to install
a few dependencies.

**On a Kubernetes cluster** : This is the standard and recommended approach. We
recommend this option if you have an available cluster on your hands or if you
want a longer lasting installation for your production needs.

### On a local machine

You will need the following dependencies :

- [Helm](https://helm.sh/)
- [Helmfile](https://github.com/roboll/helmfile)
- [Poetry](https://python-poetry.org/) (Or `nix-shell`, although poetry is
  substantially faster)
- [Kind](https://github.com/kubernetes-sigs/kind)

Once these are available on your machine, follow these steps to run a local
Ryax instance.

- Clone [ryax-adm](https://gitlab.com/ryax-tech/ryax/ryax-adm/) somewhere and
  `cd` into it.
- Run `poetry install` to generate a virtual environment for python.
- Run `poetry shell` to activate the virtual environment. These last two steps
  can also be replaced by `nix-shell`, although this one can take a while.
- Run `./adm/local_ryax/local-ryax.sh`. This will deploy a Ryax instance on
  your machine with `kind`.
- Connect to `localhost` on your navigator and *voilà*.

**/!\ Warning** Kind runs a kubernetes instance in a docker container on your
machine, which will expose the NodePorts of the cluster. This may conflict with
ports that would be already used on your machine.

TODO write how to know which ports are exposed. (Or test a conflict situation)

### On an existing kube cluster

#### Preparatory steps on the cluster

- Make sure you're on the intended cluster : `kubectl config current-context`
- Make sure it's empty. Ryax may or may not function properly alongside
other installations, as some cluster wide resources may collide with one
another (CRDs, for instance). It is preffered that Ryax gets its own
cluster to ensure a trouble free installation so if you do not wish to set
up a brand new cluster for Ryax, check out <link to the section for a
local install>.
- Make sure you have got complete admin access to the cluster. You will have
to create namespaces and some cluster resources. Try to run `kubectl auth
can-i create ns` or `kubectl auth can-i create pc`, for instance.

#### Customize your installation

Installing Ryax is very much analogous to installing a Helm chart. To get
you started we will use a default configuration and tweak one thing or two
so that everything is compatible with your kube provider, but be assured
that you will be able to fine tune your installation later on.

Just like helm charts, we call "values" the configuration of a Ryax
cluster.

TODO init values. These have to be minimal. Edit : instance url, storage
classes (give the name of the default ones for aws, azure, gcp), pvc sizes
(give minimal amount so that it works, state that it's better to start small
because you can't shrink them in kubernetes)

```{bash}
```

TODO edit

#### Install Ryax

TODO apply values

```{bash}
```

#### Configure your dns

TODO how to retrieve traefik external IP

## 🛹 Roadmap

A more complete roadmap will be published soon.

- [x] Create workflows
- [x] Support actions and triggers made in python
- [x] User and project management
- [ ] Create HTTP API
- [ ] Support actions and triggers made in javascript

## 🤗 Contributing

The code will be published soon, if you want a beta access, contact us!

[Discord](https://discord.gg/bg7s7Es8),
[Reddit](https://www.reddit.com/r/ryax/),
[Slack](https://join.slack.com/t/ryax/shared_invite/zt-fjx7pud0-GAYiNrDEa1hHyArs5etMiA)
