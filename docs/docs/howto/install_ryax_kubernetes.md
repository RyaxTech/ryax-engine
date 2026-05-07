# Installation

!!! tip
    For a local development installation please refers the [Getting Started Guide](https://gitlab.com/ryax-tech/ryax/ryax-engine#getting-started-with-ryax)

!!! note
    Previous installation method with `ryax-adm` is **deprecated**: You can still find the documentation [here](./install_ryax_kubernetes_old.md)

If you have any questions, please join our [Discord server](https://discord.gg/ctgBtx9QwB). We will be happy to help!

## Requirements

All you need to install Ryax is a Kubernetes cluster and Docker installed on your machine.
You can get a managed Kubernetes instance from any Cloud provider.

Supported Kubernetes:

* kubernetes > 1.30 with `loadBalancer` and `storageClass` setup with a default values

Hardware:

* At least 2 CPU core
* 4GB of memory
* 40GB of disk available

!!! tip
    Depending on the Actions that you run on your cluster you might need more resources

## Prerequisites

!!! warning
    This guide assumes that you are comfortable with Kubernetes and Helm.

- Make sure your configuration point to the intended cluster: `kubectl config current-context`.
- Your Kubernetes cluster dedicated to Ryax: we offer no guarantee that Ryax runs smoothly alongside other applications.
- Make sure you have complete admin access to the cluster. Try to run `kubectl auth can-i create ns` or `kubectl auth can-i create pc`, for instance.
  ```sh
  $ kubectl auth can-i create ns
  Warning: resource 'namespaces' is not namespace scoped
  yes
  ```
- Have access to a DNS server where you can add a new `A` or `CNAME` entry for your cluster.

### Enable TLS

!!! note
    Without a DNS, the Ryax cluster will be accessed with the IP address directly and the HTTPS certificate will be self-signed.

If you intend to configure a DNS for your cluster the first step is to install [cert-manager](https://cert-manager.io/).

For instance with the following command:

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
```

## Configure your Installation

Installing Ryax is analogous to installing a Helm chart. To begin we will start
with a default configuration, and make a few tweaks so that everything is
compatible with your Kubernetes provider. Be assured however that you will be
able to fine-tune your installation later on.

In our tests we installed Ryax with the main cloud providers current on the market, depending on the provider
some configuration is required to get kubernetes with all the features
required to run Ryax. Please visit the link of your provider below to check
how to configure a kubernetes cluster before installing.

* [AWS](kubernetes_aws.md) : requires tweaking so pods can have persistent volume claims (PVCs) and enable autoscaling support;
* Scaleway : no specific tweaking for Ryax support is required.

## Installation

!!! note
    We also propose a **minimal** and a **dev** version. You can find the values here: https://gitlab.com/ryax-tech/ryax/ryax-engine/-/tree/master/charts/ryax/env.

We provide a script to generate a `secrets.yaml` including secrets with the right formatting.
```sh
curl -s https://gitlab.com/ryax-tech/ryax/ryax-engine/-/raw/987689da73f5875c52ca8fa4361c7082ed74a78f/chart/generate-secrets.py | python > secrets.yaml
```

Then, download the configuration file `prod.yaml` in this [repository](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/blob/master/charts/ryax/env/prod.yaml).
Or using this command:
```sh
curl -O https://gitlab.com/ryax-tech/ryax/ryax-engine/-/raw/master/charts/ryax/env/prod.yaml
```
This file contains specific configuration with tls enabled and monitoring configured with tls.

Next you can install Ryax with these configuration files.
The only value you need to complete is `global.tls.hostname` with the intended domain name for your cluster.

```sh
helm install ryax oci://registry.ryax.org/release-charts/ryax-engine \
  -n ryaxns --create-namespace \
  -f prod.yaml -f secrets.yaml \
  --set global.tls.hostname='example.company.io'
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

### Configure the DNS

To get a valid SSL certificate and to allow other Kubernetes sites to be join your Ryax main site, you have to associate a valid domain name by setting `global.tls.hostname`.
Then, you need to configure domain name resolution pointing to the correct Kubernetes cluster public IP address.

The last step is configuring your DNS so that you can connect to your cluster.

To retrieve the external IP of your cluster, run this one-liner

```bash
kubectl -n ryaxns get svc ryax-traefik -o jsonpath='{.status.loadBalancer.ingress[].ip}'
# OR depending on your provider
kubectl -n ryaxns get svc ryax-traefik -o jsonpath='{.status.loadBalancer.ingress[].hostname}'
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

### Configure Storage Class

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

## Access to your Cluster

Now you can access your cluster with its IP address in your web browser.

Default credentials are:
- user: `user1`
- password: `pass1`

!!! warning
    Change this password and user as soon as you're logged in!

## Install a Worker

In Ryax, workflow executions are handled by Workers.
The next step is to configure and install a worker in your cluster to start running your workflows.

!!! tip
    This guide explains how to install a worker in your main ryax installation. If you already have a worker on your main site, and you want to create a multi site installation you can follow this [guide](./worker-install.md).

### Worker configuration

In order to configure your Worker, you will need to register a *Site* and or more *Node Pools* (set of homogeneous nodes) in the Ryax UI.
To do so, go into the Infrastructure view of your Ryax installation (For example in https://ryax.example.com/app/infrastructure) and create a new Site.
Then create a new Node pool that match the caracteristics of the computing node (servers) that you want to attach to Ryax.

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

## Cluster Update

!!! warning
    Before any updates, [do a backup](./create-backups.md) and have a look at the changelog to see if there is any extra step needed.

!!! tip
    If you have lost the values YAML files use for your cluster you can restore them using:
    ```sh
    helm get values -n ryaxns ryax --output yaml > values.yaml
    ```
     
Run the upgrade with:
```sh
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine -n ryaxns -f values.yaml
```

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

