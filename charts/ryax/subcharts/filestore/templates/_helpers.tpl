{{/*
Name of the Deployment and of its PVC.
*/}}
{{- define "filestore.fullname" -}}
{{- .Values.fullnameOverride | default "ryax-filestore" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "filestore.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "filestore.selectorLabels" -}}
app.kubernetes.io/name: filestore
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "filestore.labels" -}}
{{ include "filestore.selectorLabels" . }}
ryax.tech/resource-name: filestore
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "filestore.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "filestore.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) }}
{{- end }}

{{- define "filestore.claimName" -}}
{{- .Values.persistence.existingClaim | default (include "filestore.fullname" .) }}
{{- end }}

{{/*
Placement of every pod of the chart: its own value, else the global one.
*/}}
{{- define "filestore.placement" -}}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations | default .Values.global.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector | default .Values.global.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity | default .Values.global.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "filestore.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 1200
runAsGroup: 1200
fsGroup: 1200
fsGroupChangePolicy: OnRootMismatch
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "filestore.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: [ALL]
{{- end }}

{{/* ----------------------------------------------------------------------
  Migration from the MinIO of Ryax 26.9
---------------------------------------------------------------------- */}}

{{/*
Name of the MinIO Deployment and PVC of Ryax 26.9: the Bitnami chart named
both after the release.
*/}}
{{- define "filestore.legacyName" -}}
{{- printf "%s-minio" .Release.Name }}
{{- end }}

{{/*
The Bitnami chart's pod selector. A Deployment's selector cannot change, so
the old MinIO keeps it to be updated in place rather than replaced.
*/}}
{{- define "filestore.legacySelectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: minio
app.kubernetes.io/component: minio
app.kubernetes.io/part-of: minio
{{- end }}

{{- define "filestore.migrationImage" -}}
{{- printf "%s:%s" .Values.migration.image.repository (.Values.migration.image.tag | toString) }}
{{- end }}

{{/*
"true" when the chart is rendered against a cluster (`helm install` and
`upgrade`), empty when it is rendered without one (`helm template`, ArgoCD,
Flux), where every lookup returns nothing.

Two gets, no list: every namespace holds kube-root-ca.crt, and kube-system is
only asked for when the release namespace does not exist yet, as on a first
`helm install --create-namespace`. Helm renders before it creates the
namespace.
*/}}
{{- define "filestore.online" -}}
{{- if lookup "v1" "ConfigMap" .Release.Namespace "kube-root-ca.crt" -}}
true
{{- else if lookup "v1" "Namespace" "" "kube-system" -}}
true
{{- end -}}
{{- end }}

{{/*
"true" when this render carries the old MinIO and the copy from it. Against a
cluster, only when the old volume is there to copy from; without a cluster the
chart cannot tell, and `migration.enabled` alone decides.
*/}}
{{- define "filestore.migrating" -}}
{{- if .Values.migration.enabled -}}
{{- if not (include "filestore.online" .) -}}
true
{{- else if lookup "v1" "PersistentVolumeClaim" .Release.Namespace (include "filestore.legacyName" .) -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Size of the filestore volume. A PVC cannot shrink, so the size of the one
already there wins over the default; on the upgrade that creates it, the
volume is sized after MinIO's, which the copy has to fit in.
*/}}
{{- define "filestore.size" -}}
{{- $current := lookup "v1" "PersistentVolumeClaim" .Release.Namespace (include "filestore.fullname" .) -}}
{{- $legacy := lookup "v1" "PersistentVolumeClaim" .Release.Namespace (include "filestore.legacyName" .) -}}
{{- if .Values.persistence.size -}}
{{- .Values.persistence.size -}}
{{- else if $current -}}
{{- $current.spec.resources.requests.storage -}}
{{- else if and $legacy (include "filestore.migrating" .) -}}
{{- $legacy.spec.resources.requests.storage -}}
{{- else if include "filestore.migrating" . -}}
{{- .Values.migration.legacy.persistence.size -}}
{{- else -}}
20Gi
{{- end -}}
{{- end }}

{{/*
The filestore PVC, shared by its own template and by the pre-copy, which
creates it ahead of the upgrade.
*/}}
{{- define "filestore.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "filestore.fullname" . }}
  labels: {{- include "filestore.labels" . | nindent 4 }}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: {{ include "filestore.size" . | quote }}
  {{- with .Values.persistence.storageClass | default .Values.global.defaultStorageClass }}
  storageClassName: {{ . | quote }}
  {{- end }}
{{- end }}

{{/*
Environment of the copy: where MinIO is, and its root credentials, which are
the filestore's too.
*/}}
{{- define "filestore.copyEnv" -}}
- name: SOURCE_HOST
  value: {{ .source | quote }}
- name: WAIT_SECONDS
  value: {{ .waitSeconds | quote }}
- name: ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.filestoreSecret }}
      key: root-user
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.filestoreSecret }}
      key: root-password
{{- end }}

