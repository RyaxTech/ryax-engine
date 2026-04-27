{{/*
Expand the name of the chart.
*/}}
{{- define "worker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "worker.fullname" -}}
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
{{- define "worker.postgresql.secret" -}}
{{- printf "%s-db-pass" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a postgresql service name to be called from worker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "worker.postgresql.service" -}}
{{- printf "%s-postgresql" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "worker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "worker.labels" -}}
{{ include "worker.selectorLabels" . }}
ryax.tech/resource-name: {{ include "worker.name" . }} # backwards compatibility
app: {{ include "worker.name" . }} # backwards compatibility
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "worker.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "worker.name" . }}
{{ $instanceOverride := default .Release.Name .Values.instanceOverride -}}
app.kubernetes.io/instance: {{ printf "%s" $instanceOverride }}
{{- end }}

{{/*
Return the proper image name.
*/}}
{{- define "worker.image" -}}
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

