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
- New Jupyter Notebook action with GPU support [in default actions] (https://gitlab.com/ryax-tech/workflows/default-actions/-/tree/master/triggers/jupyterlab)
- Action builds now can be canceled
- Kubernetes addon now support injection of service
- Add VPA recommendation support (experimental)


## Bug fixes and Improvements

- Fix volume permission for NFS based storage volumes (defaults to 1200 now)
- Fix fail properly when a pip install fails during builds

## Upgrade to this version

Require to add a site configuration per worker. For instance,
below a worker is deployed aside on the same kubernetes cluster hosting
Ryax. Following the site spec contains a list of nodePools. For each
nodePool the amount of cpu/memory available for nodes as weel as objective
scores need to be provided.


```yaml
worker:
  values:
     config:
       site:
         name: localworker
         spec:
           nodePools:
           - cpu: 4
             memory: 8G
             name: default
             objectiveScores:
               cost: 70
               energy: 30
               performance: 80
             selector:
               k8s.scaleway.com/pool-name: ryaxns-execs-nodes
```


Usual process: update the version in the config file and apply!

After the apply remove the old loki service that was moved into the ryaxns
namespace with:
```sh
helm uninstall -n ryaxns-monitoring loki
```
