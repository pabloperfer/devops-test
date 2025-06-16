apiVersion: v1
kind: Secret
metadata:
  name: {{ include "sample-node-app.fullname" . }}-secret
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}
type: Opaque
stringData:
  DB_PASSWORD: {{ .Values.secret.DB_PASSWORD | quote }}
