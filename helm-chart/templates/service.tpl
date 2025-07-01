{{- /*
###############################################################################
# Service template
# -----------------------------------------------------------------------------
# This template defines a Kubernetes Service resource for the `sample-node-app`.
# A Service provides a stable network endpoint for accessing the application's Pods,
# abstracting away the dynamic nature of Pod IPs.
# It uses helpers defined in `_helpers.tpl` and retrieves values from `values.yaml`
# under the `.Values.service.*` path.
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
  clusterIP: {{ .Values.service.clusterIP }}   # Optionally sets a specific cluster IP. If omitted, Kubernetes assigns one.
  {{- end }}
  {{- if .Values.service.externalIPs }}
  externalIPs:
    {{- toYaml .Values.service.externalIPs | nindent 4 }}  #  Optionally assigns external IPs to the Service.
  {{- end }}
  type: {{ .Values.service.type | default "ClusterIP" }}  # Defines the Service type (e.g., ClusterIP, NodePort, LoadBalancer). Defaults to "ClusterIP" for internal cluster access.
  selector:
    {{- include "sample-node-app.selectorLabels" . | nindent 4 }}  # Defines how the Service identifies which Pods to route traffic to, based on matching labels.
  ports:
    - name: http
      port: {{ .Values.service.port | default 80 }} # The port exposed by the Service within the cluster. This is what other services or the Ingress will target.
      targetPort: {{ .Values.service.targetPort | default 3000 }} # The port on the Pods to which the Service will forward traffic. This is where your application listens inside the container.
      protocol: TCP