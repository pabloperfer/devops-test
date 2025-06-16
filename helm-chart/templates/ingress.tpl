{{- /*
Ingress backed by AWS Load Balancer Controller (ALB)
*/ -}}
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "sample-node-app.fullname" . }}
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}
  annotations:
    {{- /* ALB-specific annotations */}}
    alb.ingress.kubernetes.io/scheme: {{ .Values.ingress.scheme | default "internet-facing" | quote }}
    alb.ingress.kubernetes.io/target-type: ip
    {{- with .Values.ingress.listenPorts }}
    alb.ingress.kubernetes.io/listen-ports: {{ . | quote }}
    {{- end }}
    {{- with .Values.ingress.loadBalancerName }}
    alb.ingress.kubernetes.io/load-balancer-name: {{ . | quote }}
    {{- end }}

    {{- /* Anotaciones extra definidas por el usuario */}}
    {{- with .Values.ingress.extraAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}

spec:
  ingressClassName: {{ .Values.ingress.className | default "alb" }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          - path: {{ .path | default "/" | quote }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ include "sample-node-app.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
    {{- end }}

  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- toYaml .hosts | nindent 8 }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
{{- end }}