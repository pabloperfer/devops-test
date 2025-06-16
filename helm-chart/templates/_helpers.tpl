{{/* ===============================================================
   base name of the chart
   - Usa .Values.nameOverride if exists , if not -> .Chart.Name
================================================================ */}}
{{- define "sample-node-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* ===============================================================
   name “fullname” (will be used by reach resource)
   rule:
     1. if exists .Values.fullnameOverride -> use at it is.
     2. if Release.Name if equal to name() → use only Release.Name
        (avoids sample-node-app-sample-node-app)
     3. otherwise -> <Release.Name>-<name()>
================================================================ */}}
{{- define "sample-node-app.fullname" -}}
{{- if .Values.fullnameOverride }}
    {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
    {{- $name := include "sample-node-app.name" . -}}
    {{- if eq .Release.Name $name }}
        {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
    {{- else }}
        {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
{{- end -}}
{{- end }}

{{/* ===============================================================
   common labels for all objects
================================================================ */}}
{{- define "sample-node-app.labels" -}}
app.kubernetes.io/name: {{ include "sample-node-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* ===============================================================
   selector labels(Deployment/Service)
================================================================ */}}
{{- define "sample-node-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sample-node-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