{{/*
The copy from MinIO to the filestore volume, mounted at /data. It runs in the
MinIO image, for its `mc` client.

The objects become plain files under /data/s3/<bucket>/<key>, which is how
versitygw stores them. MinIO's own `xl.meta` layout cannot be read without
MinIO, so the copy goes through its S3 API.

`mc mirror --overwrite --remove` makes the destination equal to the source
whatever an earlier, possibly interrupted, run left there: it copies what is
missing, overwrites what differs in size or is newer in MinIO than on the
volume, and deletes what MinIO no longer has.

Mode "precopy" runs ahead of the upgrade, while Ryax still writes to MinIO.
It dates every file it copies back to its own start time minus a margin, so
that the final copy sees as newer, and copies again, any object written while
it ran, even one rewritten with the same size.

Mode "final" runs once in the filestore pod at the upgrade, when nothing
writes to MinIO any more. It checks that both sides list the same objects and
sizes, then leaves the marker that makes every later start skip the copy.
*/}}
{{- define "filestore.copyScript" -}}
set -eu
MC=/opt/bitnami/minio-client/bin/mc
MARKER=/data/.ryax-migrated-from-minio
DEST=/data/s3
SOURCE="http://$SOURCE_HOST:9000"
export HOME=/tmp MC_CONFIG_DIR=/tmp/.mc

if [ -f "$MARKER" ]; then
  echo "The objects were copied from MinIO on $(cat "$MARKER"): nothing to do."
  exit 0
fi

echo "Waiting for MinIO at $SOURCE"
waited=0
until curl -fs -o /dev/null "$SOURCE/minio/health/live"; do
  if [ "$WAIT_SECONDS" -gt 0 ] && [ "$waited" -ge "$WAIT_SECONDS" ]; then
    echo "No MinIO answers at $SOURCE after ${waited}s." >&2
    exit 1
  fi
  sleep 5
  waited=$((waited + 5))
done

"$MC" alias set legacy "$SOURCE" "$ACCESS_KEY" "$SECRET_KEY" >/dev/null
"$MC" ls legacy > /tmp/buckets
buckets=$(awk '{print $NF}' /tmp/buckets | tr -d /)
start=$(date +%s)
mkdir -p "$DEST"
for bucket in $buckets; do
  echo "Copying bucket $bucket"
  mkdir -p "$DEST/$bucket"
  "$MC" mirror --quiet --overwrite --remove "legacy/$bucket" "$DEST/$bucket" >/dev/null
done
for dir in "$DEST"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  case " $(echo $buckets) " in
    *" $name "*) ;;
    *) echo "Removing $name, a bucket MinIO no longer has"; rm -rf "$dir" ;;
  esac
done
# An interrupted mc leaves its partial files, which mirror --remove skips.
find "$DEST" -type f -name '*.part.minio' -delete
count=$(find "$DEST" -type f | wc -l)
{{- if eq .mode "precopy" }}
stamp=$((start - 600))
find "$DEST" -type f -newermt "@$stamp" -exec touch -m -d "@$stamp" {} +
echo "Pre-copied $count objects in $(($(date +%s) - start))s. The upgrade copies only what changes from now on."
{{- else }}
for bucket in $buckets; do
  "$MC" diff "legacy/$bucket" "$DEST/$bucket" > /tmp/diff
  if [ -s /tmp/diff ]; then
    echo "The copy of bucket $bucket differs from MinIO:" >&2
    head -n 20 /tmp/diff >&2
    exit 1
  fi
done
date -u +%Y-%m-%dT%H:%M:%SZ > "$MARKER.tmp"
mv "$MARKER.tmp" "$MARKER"
echo "Copied $count objects from MinIO in $(($(date +%s) - start))s."
{{- end }}
{{- end }}

{{/*
Labels of the pre-copy Job and pod: not the filestore's, which the Service
selects.
*/}}
{{- define "filestore.precopyLabels" -}}
app.kubernetes.io/name: filestore-precopy
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "filestore.chart" . }}
{{- end }}
