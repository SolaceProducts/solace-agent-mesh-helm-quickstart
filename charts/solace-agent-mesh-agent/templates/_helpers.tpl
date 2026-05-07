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
{{- include "sam.names.fullname" . }}
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
{{- if .Values.componentType }}
app.kubernetes.io/component: {{ .Values.componentType }}
{{- end }}
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
Get PostgreSQL secret name based on persistence.createSecrets
*/}}
{{- define "sam.postgresql.secretName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- include "sam.fullname" . }}-persistence
{{- else }}
  {{- if not .Values.persistence.existingSecrets.database }}
    {{- fail "persistence.createSecrets is false but persistence.existingSecrets.database is not set" }}
  {{- end }}
  {{- .Values.persistence.existingSecrets.database }}
{{- end }}
{{- end }}

{{/*
Generate DATABASE_URL based on persistence.createSecrets
*/}}
{{- define "sam.postgresql.databaseUrl" -}}
{{- if .Values.persistence.createSecrets }}
  {{- /* Build URL from provided values */ -}}
  {{- if .Values.persistence.database.url }}
    {{- .Values.persistence.database.url }}
  {{- else }}
    {{- printf "postgresql+psycopg2://%s:%s@%s:%s/%s" .Values.persistence.database.username .Values.persistence.database.password .Values.persistence.database.host .Values.persistence.database.port .Values.persistence.database.database }}
  {{- end }}
{{- else }}
  {{- /* Use existing secret - must contain DATABASE_URL */ -}}
  {{- $pgSecret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.database) }}
  {{- if not $pgSecret }}{{- fail (printf "PostgreSQL secret '%s' not found" .Values.persistence.existingSecrets.database) }}{{- end }}
  {{- index $pgSecret.data "DATABASE_URL" | b64dec }}
{{- end }}
{{- end }}

{{/*
SeaweedFS secret discovery and access helpers
*/}}

{{/*
Get S3 secret name based on persistence.createSecrets
*/}}
{{- define "sam.s3.secretName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- include "sam.fullname" . }}-persistence
{{- else }}
  {{- if not .Values.persistence.existingSecrets.s3 }}
    {{- fail "persistence.createSecrets is false but persistence.existingSecrets.s3 is not set" }}
  {{- end }}
  {{- .Values.persistence.existingSecrets.s3 }}
{{- end }}
{{- end }}

{{/*
Get S3 URL based on persistence.createSecrets
*/}}
{{- define "sam.s3.url" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.s3.endpointUrl }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.s3) }}
  {{- if not $secret }}{{- fail (printf "S3 secret '%s' not found" .Values.persistence.existingSecrets.s3) }}{{- end }}
  {{- index $secret.data "S3_ENDPOINT_URL" | b64dec }}
{{- end }}
{{- end }}

{{/*
S3 configuration helpers - generates consistent S3 settings based on namespaceId
*/}}

{{/*
Get S3 bucket name based on persistence.createSecrets
*/}}
{{- define "sam.s3.bucketName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.s3.bucketName }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.s3) }}
  {{- if not $secret }}{{- fail (printf "S3 secret '%s' not found" .Values.persistence.existingSecrets.s3) }}{{- end }}
  {{- index $secret.data "S3_BUCKET_NAME" | b64dec }}
{{- end }}
{{- end }}

{{/*
Get S3 access key based on persistence.createSecrets
*/}}
{{- define "sam.s3.accessKey" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.s3.accessKey }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.s3) }}
  {{- if not $secret }}{{- fail (printf "S3 secret '%s' not found" .Values.persistence.existingSecrets.s3) }}{{- end }}
  {{- index $secret.data "AWS_ACCESS_KEY_ID" | b64dec }}
{{- end }}
{{- end }}

{{/*
Get S3 secret key based on persistence.createSecrets
*/}}
{{- define "sam.s3.secretKey" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.s3.secretKey }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.s3) }}
  {{- if not $secret }}{{- fail (printf "S3 secret '%s' not found" .Values.persistence.existingSecrets.s3) }}{{- end }}
  {{- index $secret.data "AWS_SECRET_ACCESS_KEY" | b64dec }}
{{- end }}
{{- end }}

