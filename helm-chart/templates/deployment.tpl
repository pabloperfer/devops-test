{{- /*
Deployment for the sample Node.js application.
It relies on helpers in _helpers.tpl and on values set in values.yaml
*/ -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sample-node-app.fullname" . }}        # → p. ej. sample-node-app-prod
  labels:
    {{- include "sample-node-app.labels" . | nindent 4 }} #  standard labels
spec:
  replicas: {{ .Values.replicaCount }}                    # set in values.yaml
  selector:
    matchLabels:
      {{- include "sample-node-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "sample-node-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}                # allows to use a secret if needed
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      containers:
        - name: {{ include "sample-node-app.name" . }}    # container name = chart name
          image: "{{ .Values.image.repository }}:{{ default .Chart.AppVersion .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}

          ports:
            - name: http
              containerPort: {{ .Values.service.port }}

          # env vars
          env:
            - name: PORT
              value: "{{ .Values.env.PORT | default "3000" }}"

            # config map env var
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: {{ include "sample-node-app.fullname" . }}-config
                  key: app_env

          # Injects all vars within a secret
          envFrom:
            - secretRef:
                name: {{ include "sample-node-app.fullname" . }}-secret

          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}

      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}