{{/*
Expand the name of the chart.
*/}}
{{- define "common-resources.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "common-resources.fullname" -}}
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
{{- define "common-resources.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "common-resources.labels" -}}
{{ include "common-resources.selectorLabels" . }}
ryax.tech/resource-name: {{ include "common-resources.name" . }} # backwards compatibility
app: {{ include "common-resources.name" . }} # backwards compatibility
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "common-resources.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "common-resources.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common-resources.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

