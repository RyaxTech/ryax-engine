{{/*
Expand the name of the chart.
*/}}
{{- define "worker-k8s.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "worker-k8s.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Create a secret name to be shared between the charts for the database secret.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "worker-k8s.postgresql.secret" -}}
{{- printf "%s-db-pass" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The postgresql service name to be called from worker, i.e. the name the bitnami
subchart gives its own service.

Delegate to the subchart's own naming helper instead of computing a name and
asking the subchart to adopt it: values files are not templated, so a name that
depends on .Release cannot be handed to the subchart through values (this used to
be attempted with a "fullNameOverride" key, which bitnami does not read -- its
key is "fullnameOverride" -- so the subchart kept its default name while the
database URL below pointed somewhere else, and the migration init container
failed to resolve the host).

Deriving it this way also means a user who sets postgresql.nameOverride or
postgresql.fullnameOverride keeps a working URL, and only ever needs to set them
on one side.

Only call this where the subchart is present (it is guarded by
postgresql.enabled, matching the dependency condition in Chart.yaml), since
common.* comes from the subchart.
*/}}
{{- define "worker-k8s.postgresql.service" -}}
{{- include "common.names.fullname" (dict "Values" .Values.postgresql "Chart" (dict "Name" "postgresql") "Release" .Release) -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "worker-k8s.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "worker-k8s.labels" -}}
{{ include "worker-k8s.selectorLabels" . }}
ryax.tech/resource-name: {{ include "worker-k8s.name" . }} # backwards compatibility
app: {{ include "worker-k8s.name" . }} # backwards compatibility
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "worker-k8s.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "worker-k8s.selectorLabels" -}}
app.kubernetes.io/name: {{ include "worker-k8s.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the proper image name.
*/}}
{{- define "worker-k8s.image" -}}
{{- $registryName := default .Values.image.registry .Values.global.imageRegistry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $separator := ":" -}}
{{- $termination := .Values.image.tag | toString -}}

{{- if not .Values.image.tag }}
  {{- if .chart }}
    {{- $termination = .chart.AppVersion | toString -}}
  {{- end -}}
{{- end -}}
{{- if .Values.image.digest }}
    {{- $separator = "@" -}}
    {{- $termination = .Values.image.digest | toString -}}
{{- end -}}
{{- if $registryName }}
    {{- printf "%s/%s%s%s" $registryName $repositoryName $separator $termination -}}
{{- else -}}
    {{- printf "%s%s%s"  $repositoryName $separator $termination -}}
{{- end -}}
{{- end -}}

