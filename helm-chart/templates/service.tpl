{{- /*
###############################################################################
# Service template
# -----------------------------------------------------------------------------
# - Usa helpers defined in _helpers.tpl
# - values can be configured in values.yaml → .Values.service.*
###############################################################################
*/ -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sample-node-app.fullname" . }}
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.service.clusterIP }}
  clusterIP: {{ .Values.service.clusterIP }}
  {{- end }}
  {{- if .Values.service.externalIPs }}
  externalIPs:
    {{- toYaml .Values.service.externalIPs | nindent 4 }}
  {{- end }}
  type: {{ .Values.service.type | default "ClusterIP" }}
  selector:
    {{- include "sample-node-app.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port | default 80 }}
      targetPort: {{ .Values.service.targetPort | default 3000 }}
      protocol: TCP