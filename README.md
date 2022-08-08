
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
    <a href="https://gitlab.com/ryax-tech/ryax/ryax-main/-/issues/new">Report Bug</a>
    ·
    <a href="https://gitlab.com/ryax-tech/ryax/ryax-main/-/issues/new">Request Feature</a>
    ·
    <a href="https://discord.gg/bg7s7Es8">Talk with the devs</a>
  </p>
</div>



## ⭐ About the project

![screenshots](https://user-images.githubusercontent.com/104617518/167607552-44354081-c7d7-4f65-bc25-fca4aec65967.png)

Ryax is an open-source platform that streamlines the design, deployment, and monitoring of Cloud automations and APIs.


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




## 🛹 Roadmap

A more complete roadmap will be published soon.

- [x] Create workflows
- [x] Support actions and triggers made in python
- [x] User and project management
- [ ] Create HTTP API
- [ ] Support actions and triggers made in javascript



## 🤗 Contributing

If you want to say thank you and/or support the active development of Ryax:

1. Add a [GitHub Star](https://github.com/RyaxTech/ryax/) to the project.
2. Tweet about the project on your Twitter.
3. Write a review or tutorial on Medium, Dev.to or personal blog.
4. Share some triggers and actions with the [community](https://discord.gg/bg7s7Es8).
5. Fix bugs and implement features to [our code](https://gitlab.com/ryax-tech/ryax/ryax-main).


[Discord](https://discord.gg/bg7s7Es8), [Reddit](https://www.reddit.com/r/ryax/), [Slack](https://join.slack.com/t/ryax/shared_invite/zt-fjx7pud0-GAYiNrDEa1hHyArs5etMiA)
