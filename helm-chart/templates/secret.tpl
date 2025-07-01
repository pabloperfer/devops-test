apiVersion: v1
kind: Secret
metadata:
  name: {{ include "sample-node-app.fullname" . }}-secret  # Uses the full name helper for consistent naming.
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}  # Applies common labels for discoverability.
type: Opaque  # Defines the type of Secret. "Opaque" is a generic type for arbitrary user-defined data.
stringData:   # Use `stringData` to provide data as plain strings (Helm will base64 encode it automatically).
  DB_PASSWORD: {{ .Values.secret.DB_PASSWORD | quote }}  # Injects the database password from values.yaml as an environment variable into the application Pods.
