We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 24.12.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

Stability and better UI experience

## New features

- GPU support for SSH SLURM with Singularity
- Runtime Class support for the Kubernetes add-on
- Action Builder now use a persistent cache (Nix Store)

## Bug fixes and Improvements

- Use PostgreSQL instead of SQLite as database by default for the Worker
- Fix Dynamic Output edition form UI reload too often
- Better deploy constraints settings site type filter
- Fix CPU per task option for in Slurm execution mode
- Fix Worker configuration update is now taken into account
- Fix missing logs for very short execution
- Avoid workflow error when double deploy
- Avoid action stuck on Building in case of Action Builder failure
- Fix RabbitMQ memory leaking due to dangling queues

## Upgrade to this version

Because the Worker changes database it, the Runner and all workers should be cleaned.

After the applying the update with ryax-adm, runs:
```sh
ryax-adm clean worker runner
```
For external workers run:
```sh
helm update -n ryaxns --reuse-values
```
