apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sample-node-app.fullname" . }}-config
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}
data:
  # use a nil-safe lookup; falls back to "production"
  app_env: {{ default "production" (index (default dict .Values.config) "appEnv") | quote }}

  # render any optional extra entries
  {{- with (index (default dict .Values.config) "extra") }}
  {{- toYaml . | nindent 2 }}
  {{- end }}