{{/*
Name of the RabbitmqCluster, and so of the broker Service.
*/}}
{{- define "rabbitmq.fullname" -}}
{{- .Values.fullnameOverride | default "ryax-broker" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the operator Deployment and of its ServiceAccount and Role.
*/}}
{{- define "rabbitmq.operatorName" -}}
{{- printf "%s-operator" (include "rabbitmq.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "rabbitmq.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels of the chart's own objects. The operator copies the RabbitmqCluster's
labels to everything it creates, except the app.kubernetes.io ones it sets
itself, which is what lets the operator select its pods by those.
*/}}
{{- define "rabbitmq.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "rabbitmq.chart" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "rabbitmq.operatorSelectorLabels" -}}
app.kubernetes.io/name: {{ include "rabbitmq.operatorName" . }}
app.kubernetes.io/component: rabbitmq-operator
{{- end }}
