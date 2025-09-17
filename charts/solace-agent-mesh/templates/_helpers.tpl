{{/*
Expand the name of the chart.
*/}}
{{- define "sam.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sam.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "sam.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sam.labels" -}}
helm.sh/chart: {{ include "sam.chart" . }}
{{ include "sam.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sam.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sam.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sam.podAnnotations" -}}
{{- if .Values.podAnnotations }}
{{- .Values.podAnnotations | toYaml }}
{{- end }}
{{- end }}

{{- define "sam.podLabels" -}}
{{- if .Values.podLabels }}
{{- .Values.podLabels | toYaml }}
{{- end }}
{{- end }}

{{- define "sam.annotations" -}}
{{- if .Values.annotations }}
annotations:
  {{- .Values.annotations | toYaml | nindent 2 }}
{{- end }}
{{- end }}

{{- define "sam.ddtags" -}}
{{- $tags := list }}
{{- if .Values.datadog.tags }}
{{- range $key, $value := .Values.datadog.tags }}
  {{- $tags = printf "%s:%s" $key $value | append $tags }}
{{- end }}
{{- end }}
{{- join " " $tags }}
{{- end }}

{{- define "sam.hostname" -}}
{{- if .Values.sam.hostname }}
{{- printf "%s:%d" .Values.sam.hostname }}
{{- else }}
{{- fail "No valid SAM endpoint defined. Please set sam.hostname in values.yaml." }}
{{- end }}
{{- end }}

{{- define "sam.webUiPort" -}}
{{- if .Values.sam.webUiPort }}
{{- printf "%s:%d" .Values.sam.webUiPort }}
{{- else }}
{{- fail "No valid SAM webUiPort port defined. Please set sam.webUiPort in values.yaml." }}
{{- end }}
{{- end }}
