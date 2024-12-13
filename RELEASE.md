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

Because the Worker changes from SQLite database to PostgreSQL you have to reset its state.
To do so, remove the worker with:
```sh
helm uninstall ryax-worker -n ryaxns
```
We also need to clean broker state to clean internal state:
```
helm uninstall rabbitmq -n ryaxns
kubectl delete pvc -n ryaxns data-ryax-broker-0
```

Runner should be cleaned also:
```sh
ryax-adm clean runner
```

For external workers be sure that you have the values.yaml file that you used
for the previous installation and then run, for example:
```sh
helm uninstall ryax-other-worker -n ryaxns
helm install -n ryaxns --values ryax-other-worker.yaml
```

Then apply the update as usual.
