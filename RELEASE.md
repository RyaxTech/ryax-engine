We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 24.06.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

Control and stability.

## New features

- Add a Kubernetes Addon to customize action deployment (label, nodeSelector, annotations, serviceAccount)

## Bug fixes and Improvements

- Fix impossible to add dynamic output enum Values
- Fix addon default values from ryax_metadata.yaml no available in UI
- Better error handling for action deployments
- Fix hpc addon support of files in custom script
- Fix python-cuda build fails in some case
- Fix UID overlap when using NFS CSI Driver
- Fix OutOfMemory during git scan lead to inconsistent state

## Upgrade to this version

Usual process: update the version in the config file and apply!
