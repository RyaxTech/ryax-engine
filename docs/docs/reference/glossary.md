# Glossary


[Workflow](#workflow) runs start with a [trigger](#trigger), which listens for external events or user inputs  (API calls, messages, database updates, etc). Then, the rest of the [actions](#action) in the [workflow](#workflow) can run in their defined order.

A [workflow](#workflow) is composed of a [trigger](#trigger) and 1 or more [actions](#action). The [trigger](#trigger) starts a new [run](#run). Each [action](#action) is executed according to the workflow configuration.

[Triggers](#trigger) and [actions](#action) are configured using [inputs](#io). [Inputs](#io) are typed and can either be defined statically by the users by typing in a desired value. Alternatively, input values can be defined to take the [output](#io) value of one of the upstream [actions](#action), or the [trigger](#trigger) (as long as the output value and input value are of the same type).

A [workflow](#workflow) has to be [deployed](#deploy) to start new [runs](#run).

You can import new [triggers](#trigger) and [actions](#action) from the [library](#modulelibrary) menu. Ryax can be connected to [git repositories](#repo) to import new [actions](#action). Ryax scans the [git repository](#repo) to be able to build them ; once done, the [action](#action) is imported in Ryax and can be used in your [workflow](#workflow)!




<dl>

<dt><a name="use-case"></a><strong>
        Use case
</strong></dt>
<dd>

Every use-case is a set of [workflows](#workflow) answering specific business objectives

</dd>
<dt><a name="workflow"></a><strong>
        Workflow
</strong></dt>
<dd>

A [trigger](#trigger) and a set of [actions](#action) linked to each other.

</dd>
<dt><a name="deploy"></a><strong>
        Deploy & Undeploy
</strong></dt>
<dd>

When a workflow is deployed, its trigger is running, some [runs](#run) may be created.

</dd>
<dt><a name="action"></a><strong>
        Action
</strong></dt>
<dd>

A specific step of a defined worklfow. Actions that start a workflow are called [trigger](#trigger).
See [Workflows, Actions, and runs](../concepts/concepts) for more details.

</dd>
<dt><a name="trigger"></a><strong>
        Trigger
</strong></dt>
<dd>

Modules that ingest events and data from the outside world. They are long-running processes triggering new workflow runs.

</dd>
<dt><a name="io"></a><strong>
        Inputs and outputs
</strong></dt>
<dd>

Actions have inputs and outputs, they are the data flowing in and out of the actions.

</dd>
<dt><a name="modulelibrary"></a><strong>
        Module library
</strong></dt>
<dd>

Find all actions of your Ryax instance in the module library.

</dd>
<dt><a name="project"></a><strong>
        Project
</strong></dt>
<dd>

A set of isolated actions, triggers, workflows, users, repositories, and runs. Use projects to split workflows across your teams!

</dd>
<dt><a name="action_run"></a><strong>
        Action Run
</strong></dt>
<dd>

When an action recieve some inputs, it is executed to generate some outputs. We call this, an action run.

</dd>
<dt><a name="run"></a><strong>
        (Workflow) run
</strong></dt>
<dd>

A run is the complete run of a workflow.

</dd>
<dt><a name="studio"></a><strong>
        Workflow Studio
</strong></dt>
<dd>

Sometimes called the studio, it is the place where users can design workflows.

</dd>
<dt><a name="repo"></a><strong>
        Repositories
</strong></dt>
<dd>

To add a actions and triggers to Ryax, we use a system of code repositories.

</dd>
<dt><a name=""></a><strong>
        Users
</strong></dt>
<dd>

People who use Ryax. Most of the users can fit in one of these categories:
Business user (in french, *utilisateur métier*),
Creators (developers that design and implement workflows and modules),
Instance administrators, and
Cluster administrators.

</dd>
<dt><a name=""></a><strong>
        Instance
</strong></dt>
<dd>

A Ryax instance is a complete Ryax system running. It may hold many projects and users.

</dd>
<dt><a name=""></a><strong>
        SaaS instance
</strong></dt>
<dd>

Online version of a Ryax instance when logged into our website.

</dd>
<dt><a name=""></a><strong>
        Server or Cluster
</strong></dt>
<dd>

A server or a cluster is a set of machines connected. See, [Wikipedia](https://en.wikipedia.org/wiki/Computer_cluster).

</dd>
<dt><a name=""></a><strong>
        On-premise
</strong></dt>
<dd>

Running Ryax *on-premise* means that Ryax runs on a cluster supplied by the client. See, [Wikipedia](https://en.wikipedia.org/wiki/On-premises_software).

</dd>
<dt><a name=""></a><strong>
        Kubernetes
</strong></dt>
<dd>

If Ryax were a car, Kubernetes would be the traffic regulations. A set of rules that allow Ryax to run many different clusters without trouble. See, [Wikipedia](https://en.wikipedia.org/wiki/Kubernetes).

</dd>




</dl>



