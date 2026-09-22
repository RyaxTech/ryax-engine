{{/*
The GPU readiness ConfigMap payload, defined once so the pod templates can hash
it: node-problem-detector reads its configuration only at startup, and the
untainter's loop *is* the ConfigMap, so neither picks a change up on its own.

Note which "reason" goes where: conditions[].reason is the NOT-ready reason
(node-problem-detector's default for the condition) and rules[].reason is the
ready one. That follows from the inverted exit-code contract documented in
files/check-gpu-ready.sh.
*/}}
{{- define "worker-k8s.gpuReadiness.configData" -}}
gpu-ready-monitor.json: |
  {
    "plugin": "custom",
    "pluginConfig": {
      "invoke_interval": "{{ .Values.gpuReadiness.intervalSeconds }}s",
      "timeout": "{{ .Values.gpuReadiness.probeTimeoutSeconds }}s",
      "max_output_length": 80,
      "concurrency": 1
    },
    "source": "gpu-ready-monitor",
    "metricsReporting": false,
    "conditions": [
      {
        "type": "{{ .Values.gpuReadiness.conditionType }}",
        "reason": "NvidiaGPUNotReady",
        "message": "GPU not ready: driver down, or MIG asked for and not enabled yet. Run /config/check-gpu-ready.sh in the node-problem-detector container for which."
      }
    ],
    "rules": [
      {
        "type": "permanent",
        "condition": "{{ .Values.gpuReadiness.conditionType }}",
        "reason": "NvidiaGPUReady",
        "path": "/config/check-gpu-ready.sh",
        "timeout": "{{ .Values.gpuReadiness.probeTimeoutSeconds }}s"
      }
    ]
  }
check-gpu-ready.sh: |
{{ .Files.Get "files/check-gpu-ready.sh" | trimSuffix "\n" | indent 2 }}
untaint-gpu-nodes.sh: |
{{ .Files.Get "files/untaint-gpu-nodes.sh" | trimSuffix "\n" | indent 2 }}
watch-node-labels.sh: |
{{ .Files.Get "files/watch-node-labels.sh" | trimSuffix "\n" | indent 2 }}
{{- end }}
