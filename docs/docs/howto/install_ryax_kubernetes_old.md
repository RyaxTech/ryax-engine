
## Install with `ryax-adm` **(DEPRECATED)**
### Initialize

First create a directory to organize the Ryax installation and initialize it with the default configuration:
```bash
mkdir ryax_install
cd ryax_install
docker run \
  -v $PWD:/data/volume \
  ryaxtech/ryax-adm:latest init --values volume/values.yaml
```

You are now in the `ryax_install` folder and the `values.yaml` containing the
default config was created.

``` note::
All the following commands assume that you are in the `ryax_install` directory.
```

To explain the configuration fields, here is an example of simple configuration file for Ryax:
```yaml
# The Ryax version.
# Check here to get the latest version: https://github.com/RyaxTech/ryax-engine/releases
version: 25.10.0

# Cluster DNS
clusterName: myclustername
domainName: example.com

# Log level for all Ryax services
logLevel: info

# Set the storage size for each stateful service
datastore:
  pvcSize: 10Gi
minio:
  pvcSize: 40Gi
registry:
  pvcSize: 20Gi

# Enable Prometheus + Grafana monitoring
monitoring:
  enabled: true

# Use HTTPS by default
tls:
  enabled: true

# Automate HTTPS with Let's Encrypt
certManager:
  enabled: false

repository:
    chartVersion: 25.10.0-1

ryax-front:
    chartVersion: 25.10.0-1

# Set minimal requirements for builder
actionBuilder:
    chartVersion: 25.10.0-1
    values:
      resources:
        limits:
          memory: 10Gi
        requests:
          cpu: 2
          memory: 10Gi

# Set minimal requirement for message broker
rabbitmq:
  values:                                                             
    resources:                                                        
      limits:                                                         
        memory: 8Gi                                                   
      requests:                                                       
        cpu: 2                                                        
        memory: 8Gi 

# Set minimal requirements for runner
runner:
  chartVersion: 25.10.0-3
  values:
    resources:
      limits:
        memory: 2Gi
      requests:
        cpu: 1
        memory: 2Gi
        
# Depends on your Kubernetes instance. Leave it empty to use the default
# storageClass: ""

worker:
  chartVersion: 25.10.0-3
  values:
    config:
      site:
        name: aws-kubernetes-cluster-1
        spec:
          nodePools:
          - name: small
            cpu: 2
            # gpu: 1 # required if the nodepool has GPUs
            memory: 4G
            selector:
              eks.amazonaws.com/nodegroup: default
            
```

The Ryax installation is based on Helm charts, one for each service with a `helmfile` to define the whole cluster configuration.

To customize your installation. You can set any configuration field using the `values` keyword. A detailed description of all the values can be found in [ryax-adm/helm-charts/values.yaml](https://gitlab.com/ryax-tech/ryax/ryax-adm/-/blob/master/helm-charts/values.yaml).

### Set the `version` field with the Ryax version, for example: `23.10.0`. The latest stable version can be found in the [releases page](https://gitlab.com/ryax-tech/ryax/ryax-main/-/releases).

The `clusterName` and `domainName` defines the name you give to your cluster, which is used in various places. One of those places is the URL of your cluster that will be \<clusterName\>.\<domainName\>, therefore it has to be consistent with your DNS.

