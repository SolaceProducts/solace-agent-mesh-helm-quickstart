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

{{/*
PostgreSQL secret discovery and access helpers
*/}}

{{/*
Get PostgreSQL secret name using service discovery
*/}}
{{- define "sam.postgresql.secretName" -}}
{{- $namespaceId := .Values.global.persistence.namespaceId }}
{{- $allSecrets := (lookup "v1" "Secret" .Release.Namespace "") }}
{{- if not $allSecrets.items }}{{- fail "Unable to lookup secrets. Make sure you have proper cluster access." }}{{- end }}
{{- $found := "" }}
{{- range $allSecrets.items }}
{{- if and .metadata.labels (eq (index .metadata.labels "app.kubernetes.io/namespace-id" | default "") $namespaceId) (eq (index .metadata.labels "app.kubernetes.io/service" | default "") "postgresql") }}
{{- $found = .metadata.name }}{{- break }}{{- end }}{{- end }}
{{- if not $found }}{{- fail (printf "PostgreSQL secret not found for namespaceId '%s'. Make sure the chart with persistence is deployed first." $namespaceId) }}{{- end }}
{{- $found }}
{{- end }}

{{/*
Generate DATABASE_URL from helpers and discovered PostgreSQL secret
*/}}
{{- define "sam.postgresql.databaseUrl" -}}
{{- $secretName := include "sam.postgresql.secretName" . }}
{{- $pgSecret := (lookup "v1" "Secret" .Release.Namespace $secretName) }}
{{- if not $pgSecret }}{{- fail (printf "PostgreSQL secret '%s' not found" $secretName) }}{{- end }}
{{- $pgHost := index $pgSecret.data "PGHOST" | b64dec }}
{{- $pgPort := index $pgSecret.data "PGPORT" | b64dec }}
{{- printf "postgresql+psycopg2://%s:%s@%s:%s/%s" (include "sam.database.agentUser" .) (include "sam.database.agentPassword" .) $pgHost $pgPort (include "sam.database.agentName" .) }}
{{- end }}

{{/*
SeaweedFS secret discovery and access helpers
*/}}

{{/*
Get SeaweedFS secret name using service discovery
*/}}
{{- define "sam.seaweedfs.secretName" -}}
{{- $namespaceId := .Values.global.persistence.namespaceId }}
{{- $allSecrets := (lookup "v1" "Secret" .Release.Namespace "") }}
{{- if not $allSecrets.items }}{{- fail "Unable to lookup secrets. Make sure you have proper cluster access." }}{{- end }}
{{- $found := "" }}
{{- range $allSecrets.items }}
{{- if and .metadata.labels (eq (index .metadata.labels "app.kubernetes.io/namespace-id" | default "") $namespaceId) (eq (index .metadata.labels "app.kubernetes.io/service" | default "") "seaweedfs") }}
{{- $found = .metadata.name }}{{- break }}{{- end }}{{- end }}
{{- if not $found }}{{- fail (printf "SeaweedFS secret not found for namespaceId '%s'. Make sure the chart with persistence is deployed first." $namespaceId) }}{{- end }}
{{- $found }}
{{- end }}

{{/*
Get SeaweedFS S3 URL from discovered secret
*/}}
{{- define "sam.seaweedfs.url" -}}
{{- $secretName := include "sam.seaweedfs.secretName" . }}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) }}
{{- if not $secret }}{{- fail (printf "SeaweedFS secret '%s' not found" $secretName) }}{{- end }}
{{- $url := index $secret.data "S3_ENDPOINT_URL" | b64dec }}
{{- if not $url }}{{- fail "S3_ENDPOINT_URL not found in SeaweedFS secret" }}{{- end }}
{{- $url }}
{{- end }}

{{/*
S3 configuration helpers - generates consistent S3 settings based on namespaceId
*/}}

{{/*
Get S3 bucket name (same as namespaceId)
*/}}
{{- define "sam.s3.bucketName" -}}
{{- .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get S3 access key (same as namespaceId)
*/}}
{{- define "sam.s3.accessKey" -}}
{{- .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Get S3 secret key (same as namespaceId)
*/}}
{{- define "sam.s3.secretKey" -}}
{{- .Values.global.persistence.namespaceId }}
{{- end }}

{{/*
Database configuration helpers - generates agent database settings based on namespaceId
*/}}

{{/*
Get agent database name (namespaceId_agentId_agent)
*/}}
{{- define "sam.database.agentName" -}}
{{- printf "%s_%s_agent" .Values.global.persistence.namespaceId .Values.agentId }}
{{- end }}

{{/*
Get agent database user (namespaceId_agentId_agent)
*/}}
{{- define "sam.database.agentUser" -}}
{{- printf "%s_%s_agent" .Values.global.persistence.namespaceId .Values.agentId }}
{{- end }}

{{/*
Get agent database password (same as user for simplicity)
*/}}
{{- define "sam.database.agentPassword" -}}
{{- printf "%s_%s_agent" .Values.global.persistence.namespaceId .Values.agentId }}
{{- end }}
