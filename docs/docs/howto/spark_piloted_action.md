# Ryax spark wrapped action

Spark support of kubernetes enable to use the kubernetes
infrastructure piloted by spark. Ryax works upon kubernetes
so this tutorial goal is to explain
how to make a Ryax action to behave as a spark driver that 
interacts with kubernetes directly spawning executors pods
across the platform.

## Requirements

Before we start, there is a security concerns when enabling an 
action to interact
with kubernetes. To limit access Ryax deploy users' actions 
in the `ryaxns-execs` kubernetes namespace. When allowing an
action to interact with the kubectl api be aware that this action
would delete, create, read, pods, deamonsets, and other resources
that are running on the same namespace.
The user that requests this feature need to be trusted and requries 
the cluster administrator to add a `service_account`
on kubernetes `ryaxns-execs` namespace.
Throughout this section we configure the Kubernetes resources required to
run the piloted Spark application.


### serviceAccount

!!! warning **Disclaimer**
    the creation of serviceAccount must be
    made by an administrator on kubernetes. This is step
    is to be performed by a kuberntes cluster administrator, someone
    that has full access to `kubectl` and can create the serviceAccount resource on
    `ryaxns-execs` namespace.

This action will require kubernetes addon to
associate with a serviceAccountName that can list/delete/create on
services, pods, persistentvolumeclaims, and configmaps.
This will grant access required for Spark to spam the executors across
kubernetes nodes.

The serviceAccount must be created beforehand in namespace `ryaxns-execs`
with a serviceAccountName that is later used with the Kubernetes addon.
To edit the Kubernetes addon serviceAccountName one can either edit the
workflow on Ryax UI before deployment or provide an initial value in `ryax_metadata.yaml`.

To create the service account with the right permissions you can use [our sample
rbac yaml file](https://gitlab.com/ryax-tech/workflows/hpc-actions/-/blob/master/spark/spark-rbac.yaml?ref_type=heads). 
To apply that file use command below.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark
  namespace: ryaxns-execs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ryaxns-execs
  name: spark-role
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: spark-role-binding
  namespace: ryaxns-execs
subjects:
- kind: ServiceAccount
  name: spark
  namespace: ryaxns-execs
roleRef:
  kind: Role
  name: spark-role
  apiGroup: rbac.authorization.k8s.io

```

To use this file simply get its content or download it in a `spark-rbac.yaml` file on your file system then issue the
`kubectl` command to apply this file, see below.


```shell
kubectl apply -f spark-rbac.yaml
```

To check if the service account has the correct permissions.
To do so you can run the bash code below.

```shell
for op in "list" "delete" "create" "update"
do
    for resource in "pods" "services" "configMaps" "persistentvolumeclaims"
    do
      echo "Checking for $op on $resource =====>" `kubectl auth can-i $op $resource --as=system:serviceaccount:ryaxns-execs:spark -n ryaxns-execs`
    done
done
```

## Getting started

This tutorial uses the action [Spark Ryax wrapper](https://gitlab.com/ryax-tech/workflows/hpc-actions/-/tree/master/spark?ref_type=heads).


Our goal is guide you through launching this action that hence issues
a spark-submit command. The spark-submit command has several
parameters that enables the action itself to become
a Spark driver transforming the current Ryax action pod. This will
allow Ryax to seamlessly run the Spark application and
spawn as many executors you specify.

The provided action serves as an example that computes digits of Pi using the Monte Carlo method. 
By changing the application jar file and the input parameters you can adapt that 
application to your needs. For the
more advanced cases, it will be necessary to edit the action
layout of inputs and outputs in `ryax_metadata.yaml` or even tweak some code in `ryax_run.py`.
We first show how to use the action as is and complement with information of
how to adapt that feature for advanced users.

Note that several input parameters declared on `ryax_metadata.yaml` are optional
and will have a default value assigned in case they are omitted. Moreover,
the action also inherets from the Kubernetes addon, and some paramters: like
`service_account_name` and `service_name` will appear because of the Kubernetes
addon. Ryax action pod will be the Spark driver. This 
will spawn multiple Spark executors across Kubernetes. We will then configure
executors' memory, executors' cpu, amount of executors pods.

To start, simple let's just use the application at first. For customizing the action
we are only required to provide the jar file with the application, the application
main class, and the parameters. 

* application_jar
* application_main_class
* application_args


## Advanced usage

### Tolerations

Sometimes we want to use specific nodes. Like for bebida that will make
nodes available that use the best effort policy. In this case we
can make a bebida aware action by selecting the nodes where the Spark
executors will run.

To select nodes where to schedulle, we can edit `exporter-pod-template.yaml`.
This file overrides toleration parameters and will make the executor.

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    ryax: spark-executor
spec:
# The pod template starts here
  containers:
    - command:
      - bash
      - /data/spark-entrypoint.sh
  # If you want the pods to execute only in nodes with label: bebida=hpc
  # uncomment below
  tolerations:
    - effect: NoSchedule
      key: bebida
      operator: Equal
      value: hpc
# The pod template ends here
```

The template state by default the toleration of taint `spark=bebida:NoSchedule`, so nodes
should receive the taint like in the example below:

```shell
kubectl taint nodes bebidanode spark=bebida:NoSchedule
```

## Running on Ryax

### Configuration 

Only 2 parameters required for the addon Kubernetes:

* Set the `service account` parameter to a given, example `spark`
* Set `service name`, example `sparkpi` 

Set the remaining parameters to match your needs:

* `executor cores`: number of vcores per executor
* `executor memory`: memory per executor, example 512m
* `executor instances`: total executor pods to spawn
* Load application file into `application jar` parameter
* Write a space separated list of application parameters in `application args`


!!! tip
    if you need files as parameters you will need
    to modify the code, add input parameters for the files and
    then add files to list.

For an example use the Spark examples class with the SparkPi
class.

* `application jar`: spark-examples_2.12-3.4.0.jar (you can get this inside the [Spark package](https://spark.apache.org/downloads.html) in `examples/jars`). 
* `application main class`: org.apache.spark.examples.SparkPi

