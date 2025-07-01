apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sample-node-app.fullname" . }}-config
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}
data:
  # Sets the `app_env` environment variable for the application.
  # It safely retrieves the value from `.Values.config.appEnv`, falling back to "production" if not specified.
  app_env: {{ default "production" (index (default dict .Values.config) "appEnv") | quote }}

 # Renders any optional extra key-value pairs defined under `config.extra` in values.yaml.
 # This provides flexibility for adding custom configuration parameters without modifying the template.
 # extra is a dictionary with a list of key value pairs that will be added under data:
 # if no value the block is not processed
  
  {{- with (index (default dict .Values.config) "extra") }}
  {{- toYaml . | nindent 2 }}
  {{- end }}