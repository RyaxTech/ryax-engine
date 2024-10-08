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
- Action builds might now be canceled if necessary
- Kubernetes addon now support injection of service

## Bug fixes and Improvements

- Fix volume permission for NFS based storage volumes (defaults to 1200 now)
- Fix fail properly when a pip install fails during builds

## Upgrade to this version

Usual process: update the version in the config file and apply!

After the apply remove the old loki service that was moved into the ryaxns
namespace with:
```sh
helm uninstall -n ryaxns-monitoring loki
```
