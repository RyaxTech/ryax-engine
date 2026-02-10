We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.1.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

## New features

### Fully Compatible Helm Installation

After 5 years of development and usage of our administration tool we decided to drop the support for [ryax-adm](https://gitlab.com/ryax-tech/ryax/ryax-adm) in favor of a pure helm cluster installation and management. Hence, we strongly advise to install cluster with `ryax-adm` now, and to use helm instead. 

<!--
Developing custom tools can be very exiting and enriching with the added cost to add an additional load on the development team. Either in maintenance, development and documentation.
-->

The new installation documentation is available here [TBD]().

Furthermore, this has several implications, first we believe that it will ease the administration of ryax clusters since helm is a widely adopted tool that cluster administrators are accustomed to. Secondly, this change unfortunatelly breaks the retro-compatibility for cluster installed under ryax version 26.1.0, worfklows, images and data can be migrated but cluster installed with adm cannot be operated directly with helm and vice-versa.

Follow the migration documentation [TBD]() to migrate from and older version to 26.1.0.

### Air gap version of ryax

Ryax now supports airgapped cluster, where one can build and run worfklows in a complete isolated environment.

More information in our installation documentation related to airgapped clusters [TBD]()

### Ryax Saas

We announce also the Saas version of ryax for users that wish to go to production quickly without the need to administrate a full kubernetes cluster.
We track your the usage of resources used by workflows and charge users consequently.

To access the saas version contact our marketing team or directly register from our website at https://ryax.tech.

### Navigation and UI

- Project navigation has been improved: top bar that enables to switch between your projects
- Complete rework of the installation: now use Helm (ryax-adm is deprecated)
- Users and projects management is now in the top menu
- Resource Usage data is now available in the UI for system administrators

## Bug fixes and Improvements

- Fix URL is now strip from its whitespace when adding repository
- Project deletion when active user's current project lead to stall UI
- Move the user documentation to MkDocs

## Upgrade to this version

Unfortunatelly, as stated we deprecate the support of ryax-adm, and cluster installed with adm cannot be operated with the new helm charts. To upgrade this ryax version, we need to do a full data migration of the cluster to another cluster. Fortunatelly, we have ddesigned scripts that does exactly that.

### Requirements

To process with the migration we need to have the following:
- A ryax cluster with ryax installed with a version under 25.1.0,
- A new kubernetes cluster that will be the resulting cluster,
- A bucket S3 necessary to store the data that will be transfered between the clusters during the migration.

### Process

The migration is done in two steps, the first step backups the data of the internal minio and the database from the _old_ cluster and store it into a S3 bucket. In some cases, the registry may contains too many images to be efficiently stored into a s3 bucket. It is possible to move directly the containers images from one cluster to the another using skopeo.

To execute the first step, on the __old__ cluster one can use the following command.

*TODO with Pedro: Explain both solution with backup or with direct transfer between registry*

```bash
kubectl -n {{ .Release.Namespace }} create job --from=cronjob/{{ include "ryax-backup.fullname" . }} {{ include "ryax-backup.fullname" . }}
```

The second step is to import the data in the new cluster. For that you need to be able to run `kubectl` command on the __new__ cluster.


<!--
However, it is still possible to upgrade cluster to 26.1.0 with adm to install the latest bug fix and features (althoug you it is not possible to use the airgap version with this technique).
-->

