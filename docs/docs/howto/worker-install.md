# Enable Multi-Site on Ryax

!!! warning
    This documentation assumes that you already have a working Ryax installation, with a public IP and a configured DNS. See [Ryax install doc](./install_ryax_kubernetes.md) for more details.


Ryax is able to use multiple computing infrastructure at once, even during the single run of a workflow.
To enable the multi-site mode you will need to install a Ryax Worker for each site.
Ryax Worker currently supports two type of sites `SLURM_SSH` and `KUBERNETES`.

This document explains how to install and configure Workers.

## SLURM_SSH Worker

### Requirements

Because the SLURM_SSH worker uses SSH to connect to the SLURM cluster, 
the simplest way to deploy an SLURM_SSH worker is on the Ryax main site.
So, the only things you'll need are:

- SLURM installed on the cluster
- SSH access to the cluster with credentials to run SLURM commands
- Pyhton3 available on the Slurm login node
- (Recommended) Singularity install on the cluster to run Ryax Actions containers

!!! note
    With the usage of `custom script` you can run commands directly on the cluster and avoid the usage of Singularity,
    but Action packaging will be completely bypassed.


### Configuration

!!! warning
    Be sure to install the workers on the same cluster and namespace that is running `ryax-runner`.

Ryax allows you to register one or more SLURM partitions to run your actions on. 
To do so, you need to define a *Site* and one or more partitions, called *Node Pools* in Ryax, in the infrastructure view of the Ryax UI.

Now that your Site and you Node Pools are created, their IDs are required to create the Worker configuration.
Create a worker-values.yaml file and copy the Site and Node Pools IDs from the Ryax UI to add them to the configuration
like in the following example: 

```yaml
config:
  site:
    id: Site-1777021590-tq6kqbbe
    type: SLURM_SSH
    spec:
      partitions:
        - name: default # name of the partition as define in Slurm
          id: NodePool-1777021590-n3y8xs0g
      credentials:
        server: my.hpc-site.com
        username: ryax
loki:
  enabled: false
intelliscale:
  enabled: false
```
Each field explained in details:

- **site.id**: the name of the site that identifies the site in Ryax
- **site.type**: the type of the site (can SLURM_SSH or KUBERNETES)
- **site.spec.partitions**: the partition definitions. **Ryax only supports partition with homogeneous node for now.** Each resource value is given by node.
  - **name**: name of the partition in Slurm (Will be use to target the partition).
  - **id**: id of the partition provided by the Ryax UI.
- **site.spec.credentials**: Contains credential to SSH to HPC cluster login server. The private key will be injected during the installation phase.

