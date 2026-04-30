We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.4.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

## New features

### New scheduling policy

We have added a new multi-objective scheduler that combines static scores, runtime prediction, node-pool pricing,
and empirical execution history to automatically select the best execution pool according to performance and cost preferences.

### Site Registation

The Ryax Site registration (from the main site to one with a Worker) is now done in the Ryax UI.
This simplifies the Worker configuration make it more secure and fix issues with dynamic registration token.
    
## Bug fixes and Improvements

- Fix unable to create user in the UI
- Centralized Helm repository in ryax-engine so simplify install and development
- Emit Evry and Stop action is now propely stopping in all case
- Fix memory warm start with last successful allocation in Intelliscale
- Reduce Intelliscale recomendation timeout to avoid stall deployment
- Modularize scheduling policies to prepare external policies support

## Upgrade to this version

The Worker that was packaged inside the Ryax installation is now removed and the Worker install will be done separately.
This simplify the configuration and make the Ryax installation independant of user code execution.

TODO: Test and explain process or point to the doc
