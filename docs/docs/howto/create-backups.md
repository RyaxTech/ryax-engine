# Backup Ryax with Velero

To create a backup of Ryax you can use Velero. The process describe here is base on the Velero [FileStytemBackup](https://velero.io/docs/v1.13/file-system-backup/) that provides Persistent Volume backup in any Kubernetes installation.

## Prerequisites

- Create a bucket on an S3 compatible storage (AWS, Minio, ...)
- Create a secret with write access to this bucket
- Install Velero on your local machine

## Install

!!! warning
    Be sure that your Kubernetes context point to the Ryax cluster you want to backup.


Put you credentials in a local file (replace with appropriate values):
```toml
[default]
aws_access_key_id=ACCESS_KEY
aws_secret_access_key=SECRET_KEY
```

Run this command to install Velero on your cluster (set storage url and region):
```sh
velero install \
--provider velero.io/aws \
--bucket ryax-backups \
--plugins velero/velero-plugin-for-aws:v1.7.0 \
--backup-location-config s3Url=https://<S3_STORAGE_URL>,region=<S3_STORAGE_REGION> \
--use-volume-snapshots=false \
--use-node-agent \
--default-volumes-to-fs-backup \
--secret-file=./velero-credentials
```

Now, you should able to create a backup with:
```sh
velero backup create my-ryax-cluster --ttl 336h --default-volumes-to-fs-backup
```

If you want regular backup of your system, you can for example create a daily
backup that runs every day at 3am which is kept for 2 weeks with:
```sh
velero schedule create daily-ryax-backup --schedule "0 3 * * *" --ttl 336h
```

