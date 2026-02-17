We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.2.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

## New features

### Fully Compatible Helm Installation

After 5 years of development and usage of our administration tool, we decided to drop the support for [ryax-adm](https://gitlab.com/ryax-tech/ryax/ryax-adm) in favor of a pure Helm cluster installation and management. Hence, we strongly advise installing a cluster with `ryax-adm` now and using Helm instead. 

<!--
Developing custom tools can be very exciting and enriching, with the added cost of adding another load on the development team. Either in maintenance, development, or documentation.
-->

The new installation documentation is available here [TBD]().

Furthermore, this has several implications. First, we believe that it will ease the administration of Ryax clusters since Helm is a widely adopted tool that cluster administrators are accustomed to. Secondly, this change unfortunately breaks the retro-compatibility for clusters installed under Ryax version 26.2.0, worfklows, images and data can be migrated, but clusters installed with adm cannot be operated directly with Helm and vice versa.

For the moment, the moment cluster installed with versions before 26.2.x can still be managed with ryax-adm. We intend to implement migration tools to migrate clusters to pure-helm installation without data loss.

<!-- Follow the migration documentation [TBD]() to migrate from and older version to 26.2.0. -->

### Air gap version of ryax

Ryax now supports air-gapped clusters, where one can build and run workflows in a completely isolated environment.

More information in our installation documentation related to air-gapped clusters [TBD]()

### Ryax Saas

We  also announce the SaaS version of Ryax for users that wish to go to production quickly without the need to administrate a full Kubernetes cluster.
We track the usage of resources used by workflows and charge users consequently.

To access the SaaS version, contact our marketing team or directly register from our website at https://ryax.tech.

### Navigation and UI

- Project navigation has been improved: a top bar that enables you switching between your projects.
- Complete rework of the installation: now use Helm (ryax-adm is deprecated)
- User and project management is now in the top menu for admins.
- Resource usage data is now available in the UI for system administrators.
- We added an infrastructure view that shows the current topology of the underlying infrastructure (including workers, sites, and node pools).

## Bug fixes and Improvements

- Fix URL is now stripped of its whitespace when adding a repository.
- Project deletion when the active user's current project leads to a stalled UI
- Move the user documentation to MkDocs

## Upgrade to this version

Unfortunately, as stated, we deprecate the support of ryax-adm, and the cluster installed with adm cannot be operated with the new helm charts. To upgrade this Ryax version, we need to do a full data migration of the cluster to another cluster; __we are currently working on the migration process__.

However, it is still possible to upgrade the cluster to 26.2.0 with adm to install the latest bug fix and features (although it is not possible to use the airgap version with this technique).
