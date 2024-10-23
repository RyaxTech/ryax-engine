We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 24.10.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

Multi-site full power!

## New features

- A new service called Ryax Worker can now be used to attached any Slurm or Kubernetes cluster resources
- Ryax can now run any action on SLURM and Kubernetes seamlessly
- Action are now scheduled according to user defined constraints and objectives
- Add the possibility to pin Ryax services to a dedicated resources (nodeSelector)
- Enhance Ryax documentation with updated content ([](https://docs.ryax.tech))
- New Jupyter Notebook action with GPU support [in default actions](https://gitlab.com/ryax-tech/workflows/default-actions/-/tree/master/triggers/jupyterlab)
- Action builds now can be canceled
- Kubernetes addon now support injection of service
- Add VPA recommendation support (experimental)


## Bug fixes and Improvements

- Fix volume permission for NFS based storage volumes (defaults to 1200 now)
- Fix fail properly when a pip install fails during builds

## Upgrade to this version

This release introduce a new service, the Worker. In order to define the nodes
that will be used by your actions, the Worker requires a site configuration.
Please, add a configuration in your Ryax installation configuration file using
the following example: in your local cluster has a node pool named default with a label `k8s.scaleway.com/pool-name: default` on each node, it has 4 CPU and 8G of memory per node.
```yaml
worker:
  values:
     config:
       site:
         name: local
         spec:
           nodePools:
           - cpu: 4
             memory: 8G
             name: default
             selector:
               my.provider.com/pool-name: default
```

See the Worker [configuration documentation](https://docs.ryax.tech/reference/configuration.html#worker-configuration) for more details.

The users of HPC actions have to install a Worker dedicated to the each cluster
following this [documentation](https://docs.ryax.tech/howto/worker-install.html).

Once configured you can apply the configuration with `ryax-adm`.

The log capture service, Loki, was moved into the ryaxns namespace. Thus, the old Loki deployment can be removed.
After the apply, we have to remove the old deployment:
```sh
helm uninstall -n ryaxns-monitoring loki
kubectl delete pvc -n ryaxns-monitoring storage-loki-0
```