For more details about the Ryax Worker configuration please see the [Worker reference documentation](../reference/configuration.md#worker-configuration)

### Installation

Now you can install the Worker on the Ryax main site. To do so, we will use the configuration defined above.

Also, we will inject the SSH private key required to access the SSH cluster.
```sh
helm upgrade --install ryax-worker-hpc \
  oci://registry.ryax.org/release-charts/worker  \
  --version 26.4.0 \
  --namespace ryaxns \
  --values worker-values.yaml \
  --set-file hpcPrivateKeyFile=./my-ssh-private-key
```

* `ryax-worker-hpc`: name of the helm release
* `worker-values.yaml`: file containing the configuration of the worker
* `my-ssh-private-key`: rsa private key file that has authorization to login

Once the worker is up and running, you should see a new site available in UI, in the workflow edition, in the *Deploy* tab of each action.
Now you just have to select the SLURM_SSH site in the *Deploy* configuration to tell Ryax to execute your Action there on the next run.

If you want more control on the way Slurm deploys your action (run parallel jobs), add the HPC addon to you action.
See the [HPC offloading](../reference/hpc.md) reference for more details.

## Kubernetes Worker

### Requirements

First, you'll need a Kubernetes cluster, of course! Be sure that your cluster is able to provision Persistent Volumes (most of the Kubernets clusters do, by default).
```sh
kubectl get storageclass
```

This command should show you at least one storage class with the *default* flag, if this is not the case you should install one.
Make sure that the storage class you want to use is set as default. You can set a storage class as default with:

```shell
kubectl patch storageclass YourStorageClassName -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Change `YourStorageClassName` accordingly. 
For a simple example you can use `local-path`, from the [Local Provisioner](https://github.com/rancher/local-path-provisioner) storage class
if available.

To install a Ryax Worker on Kubernetes we will use Helm.

Supported versions:

* Kubernetes > 1.30
* Helm > 3.x

Hardware Requirements:

* At least 2 CPU core
* 2GB of memory
* 1GB of disk available

**Note that resource requirements really depends on your usage of the cluster.**

### Configuration

<!-- TODO: This is the exact copy of the install worker configuration part -->
<!-- reformat or use include-markdown https://pypi.org/project/mkdocs-include-markdown-plugin/ -->

In order to configure your Worker, you will need to register a *Site* and or more *Node Pools* (set of homogeneous nodes) in the Ryax UI.
To do so, go into the Infrastructure view of your Ryax installation (For example in https://ryax.example.com/app/infrastructure) and create a new Site.
Then create a new Node pool that match the characteristics of the computing node (servers) that you want to attach to Ryax.

Now that your Site and you Node Pools are created, we will need to their IDs to create the Worker configuration.
Create a `worker-values.yaml` file and copy the Site and Node Pools IDs from the Ryax UI to add them to the configuration like in the following example.  

Here is a simple example worker configuration using an AWS EKS managed cluster:

```yaml
config:
  site:
    id: Site-1777021590-tq6kqbbe
    spec:
      nodePools:
      - id: NodePool-1777021590-n3y8xs0g
        selector:
          eks.amazonaws.com/nodegroup: default
```

Let's explain each field of the `config`:

- **site.id**: the id of the site copied from the Ryax UI.
- **site.spec.nodePools**: the node pools definitions (a node pool is a set of homogeneous node. Each resource value is given by node).
  - **id**: the id of the node pool copied from the Ryax UI.
  - **selector**: node selector that precises within Kubernetes which nodes will take part in the node pool.


These fields might change depending on the cloud provider. Below an example of configuration for Azure.

```yaml
kubernetes.azure.com/agentpool: default
```

All node pool information can be obtained using a simple:
```sh
kubectl describe nodes
```

To obtain resources values, look for the *Allocatable* fields.
Regarding the selector, you should find the label(s) that uniquely refers to your node pool.

For more details about the Worker configuration please see the [Worker reference documentation](../reference/configuration.md#worker-configuration).

To be able to scale to 0 when unused, your node pools must be dedicated to the Ryax users workload.
For the node pool to be used only by Ryax actions, we advise you to put a taint on your nodes using the `ryax.tech/ryaxns-execs` key.
Because all the Ryax action already have a toleration for this by default, they will be the only pods that will be allowed to deployed there.

Adding a taint on a node pool depends on your provider but here an example configuration:

```yaml
taints:
 - effect: NO_SCHEDULE
   key: ryax.tech/ryaxns-execs
   value: only
```

### Preparing

For the worker to communicate securely to the main Ryax site, we need to create a secure connection access between the two Kuberenetes clusters.
In this How-To we will use [Skupper](https://skupper.io), but other multi-cluster network technology might work. 
Make sure you have kubectl access to both clusters, we are going to reference as **main-site** the kubernetes that has all Ryax services including the UI and **worker-site** the kubernetes cluster that we will attach to run Ryax's actions.

**local machine**
  
* Install skupper v2 cli, in your local machine:
  ```shell
  curl https://skupper.io/v2/install.sh | sh
  ```

**main-site & worker-site**
  
* Remove skupper v1 in both sites if installed, if not you can skip this step:
  ```shell
  kubectl delete -n ryaxns deployment.apps/skupper-router deployment.apps/skupper-service-controller service/skupper-router service/skupper-router-local
  ```

**main-site & worker-site**
  
* Install skupper v2 custom resources definition CRDs, in both sites:
  ```shell
  helm install skupper oci://quay.io/skupper/helm/skupper --version 2.1.3
  ```

**worker-site**
 
* Create namespaces `ryaxns` and `ryaxns-execs` required by Ryax on the worker-site:
  ```yaml
  kubectl create namespace ryaxns
  kubectl create namespace ryaxns-execs
  ```


### Configure skupper

To resume we need the **worker-site** to access **main-site** services. More precisely, we need to expose the following services:

- *registry*: to pull action images
- *filestore*: to read and write files (actions static parameters, execution I/O)
- *broker*: to communicate with other Ryax services

The registry is already exposed on the internet so only the secrets are required to access it. For filestore and broker, however, we need to provide a mechanism to reach out from the **worker-site**. For that, we are going to install skupper in both sites and configure it accordingly to the procedure below. Note that a **worker-site** means the command should run on the **worker-site** only, likewise the **main-site** marks when a command must run ONLY on the **main-site**. All `skupper` cli commands will use the default kubectl configuration, so be careful to set you KUBECONFIG environment variable accordingly.


**worker-site**

* On the **worker-site**, first create the skupper site, it is very important to enable link-access so it can have the services of the main site exposed later.
  ```shell
  skupper -n ryaxns site create worker-site --enable-link-access
  ```

**main-site**

* Second, create the skupper site resource.
  ```shell
  skupper -n ryaxns site create main-site
  ```

**worker-site**

* Now create the token to redeem on the main site, keep secret.token in a secure location it will work for the first attempt to connect and then be useless.
  ```shell
  skupper -n ryaxns token issue ../secret.token
  ```

**main-site**

* Redeem the created token to allow connection with the worker.
  ```shell
  skupper -n ryaxns token redeem ../secret.token
  ```

**worker-site**

* The worker site must create a listener to have the main-site broker (ryax-broker-ext) and filestore (ryax-minio-ext) services exposed on its side.
  ```shell
  skupper -n ryaxns listener create ryax-broker-ext 5672
  skupper -n ryaxns listener create ryax-minio-ext 9000
  ```

**main-site**

* The main-site must create a connector to allow the listeners to reach its local services, note that we use `--workload` to specify the target service of the connector.
  ```shell
  skupper -n ryaxns connector create ryax-broker-ext 5672 --workload service/ryax-broker
  skupper -n ryaxns connector create ryax-minio-ext 9000 --workload service/ryax-minio
  ```

**main-site**

* Save the secrets to access Ryax services, the secrets include sensitive information please keep this file safe and delete it as after the next step. We provide a small helper script to inject the "-ext" suffix needed for remote services mapping.
  ```shell
  wget "https://gitlab.com/ryax-tech/ryax/ryax-runner/-/raw/master/k8s-ryax-config.py"
  chmod +x ./k8s-ryax-config.py
  ./k8s-ryax-config.py
  ```

**worker site**

* Install saved secrets from previous step on the **worker-site** (after this command it is safe to delete the secrets file):
  ```shell
  kubectl apply -f ./secrets
  ```

**worker site**

* Now that we have the configuration and a secure connection with the credentials we will use Helm to install the latest Ryax Worker:
  ```sh
  helm upgrade --install ryax-worker oci://registry.ryax.org/release-charts/worker --values worker.yaml -n ryaxns
  ```

---

That's it! Once the worker is up and running, you should see a new site available in UI, while editing the workflow in the *Deploy* tab for each action (might need to refresh if the workflow was already open on edit mode).

![Worker selection on Deploy tab](../_static/worker-ryax-ui.png)

### Trouble Shooting

#### Container pending on persistent volume claim.

Check if the pvc was created with the correct storage class.

```shell
kubectl get storageclass
kubectl get pvc -n ryaxns
```

The PVC status should be `BOUND`, if they are not it is probably because the cloud provider require
some extra configuration to create. In our tests, with AWS it was necessary
to associate an EBS addon.

Create iam service account with the role for EBS driver.

```shell
eksctl create iamserviceaccount \
  --region eu-west-3 \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster multi-site-pre-release-test \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole
```

Then you have to create the addon associating with the account.

```shell
eksctl create addon \
 --name aws-ebs-csi-driver \
 --cluster multi-site-pre-release-test \
 --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole --force
```

Now make the storage class the default.

```shell
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

[StackOverflow discussion](https://stackoverflow.com/questions/75758115/persistentvolumeclaim-is-stuck-waiting-for-a-volume-to-be-created-either-by-ex)

#### Troubleshot: Certificate Is Not Valid

For Ryax to have a valid TLS certificate, you need to have a DNS entry that point to you cluster. Please, check the
section related to this process in the [installation documentation](install_ryax_kubernetes.md#configure-the-dns).

You can check the state of the certificate request using:
```shell
kubectl get certificaterequests -A
kubectl get orders.acme.cert-manager.io -A
```
