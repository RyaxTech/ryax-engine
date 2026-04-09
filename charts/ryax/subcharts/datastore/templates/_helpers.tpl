{{/*
Expand the name of the chart.
*/}}
{{- define "datastore.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "datastore.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "datastore.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "datastore.labels" -}}
{{ include "datastore.selectorLabels" . }}
ryax.tech/resource-name: {{ include "datastore.name" . }} # backwards compatibility
app: {{ include "datastore.name" . }} # backwards compatibility
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "datastore.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "datastore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "datastore.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
