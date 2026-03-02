We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.2.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

## New features

### Fully Compatible Helm Installation

Starting from 26.2.0 release installation is done using helm and ryax-adm must not be used anymore.
The new installation documentation is available [here](https://docs.ryax.tech/howto/install_ryax_kubernetes/).

The switch from ryax-adm to helm breaks the retro-compatibility for clusters installed under Ryax version 26.2.0. Worfklows, images and data can be migrated, but clusters installed with adm cannot be operated directly with Helm and vice versa.

**We are developing tools to migrate clusters to pure-helm installation without data loss.**

### Air gap version of ryax

Ryax now supports air-gapped clusters, where one can build and run workflows in a completely isolated environment.

More information in our installation documentation related to air-gapped clusters [here](https://docs.ryax.tech/howto/install_ryax_kubernetes_airgap).

### Navigation and UI

- This release also brings new features related to the fine-grain observability of executions and resources consumption.
- Project navigation has been improved: a top bar that enables you switching between your projects.
- User and project management is now in the top menu for admins.
- Resource usage data is now available in the UI for system administrators.
- We added an infrastructure view that shows the current topology of the underlying infrastructure (including workers, sites, and node pools).
- Complete rework of the installation: now use Helm (ryax-adm is deprecated).

## Bug fixes and Improvements

- Fix URL is now stripped of its whitespace when adding a repository.
- Project deletion when the active user's current project leads to a stalled UI.
- Move the user documentation to MkDocs.

## Upgrade to this version

Upgrade of old Ryax versions (prior to 26.2) will need to go through adapted cluster migration. Procedure will be provided soon. Users needing a rapid migration can contact us directly.

