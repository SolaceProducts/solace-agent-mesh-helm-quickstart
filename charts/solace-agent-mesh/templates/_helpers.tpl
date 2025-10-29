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

{{- define "sam.serviceSelectorLabels" -}}
app.kubernetes.io/name: {{ include "sam.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: core
{{- end }}

{{- define "sam.podAnnotations" -}}
{{- if .Values.samDeployment.podAnnotations }}
{{- .Values.samDeployment.podAnnotations | toYaml }}
{{- end }}
{{- end }}

{{- define "sam.podLabels" -}}
{{- if .Values.samDeployment.podLabels }}
{{- .Values.samDeployment.podLabels | toYaml }}
{{- end }}
{{- end }}

{{- define "sam.annotations" -}}
{{- if .Values.samDeployment.annotations }}
annotations:
  {{- .Values.samDeployment.annotations | toYaml | nindent 2 }}
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
{{- if .Values.sam.dnsName }}
{{- printf "%s:%d" .Values.sam.dnsName }}
{{- else }}
{{- fail "No valid SAM endpoint defined. Please set sam.dnsName in values.yaml." }}
{{- end }}
{{- end }}

{{- define "sam.webUiPort" -}}
{{- if .Values.sam.webUiPort }}
{{- printf "%s:%d" .Values.sam.webUiPort }}
{{- else }}
{{- fail "No valid SAM webUiPort port defined. Please set sam.webUiPort in values.yaml." }}
{{- end }}
{{- end }}

{{/*
S3 configuration helpers - generates consistent S3 settings based on namespaceId
*/}}

{{/*
Get S3 bucket name (same as namespaceId)
*/}}
{{- define "sam.s3.bucketName" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s" .Values.global.persistence.namespaceId }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.bucketName }}
{{- end }}
{{- end }}

{{/*
Get S3 access key (same as namespaceId)
*/}}
{{- define "sam.s3.accessKey" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s" .Values.global.persistence.namespaceId }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.accessKey }}
{{- end }}
{{- end }}

{{/*
Get S3 secret key (same as namespaceId)
*/}}
{{- define "sam.s3.secretKey" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s" .Values.global.persistence.namespaceId }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.secretKey }}
{{- end }}
{{- end }}


{{- define "sam.s3.endpointUrl" -}}
{{- if .Values.global.persistence.enabled }}
{{- include "seaweedfs.s3url" (index .Subcharts "persistence-layer") }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.endpointUrl }}
{{- end }}
{{- end }}

{{/*
Database configuration helpers - generates consistent database settings based on namespaceId
*/}}

{{/*
Get WebUI database name (namespaceId_webui)
*/}}
{{- define "sam.database.webuiName" -}}
{{- printf "%s_webui" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get WebUI database user (namespaceId_webui)
*/}}
{{- define "sam.database.webuiUser" -}}
{{- printf "%s_webui" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get WebUI database password (same as user for simplicity)
*/}}
{{- define "sam.database.webuiPassword" -}}
{{- printf "%s_webui" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get Orchestrator database name (namespaceId_orchestrator)
*/}}
{{- define "sam.database.orchestratorName" -}}
{{- printf "%s_orchestrator" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get Orchestrator database user (namespaceId_orchestrator)
*/}}
{{- define "sam.database.orchestratorUser" -}}
{{- printf "%s_orchestrator" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get Orchestrator database password (same as user for simplicity)
*/}}
{{- define "sam.database.orchestratorPassword" -}}
{{- printf "%s_orchestrator" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get Platform database name (namespaceId_platform)
*/}}
{{- define "sam.database.platformName" -}}
{{- printf "%s_platform" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get Platform database user (namespaceId_platform)
*/}}
{{- define "sam.database.platformUser" -}}
{{- printf "%s_platform" .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get Platform database password (same as user for simplicity)
*/}}
{{- define "sam.database.platformPassword" -}}
{{- printf "%s_platform" .Values.global.persistence.namespaceId }}
{{- end }}