{{/*
Detect object storage type from configuration
Based on persistence.createSecrets:
- true: infer from which direct config is set
- false: infer from which existingSecrets is set
*/}}
{{- define "sam.objectStorage.type" -}}
{{- if .Values.persistence.createSecrets }}
  {{- if .Values.persistence.azure.accountName }}azure
  {{- else if .Values.persistence.gcs.bucketName }}gcs
  {{- else if .Values.persistence.s3.endpointUrl }}s3
  {{- else }}s3
  {{- end }}
{{- else }}
  {{- if .Values.persistence.existingSecrets.azure }}azure
  {{- else if .Values.persistence.existingSecrets.gcs }}gcs
  {{- else if .Values.persistence.existingSecrets.s3 }}s3
  {{- else }}s3
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get Azure storage secret name
*/}}
{{- define "sam.azure.secretName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- include "sam.fullname" . }}-persistence
{{- else }}
  {{- if not .Values.persistence.existingSecrets.azure }}
    {{- fail "persistence.createSecrets is false but persistence.existingSecrets.azure is not set" }}
  {{- end }}
  {{- .Values.persistence.existingSecrets.azure }}
{{- end }}
{{- end -}}

{{/*
Get Azure container name from secret or config
*/}}
{{- define "sam.azure.containerName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.azure.containerName }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.azure) }}
  {{- index $secret.data "AZURE_STORAGE_CONTAINER_NAME" | b64dec }}
{{- end }}
{{- end -}}

{{/*
Get Azure account name from secret or config
*/}}
{{- define "sam.azure.accountName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.azure.accountName }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.azure) }}
  {{- index $secret.data "AZURE_STORAGE_ACCOUNT_NAME" | b64dec }}
{{- end }}
{{- end -}}

{{/*
Get Azure account key from secret or config
*/}}
{{- define "sam.azure.accountKey" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.azure.accountKey }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.azure) }}
  {{- $key := index $secret.data "AZURE_STORAGE_ACCOUNT_KEY" }}
  {{- if $key }}{{- $key | b64dec }}{{- end }}
{{- end }}
{{- end -}}

{{/*
Get Azure connection string from secret or config
*/}}
{{- define "sam.azure.connectionString" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.azure.connectionString }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.azure) }}
  {{- $cs := index $secret.data "AZURE_STORAGE_CONNECTION_STRING" }}
  {{- if $cs }}{{- $cs | b64dec }}{{- end }}
{{- end }}
{{- end -}}

{{/*
Get GCS secret name
*/}}
{{- define "sam.gcs.secretName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- include "sam.fullname" . }}-persistence
{{- else }}
  {{- if not .Values.persistence.existingSecrets.gcs }}
    {{- fail "persistence.createSecrets is false but persistence.existingSecrets.gcs is not set" }}
  {{- end }}
  {{- .Values.persistence.existingSecrets.gcs }}
{{- end }}
{{- end -}}

{{/*
Get GCS bucket name from secret or config
*/}}
{{- define "sam.gcs.bucketName" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.gcs.bucketName }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.gcs) }}
  {{- $bucket := index $secret.data "GCS_BUCKET_NAME" | default (index $secret.data "GCS_BUCKET") }}
  {{- $bucket | b64dec }}
{{- end }}
{{- end -}}

{{/*
Get GCS credentials JSON from secret or config
*/}}
{{- define "sam.gcs.credentialsJson" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.gcs.credentialsJson | default "" }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.gcs) }}
  {{- $creds := index $secret.data "GCS_CREDENTIALS_JSON" }}
  {{- if $creds }}{{- $creds | b64dec }}{{- end }}
{{- end }}
{{- end -}}

{{/*
Get GCS project from secret or config
*/}}
{{- define "sam.gcs.project" -}}
{{- if .Values.persistence.createSecrets }}
  {{- .Values.persistence.gcs.project | default "" }}
{{- else }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.persistence.existingSecrets.gcs) }}
  {{- $proj := index $secret.data "GCS_PROJECT" }}
  {{- if $proj }}{{- $proj | b64dec }}{{- end }}
{{- end }}
{{- end -}}

{{/*
Database configuration helpers - generates agent database settings based on namespaceId
*/}}

{{/*
Qualify username with Supabase tenant ID if configured (for Supabase connection pooler)
Reads SUPABASE_TENANT_ID from the discovered PostgreSQL secret
*/}}
{{- define "sam.database.qualifyUsername" -}}
{{- $secretName := include "sam.postgresql.secretName" .context }}
{{- $pgSecret := (lookup "v1" "Secret" .context.Release.Namespace $secretName) }}
{{- $supabaseTenantId := "" }}
{{- if $pgSecret }}
{{- $supabaseTenantId = index $pgSecret.data "SUPABASE_TENANT_ID" | default "" | b64dec }}
{{- end }}
{{- if $supabaseTenantId }}
{{- printf "%s.%s" .username $supabaseTenantId }}
{{- else }}
{{- .username }}
{{- end }}
{{- end }}

{{/*
Get component ID with backward compatibility
Uses 'id' if set, falls back to 'agentId' for backward compatibility
*/}}
{{- define "sam.componentId" -}}
{{- if .Values.id }}
{{- .Values.id }}
{{- else if .Values.agentId }}
{{- .Values.agentId }}
{{- end }}
{{- end }}

{{/*
Get component configuration YAML with backward compatibility
Uses 'config.yaml' if set, falls back to 'config.agentYaml' for backward compatibility
*/}}
{{- define "sam.configYaml" -}}
{{- if .Values.config.yaml }}
{{- .Values.config.yaml }}
{{- else if .Values.config.agentYaml }}
{{- .Values.config.agentYaml }}
{{- end }}
{{- end }}

{{/*
Get component database name (namespaceId_id_component)
*/}}
{{- define "sam.database.agentName" -}}
{{- printf "%s_%s_%s" .Values.global.persistence.namespaceId (include "sam.componentId" .) .Values.component }}
{{- end }}

{{/*
Get component database user (namespaceId_id_component)
*/}}
{{- define "sam.database.agentUser" -}}
{{- printf "%s_%s_%s" .Values.global.persistence.namespaceId (include "sam.componentId" .) .Values.component }}
{{- end }}

{{/*
Get component database password
- External mode: uses applicationPassword discovered from parent chart's secret
- Embedded mode: uses legacy pattern (namespaceId_id_component)
*/}}
{{- define "sam.database.agentPassword" -}}
{{- $secretName := include "sam.postgresql.secretName" . }}
{{- $pgSecret := (lookup "v1" "Secret" .Release.Namespace $secretName) }}
{{- if $pgSecret }}
{{- $applicationPassword := index $pgSecret.data "APPLICATION_PASSWORD" | default "" | b64dec }}
{{- if $applicationPassword }}
{{- $applicationPassword }}
{{- else }}
{{- printf "%s_%s_%s" .Values.global.persistence.namespaceId (include "sam.componentId" .) .Values.component }}
{{- end }}
{{- else }}
{{- printf "%s_%s_%s" .Values.global.persistence.namespaceId (include "sam.componentId" .) .Values.component }}
{{- end }}
{{- end }}
