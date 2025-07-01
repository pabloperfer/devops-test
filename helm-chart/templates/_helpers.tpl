{{/* ===============================================================
This file contains reusable templates (helpers) that define common naming
conventions and labels used across multiple Kubernetes resources in this chart.
This promotes consistency and reduces redundancy.
================================================================ */}}


{{/*
Returns the base name of the chart.
It checks if `.Values.nameOverride` is provided; otherwise, it defaults to `.Chart.Name`.
The output is truncated to 63 characters and trailing hyphens are removed,
adhering to Kubernetes naming conventions.
*/}}

{{- define "sample-node-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}


{{/*
Generates the "fullname" for resources within the chart. This ensures
that resources have unique, predictable names, typically combining the Helm
release name and the chart name.

The naming rule is:
1. If `.Values.fullnameOverride` exists, it's used as is.
2. If `Release.Name` is equal to the base name (`sample-node-app.name`),
   only `Release.Name` is used to avoid redundant names like "app-app".
3. Otherwise, it combines `<Release.Name>-<base name>`.
*/}}


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

{{/*
Defines a set of common labels applied to all Kubernetes objects managed by this chart.
These labels are crucial for organizing and querying resources within Kubernetes.
- `app.kubernetes.io/name`: The name of the application.
- `app.kubernetes.io/instance`: The unique name of the Helm release.
- `app.kubernetes.io/version`: The application version from Chart.yaml (AppVersion field).
- `app.kubernetes.io/managed-by`: Indicates that the resource is managed by Helm.
*/}}

{{- define "sample-node-app.labels" -}}
app.kubernetes.io/name: {{ include "sample-node-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
Defines a subset of labels specifically used for selectors (e.g., in Deployments and Services).
These labels are used by Kubernetes to link Services to Pods and Deployments to Pods.
- `app.kubernetes.io/name`: Used to identify the application.
- `app.kubernetes.io/instance`: Used to identify the specific release instance.
*/}}


{{/* ===============================================================
   selector labels(Deployment/Service)
================================================================ */}}
{{- define "sample-node-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sample-node-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
