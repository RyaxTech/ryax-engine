# Install Ryax on Kubernetes

!!! tip
    For a local development installation please refers the [Getting Started Guide](https://gitlab.com/ryax-tech/ryax/ryax-engine#getting-started-with-ryax)

!!! note
    Previous installation methode with `ryax-adm` is **deprecated**: You can still find the [documentation](./install_ryax_kubernetes_old.md)

## Requirements

All you need to install Ryax is a Kubernetes cluster and Docker installed on your machine.
You can get a managed Kubernetes instance from any Cloud provider.

Supported Kubernetes:

* kubernetes > 1.30 with `loadBalancer` and `storageClass` setup with a default values

Hardware:

* At least 2 CPU core
* 4GB or memory
* 40GB of disk available

!!! tip
    Depending on the Actions that you run on your cluster you might need more resources

## Preparatory Steps

!!! warning
    This guide assume that you are comfortable with Kubernetes and Helm.
    
- Make sure your configuration point to the intended cluster: `kubectl config current-context`.
- Your Kubernetes cluster dedicated to Ryax: we offer no guarantee that Ryax runs smoothly alongside other applications.
- Make sure you have complete admin access to the cluster. Try to run `kubectl auth can-i create ns` or `kubectl auth can-i create pc`, for instance.
  ```sh
  $ kubectl auth can-i create ns
  Warning: resource 'namespaces' is not namespace scoped
  yes
  ```
- Have access to a DNS server where you can add a new `A` or `CNAME` entry for your cluster.

## Configure your Installation

Installing Ryax is analogous to installing a Helm chart. To begin we will start
with a default configuration, and make a few tweaks so that everything is
compatible with your Kubernetes provider. Be assured however that you will be
able to fine-tune your installation later on.

In our tests we installed Ryax with the main cloud providers current on the market, depending on the provider
some configuration is required to get kubernetes with all the features
required to run Ryax. Please visit the link of you provider below to check
how to configure a kubernetes cluster before installing.

* [AWS](kubernetes_aws.md) : requires tweaking so pods can have persistent volume claims (PVCs) and enable autoscaling support;
* Scaleway : no specific tweaking for Ryax support is required.

## Worker configuration

In your configuration, you have to define at least one `worker` configuration.
By default, a Worker is installed on the local Kubernetes cluster.

In order to configure your Worker, you will need to select one or more node pools (set of homogeneous nodes) and give to the Worker some information about the nodes.

!!! note
    Why we use node pools? Because it allows Ryax to leverage the Kubernetes node **autoscaling with scale to zero !**


Here is a simple example worker configuration using a AWS EKS managed cluster:
```yaml
worker:
  config:
    site:
      name: aws-kubernetes-small
      spec:
        nodePools:
        - name: small
          cpu: 2
          # gpu: 1 # required if the nodepool has GPUs
          memory: 4G
          selector:
            eks.amazonaws.com/nodegroup: default
```

Let's explain each field:
- **site.name**: the name of the site that identifies the site in Ryax
- **site.spec.nodePools**: the node pools definitions (a node pool is a set of homogeneous node. Each resource value is given by node). 
  - **name**: name of the node pool.
  - **cpu**: amount of allocatable cpu core per node.
  - **memory**: amount of allocatable memory in bytes per node.
  - **selector**: node selector type within Kubernetes to precise which nodes will take part in the node pool.


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

For more details about the Worker configuration please see the [Worker reference documentation](../reference/configuration.md#worker-configuration)

!!! note 
    For Multi-Site Installation see [Worker Installation Documentation](./worker-install.md)

## Install with `helm`

Ryax needs secrets for internal service. We provide a python script to generate these secret.

Then, you can install Ryax with Helm:
```sh
helm install oci://registry.ryax.org/release-charts/ryax-engine ryax -n ryaxns --create-namespace
```

!!! note
    We propose a **minimal** and a **dev** version. You can find the values here: https://gitlab.com/ryax-tech/ryax/ryax-engine/-/tree/master/chart/env


## Access to your cluster

Now you can access to you cluster with `https://ryax.example.com` on your web browser.

Default credentials are *user1/pass1*

!!! warning
    Change this password and user as soon as you're logged in!

## Cluster Update

!!! warning
    Before any updates, [do a backup](./create-backups.md) and have a look at the changelog to see if there is any extra step needed.


Run the upgrade with:
```sh
helm upgrade oci://registry.ryax.org/release-charts/ryax-engine ryax -n ryaxns --reuse-values
````

# Configure for Production

## Enable TLS

If you do not intend to configure a DNS cluster, be aware that you will access Ryax through the IP address directly and https certificate will be self-signed.
Else, you need to enable tls provided by certManager:
```sh
helm install oci://registry.ryax.org/release-charts/ryax-engine ryax -n ryaxns --create-namespace \
    --set global.tls.enable=true \
    --set global.tls.hostname='ryax.example.com' \
    --set global.tls.environment='production'
```

!!! warning

    Depending on your Kubernetes cluster setup, you might have issue
    with Cert Manager which is use to get a valid HTTPS certificate.
    See the [Cert Manager compatibility documentation](https://cert-manager.io/docs/installation/compatibility/) for more details.

    If you want to deal with the certificate yourself, you can disable it with:
    ```
      certManager:
        enabled: false
    ```

## Configure the DNS

To get a valid SSL certificate and to allow other Kubernetes sites to be join your Ryax main site, you have to associate a valid domain name by setting `global.tls.hostname`.
Then, you need to configure domain name resolution  pointing to the correct kubernetes cluster public IP address.

The last step is configuring your DNS so that you can connect to your cluster..

To retrieve the external IP of your cluster, run this one-liner

```bash
kubectl -n kube-system get svc traefik -o jsonpath='{.status.loadBalancer.ingress[].ip}'
# OR dpending on your provider
kubectl -n kube-system get svc traefik -o jsonpath='{.status.loadBalancer.ingress[].hostname}'
```

Or simply look at the response of `kubectl -n kube-system get svc traefik`, under "External IP".

Depending on your Cloud provider you will have an IP address which requires a `A` entry, or a DNS (AWS) that requires you to create a `CNAME` entry.

Now create a DNS entry for the cluster and another for every subdomain using a star entry:
- ryax.example.com
- \*.ryax.example.com

Once your entries are created, and **only if tls is enabled**, you will have to wait for Let's Encrypt to provide you a valid
certificate. You can check with:

```sh
kubectl get certificates -n ryaxns
```

The state should be `READY: true`.

## Configure Storage Class

An important configuration is the `global.defaultStorageClass`. If not set, Ryax will use the
default one provided by the Kubernetes cluster for all services. But, the
volumes are used to store the internal database (`datastore`), object store for
workflows IO (`filestore`), and a container registry for the Ryax Actions
containers (`registry`) which all affect your Ryax instance performance, so it
is recommended to have SSD backed storage for all services to avoid delays
state persistence, deployments, and runs.
For more fine grained settings you can set each storage class independently with the `storageClass` inside each service.
Regarding the volume size, we recommend that you start small, you can extend them later on with most Storage providers.
The default values give comfortable volume sizes to start working on the platform.

If you have any questions, please join our [Discord server](https://discord.gg/ctgBtx9QwB). We will be happy to help!

## Ryax IntelliScale

Ryax IntelliScale is a Resource Management optimization technique (Vertical Pod Autoscaling) that performs an optimal sizing of allocated resources within nodes based on previous 
executions. It tracks the usage of CPUs, RAM, GPUs and GPU VRAM while recommending and adjusting follow-up executions based on the real usage of resources. You can find
more details along with configuration info in [Ryax IntelliScale](../reference/intelliscale.md) 

In particular when used for GPUs it performs dynamic GPU fractioning by leveraging NVIDIA MIG mechanism (available on specific new NVIDIA architectures)

### Enable MIG

[MIG](https://www.nvidia.com/en-eu/technologies/multi-instance-gpu/), or Multi-Instance GPU, is a technology developed by NVIDIA that allows a 
single GPU to be partitioned into multiple instances. Each instance operates with its own dedicated resources, enabling various workloads to run 
simultaneously on a single GPU, which optimizes utilization and maximizes data center investment. For AI applications, MIG can be particularly 
beneficial as it allows for the efficient distribution of resources, ensuring that each task has the necessary computational power with a certain isolation from other processes running on the same GPU. 

To enable the usage of MIG to be considered in the context of IntelliScale GPU tracking and adapted recommendations you need to setup the different supported MIG node pools within the configuration of the worker.
IntelliScale functions at the level of each Kubernetes cluster so it needs to be configured for each worker. 

An example for a configuration on Scaleway is given below:

```yaml
# The following details should be created under worker nodepools 
          nodePools:
          - cpu: 23
            gpu: 7
            gpu_mode: mig-1g.10gb
            memory: 240G
            name: gpu-pool-mig-1g-10gb
            selector:
              k8s.scaleway.com/pool-name: gpu-pool-mig-1g-10gb
          - cpu: 23
            gpu: 2
            gpu_mode: mig-3g.40gb
            memory: 240G
            name: gpu-pool-mig-3g-40gb
            selector:
              k8s.scaleway.com/pool-name: gpu-pool-mig-3g-40gb
          - cpu: 23
            gpu: 1
            gpu_mode: mig-7g.80gb
            memory: 240G
            name: gpu-pool-mig-7g-80gb
            selector:
              k8s.scaleway.com/pool-name: gpu-pool-mig-7g-80gb
```

In the above example we configured 3 node pools each one representing a different MIG configuration. Ryax IntelliScale will track the usage of GPUs for each execution and will recommend the most adapted 
node-pool for the follow-up runs. 
Let's explain each field:

- **cpu**: the number of allocatable cpus of each node of the node pool
- **gpu**: the number of allocatable GPU instances for each node of the node pool 
- **gpu_mode**: the MIG mode that this node pool is configured.  
  - *The value format should strictly follow the pattern "mig-xg.ygb" (xg.ygb is the standard MIG slice format with x MIG GIs and y GB GPU memory) if you want to enable MIG on this node pool. Instead if you want nodes with entire GPU (which is not under control of IntelliScale), the value should be a single word "full".*  
  - Currently we suggest to use only mig-1g.10gb, mig-3g.40gb or mig-7g.80gb modes since there are less unutilized resources
- **memory**: amount of allocatable RAM for each node of the node pool
- **name**: name of the node pool
  - **selector**: node pool selector within Kubernetes.  
  - *To be handled by IntelliScale, a node pool with MIG mode GPUs should own a node selector with its value following strictly the format "gpu-pool-mig-xg-ygb", where xg-ygb is the standard MIG slice format "xg.ygb" replacing '.' by '-'.*

What is interesting to understand is that ideally you should set autoscaling activated from 0 to n


For more details regarding MIG, please refer to Nvidia's [User Guide](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/index.html). This is also another 
concrete [example](https://developer.nvidia.com/blog/deploying-nvidia-triton-at-scale-with-mig-and-kubernetes/) of how MIG is applied to industrial workflows.


## Use Local Only Registry

Ryax uses an internal registry to store actions' images.
If you want Ryax to work on local site only (default), no external access to registry will be provided.
Notice that with tls disabled, you cannot add external sites to Ryax outside your local network.

/// warning
    Some Kubernetes providers block access the nodePort or disable them entirly.
    In this case use a DNS with a loadBalancer as described in this section: (Configure the DNS)[#configure-the-dns].

If your cluster is inaccessible from outside your private network, Ryax use a nodePort to connect to the registry.
This will allow actions' pods to be deployed, however you will not be able to connect external kubernetes sites.
To accomplish that just disable tls in the helm values.
It will disable the registry ingress and make the internal registry available from a nodePort.

```yaml
global:
  tls:
    enabled: false
```

In details, this configuration will the internal registry available to the Kubernetes node daemon, the kubelet.
It will start one pod per node named `ryax-registry-cert-setup-xxxxx` that configures certificates to access the internal registry through `127.0.0.1:30012`.
The pod images for the Ryax actions in the namespace `ryaxns-execs` will pull images through that nodePort.

## Troubleshooting

### Cannot upgrade, Bitnami charts password error

When trying to change configuration you might experience rabbitmq, or postgresql errors like below.

```shell
COMBINED OUTPUT:
  Error: Failed to render chart: exit status 1: Error: execution error at (rabbitmq/templates/secrets.yaml:4:17):
  PASSWORDS ERROR: You must provide your current passwords when upgrading the release.
                   Note that even after reinstallation, old credentials may be needed as they may be kept in persistent volume claims.
                   Further information can be obtained at https://docs.bitnami.com/general/how-to/troubleshoot-helm-chart-issues/#credential-errors-while-upgrading-chart-releases
      'auth.password' must not be empty, please add '--set auth.password=$RABBITMQ_PASSWORD' to the command. To get the current value:
          export RABBITMQ_PASSWORD=$(kubectl get secret --namespace "ryaxns" ryax-broker-secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d)
  Use --debug flag to render out invalid YAML
```

You can find the correct password with:
```shell
kubectl get secret --namespace ryaxns ryax-broker-secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d
```

To avoid this step on every update, you can add the password in the helm values like below:
```yaml
rabbitmq:
  auth:
    password: <MY SECRET>
```

### All actions' pods on ryaxns-execs are in imagePullBackOff

If you are getting imagePullBackOff for pods on ryaxns-execs.
You are probably having trouble accessing the registry through the external domain name. 
Assure that your DNS is configured and that the ryax traefik service is using the correct ip or fully qualified hostname. 
You can check Services by typing:

```shell
kubectl get service -A  | grep -i LoadBalancer
```

Make sure that the ip/hostname associated to `traefik LoadBalancer` is correct.
Make sure to add your dns entry with a wild card. For instance, if you configure
clusterName as `example` and domainName as `ryax.io`, make sure that you have
dns entries `*.example.ryax.io` and `example.ryax.io` pointing to the correct IP 
address. See also how to [Configure the DNS](#configure-the-dns).

If you do not want to configure external access to your cluster you won't be able
to connect external kubernetes workers, but you can always have a local worker. 
In this case, to configure the internal registry refer to [Use local registry only](#use-local-only-registry).
