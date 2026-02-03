# Ryax versus other similar tools

Ryax is flexible and can be applied to many different problems, from simple side projects to the entirety of a company's backend software application.

Thus, several tools on the market have overlapping capabilities to those of Ryax. Here we will compare Ryax to a number of tools to better situate it in the tech landscape.

## Homemade tools

Companies often internally develop their tools when starting to take on a backend software project.

This typically starts with a simple script and then evolves into a larger solution. These hand-made approaches are error-prone and become hard to maintain when the need for automation grows. Going into production requires much more than a simple script, a data science workflow for example has to be continuously developed, monitored, debugged and updated.

Ryax is doing exactly this; taking care of the entire pipeline life-cycle and allowing users to focus on their projects and spend more time on their use-case.

## Airflow

Airflow is an open-source platform that can trigger code at some given time window. It is sometimes referred to as the "Cron 2.0".
Airflow differs from Ryax in 3 main areas, namely:

- **Airflow's workflows are dynamic**: a workflow step ('action' in Ryax) may produce some other steps during runtime, while Ryax workflows are defined beforehand and will not change their definitions unexpectedly. The dynamically-defined Airflow workflows offer more flexibility, but are intrinsically harder to debug which greatly limits their robustness, and introduces a steep and time-consuming learning curve to achieve a robust workflow.
- **Airflow's workflows can only be triggered at given interval times**: Ryax on the other hand supports any kind of trigger; time-based, manual, API endpoint, chat messages, emails, webhooks, etc. Flexibility is key.
- **Airflow's workflows are defined through code**: Ryax does not require users to learn new languages and provides an intuitive user interface with which users can jump into right away with drag and drops, clicks, and manual text entry.

## Container orchestrators (Kubernetes, Mesos, Docker Swarm, etc).

Kubernetes is a general-purpose container orchestrator made for any workload that a Data Center might encounter. It attracts a lot of attention, has an army of contributors, and is currently becoming an industry standard for running web applications and services.

Ryax is a much more specific tool that focuses on backend software. Ryax is built on top of Kubernetes and leverages it to manage users workflow deployments. Therefore, Ryax can be considered as a kind of orchestrator, but one that only focuses on running backend code.

## Automation Tools (Zapier, IFTTT, etc).

Automation tools are designed to provide a simple way to automate interactions between separated tools. These event-based platforms have a lot of integrations with external services and can trigger the execution of a pipeline upon many different types of events.

While Ryax is also able to automate this kind of interaction it further provides features dedicated to the creation of backends, like the ability to create APIs.

Putting a backend in production means automating the execution of your code. Behind this also comes all packaging, building, distributing, connecting, orchestrating, and monitoring. Ryax does it all for free :-).
