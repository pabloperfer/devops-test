{{- /*
This Kubernetes Ingress resource defines how external HTTP/HTTPS traffic is routed
to our `sample-node-app` within the EKS cluster. It leverages the AWS Load Balancer Controller
to provision and manage an Application Load Balancer (ALB) in AWS based on these definitions.

Key goals for this Ingress:
1.  Expose the application to the internet.
2.  Listen for HTTP traffic on port 80.
3.  Route traffic based on host and path to the appropriate Kubernetes Service.
*/ -}}


{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "sample-node-app.fullname" . }}  # Sets the name of the Ingress resource based on the Helm release name.
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }}   # Applies standard labels for organization and identification.
  annotations:
     {{- /*
    ALB-specific annotations: These annotations are critical for the AWS Load Balancer Controller.
    They instruct the controller on how to configure the underlying AWS Application Load Balancer (ALB).
    */}}
    alb.ingress.kubernetes.io/scheme: {{ .Values.ingress.scheme | default "internet-facing" | quote }}  # Defines the ALB's scheme: "internet-facing" for public access, "internal" for private VPC access. Defaulting to "internet-facing" as required for external exposure.
    alb.ingress.kubernetes.io/target-type: ip   # Specifies how the ALB routes traffic to pods. "ip" directly targets pod IPs (recommended for EKS), "instance" targets EC2 instance IPs.
    {{- with .Values.ingress.listenPorts }}
    alb.ingress.kubernetes.io/listen-ports: {{ . | quote }}
    {{- end }}
    {{- with .Values.ingress.loadBalancerName }}
    alb.ingress.kubernetes.io/load-balancer-name: {{ . | quote }}
    {{- end }}

    {{- /* Extra user-defined annotations: This block allows for injecting additional, custom annotations from values.yaml.
    This provides flexibility for advanced ALB configurations (e.g., WAF integration, specific security groups, SSL policies).
    */}}
    {{- with .Values.ingress.extraAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}

spec:
  ingressClassName: {{ .Values.ingress.className | default "alb" }}
  rules:
    {{- range .Values.ingress.hosts }}
  #  - host: {{ .host | quote }}   # commented out to for testing without host to the alb
  #   http:
  #      paths:
  #        - path: {{ .path | default "/" | quote }}
  #          pathType: {{ .pathType | default "Prefix" }}
  #          backend:
  #            service:
  #              name: {{ include "sample-node-app.fullname" $ }}
  #              port:
  #                number: {{ $.Values.service.port }}
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "sample-node-app.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
    {{- end }}

  {{- if .Values.ingress.tls }}
  # TLS configuration enables HTTPS for the Ingress, allowing secure communication.
  # This section requires a Kubernetes Secret containing the TLS certificate and key.
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- toYaml .hosts | nindent 8 }} # List of hostnames covered by this TLS certificate.
      secretName: {{ .secretName }} # The name of the Kubernetes Secret that contains the TLS certificate and key (e.g., 'my-tls-secret'). The ALB will use this for SSL termination.
    {{- end }}
  {{- end }}
{{- end }}