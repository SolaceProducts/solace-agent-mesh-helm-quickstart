{{/*
Shared secret/config data helpers.
Reusable by main secrets and sam-doctor pre-install hook secrets.
*/}}

{{/*
Secret metadata helper — consistent naming and labels.
Args: (dict "root" . "name" "core-secrets" "component" "core" "hook" false "hookWeight" "-5" "hookDeletePolicy" "before-hook-creation,hook-succeeded")
*/}}
{{- define "sam.secret.metadata" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "sam.names.fullname" .root }}-{{ .name }}
  labels:
    {{- include "sam.labels.standard" (dict "root" .root "config" (dict "component" (.component | default "core"))) | nindent 4 }}
  {{- if .hook }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": {{ .hookWeight | default "-5" | quote }}
    "helm.sh/hook-delete-policy": {{ .hookDeletePolicy | default "before-hook-creation,hook-succeeded" | quote }}
  {{- end }}
type: {{ .type | default "Opaque" }}
{{- end -}}

{{/*
Database data block — admin creds + per-service user/pass/name + DSNs.
Reusable by main secret and sam-doctor hook secret.
*/}}
{{- define "sam.secret.databaseData" }}
{{- /* DSN protocol: Python uses the SQLAlchemy+psycopg2 scheme; Go uses the pgx scheme. */ -}}
{{- $dbProtocol := ternary "postgres" "postgresql+psycopg2" (eq (.Values.sam.platform | default "python") "go") }}
{{- /* Admin credentials — only for external DB mode. Embedded mode uses the subchart's own secret. */ -}}
{{- if not .Values.global.persistence.enabled }}
PGHOST: {{ .Values.dataStores.database.host | b64enc }}
PGPORT: {{ .Values.dataStores.database.port | toString | b64enc }}
PGUSER: {{ include "sam.database.qualifyUsername" (dict "username" .Values.dataStores.database.adminUsername "context" .) | b64enc }}
PGPASSWORD: {{ .Values.dataStores.database.adminPassword | b64enc }}
PGDATABASE: {{ "postgres" | b64enc }}
SUPABASE_TENANT_ID: {{ .Values.dataStores.database.supabaseTenantId | default "" | b64enc }}
APPLICATION_PASSWORD: {{ .Values.dataStores.database.applicationPassword | b64enc }}
{{- end }}
WEB_UI_GATEWAY_DATABASE_USER: {{ include "sam.database.webuiUser" . | b64enc }}
WEB_UI_GATEWAY_DATABASE_PASSWORD: {{ include "sam.database.webuiPassword" . | b64enc }}
WEB_UI_GATEWAY_DATABASE_NAME: {{ include "sam.database.webuiName" . | b64enc }}
PLATFORM_DATABASE_USER: {{ include "sam.database.platformUser" . | b64enc }}
PLATFORM_DATABASE_PASSWORD: {{ include "sam.database.platformPassword" . | b64enc }}
PLATFORM_DATABASE_NAME: {{ include "sam.database.platformName" . | b64enc }}
ORCHESTRATOR_DATABASE_USER: {{ include "sam.database.orchestratorUser" . | b64enc }}
ORCHESTRATOR_DATABASE_PASSWORD: {{ include "sam.database.orchestratorPassword" . | b64enc }}
ORCHESTRATOR_DATABASE_NAME: {{ include "sam.database.orchestratorName" . | b64enc }}
{{- if .Values.global.persistence.enabled }}
WEB_UI_GATEWAY_DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.webuiUser" .) (include "sam.database.webuiPassword" .) (include "postgresql.host" (index .Subcharts "persistence-layer")) (include "postgresql.port" (index .Subcharts "persistence-layer")) (include "sam.database.webuiName" .) | b64enc }}
PLATFORM_DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.platformUser" .) (include "sam.database.platformPassword" .) (include "postgresql.host" (index .Subcharts "persistence-layer")) (include "postgresql.port" (index .Subcharts "persistence-layer")) (include "sam.database.platformName" .) | b64enc }}
ORCHESTRATOR_DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.orchestratorUser" .) (include "sam.database.orchestratorPassword" .) (include "postgresql.host" (index .Subcharts "persistence-layer")) (include "postgresql.port" (index .Subcharts "persistence-layer")) (include "sam.database.orchestratorName" .) | b64enc }}
{{- if eq (.Values.sam.platform | default "python") "go" }}
{{- /* Go AWE: every agent (the Orchestrator included) shares ONE durable
       sessions store. awe_base.yaml reads plain DATABASE_URL; point it at the
       shared sessions database (its own dedicated schema, distinct from the
       platform DB) so chat history survives AWE restarts and config edits. */}}
DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.orchestratorUser" .) (include "sam.database.orchestratorPassword" .) (include "postgresql.host" (index .Subcharts "persistence-layer")) (include "postgresql.port" (index .Subcharts "persistence-layer")) (include "sam.database.orchestratorName" .) | b64enc }}
{{- end }}
{{- else }}
WEB_UI_GATEWAY_DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.qualifyUsername" (dict "username" (include "sam.database.webuiUser" .) "context" .)) (include "sam.database.webuiPassword" .) .Values.dataStores.database.host (.Values.dataStores.database.port | toString) (include "sam.database.webuiName" .) | b64enc }}
PLATFORM_DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.qualifyUsername" (dict "username" (include "sam.database.platformUser" .) "context" .)) (include "sam.database.platformPassword" .) .Values.dataStores.database.host (.Values.dataStores.database.port | toString) (include "sam.database.platformName" .) | b64enc }}
ORCHESTRATOR_DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.qualifyUsername" (dict "username" (include "sam.database.orchestratorUser" .) "context" .)) (include "sam.database.orchestratorPassword" .) .Values.dataStores.database.host (.Values.dataStores.database.port | toString) (include "sam.database.orchestratorName" .) | b64enc }}
{{- if eq (.Values.sam.platform | default "python") "go" }}
{{- /* Go AWE: shared sessions DB exposed as plain DATABASE_URL (see above). */}}
DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" $dbProtocol (include "sam.database.qualifyUsername" (dict "username" (include "sam.database.orchestratorUser" .) "context" .)) (include "sam.database.orchestratorPassword" .) .Values.dataStores.database.host (.Values.dataStores.database.port | toString) (include "sam.database.orchestratorName" .) | b64enc }}
{{- end }}
{{- end }}
ORCHESTRATOR_SESSION_SERVICE_TYPE: {{ print "sql" | b64enc }}
WEB_UI_SESSION_SERVICE_TYPE: {{ print "sql" | b64enc }}
{{- end -}}

{{/*
Storage data block — S3/Azure/GCS credentials for running app.
Reusable by main secret and sam-doctor hook secret.
*/}}
{{- define "sam.secret.storageData" -}}
OBJECT_STORAGE_TYPE: {{ include "sam.objectStorage.type" . | b64enc }}
{{- if eq (include "sam.objectStorage.type" .) "azure" }}
AZURE_STORAGE_ACCOUNT_NAME: {{ .Values.dataStores.azure.accountName | b64enc }}
{{- if not .Values.dataStores.objectStorage.workloadIdentity.enabled }}
AZURE_STORAGE_ACCOUNT_KEY: {{ .Values.dataStores.azure.accountKey | b64enc }}
AZURE_STORAGE_CONNECTION_STRING: {{ .Values.dataStores.azure.connectionString | b64enc }}
{{- end }}
{{- if ne (.Values.sam.platform | default "python") "go" }}
AZURE_STORAGE_CONTAINER_NAME: {{ include "sam.azure.containerName" . | b64enc }}
{{- end }}
CONNECTOR_SPEC_BUCKET_NAME: {{ include "sam.azure.connectorSpecContainerName" . | b64enc }}
EVAL_DATA_BUCKET_NAME: {{ include "sam.azure.evalDataContainerName" . | b64enc }}
{{- if eq (.Values.sam.platform | default "python") "go" }}
OBJECT_STORAGE_BUCKET_NAME: {{ include "sam.azure.containerName" . | b64enc }}
ARTIFACT_BUCKET_NAME: {{ include "sam.azure.containerName" . | b64enc }}
STR_BUCKET_NAME: {{ include "sam.azure.containerName" . | b64enc }}
{{- end }}
{{- else if eq (include "sam.objectStorage.type" .) "gcs" }}
GCS_PROJECT: {{ .Values.dataStores.gcs.project | b64enc }}
{{- if not .Values.dataStores.objectStorage.workloadIdentity.enabled }}
GCS_CREDENTIALS_JSON: {{ .Values.dataStores.gcs.credentialsJson | b64enc }}
{{- end }}
{{- if ne (.Values.sam.platform | default "python") "go" }}
GCS_BUCKET_NAME: {{ include "sam.gcs.bucketName" . | b64enc }}
{{- end }}
CONNECTOR_SPEC_BUCKET_NAME: {{ include "sam.gcs.connectorSpecBucketName" . | b64enc }}
EVAL_DATA_BUCKET_NAME: {{ include "sam.gcs.evalDataBucketName" . | b64enc }}
{{- if eq (.Values.sam.platform | default "python") "go" }}
OBJECT_STORAGE_BUCKET_NAME: {{ include "sam.gcs.bucketName" . | b64enc }}
ARTIFACT_BUCKET_NAME: {{ include "sam.gcs.bucketName" . | b64enc }}
STR_BUCKET_NAME: {{ include "sam.gcs.bucketName" . | b64enc }}
{{- end }}
{{- else }}
S3_ENDPOINT_URL: {{ include "sam.s3.endpointUrl" . | b64enc }}
{{- /* Keep S3_BUCKET_NAME in Python mode and in bundled-SeaweedFS mode (the */ -}}
{{- /* gwe/awe/str s3-init initContainers run `weed shell s3.bucket.create     */ -}}
{{- /* -name=$S3_BUCKET_NAME` and only render when global.persistence.enabled). */ -}}
{{- if or (ne (.Values.sam.platform | default "python") "go") .Values.global.persistence.enabled }}
S3_BUCKET_NAME: {{ include "sam.s3.bucketName" . | b64enc }}
{{- end }}
CONNECTOR_SPEC_BUCKET_NAME: {{ include "sam.s3.connectorSpecBucketName" . | b64enc }}
EVAL_DATA_BUCKET_NAME: {{ include "sam.s3.evalDataBucketName" . | b64enc }}
{{- if not .Values.dataStores.objectStorage.workloadIdentity.enabled }}
AWS_ACCESS_KEY_ID: {{ include "sam.s3.accessKey" . | b64enc }}
AWS_SECRET_ACCESS_KEY: {{ include "sam.s3.secretKey" . | b64enc }}
S3_ACCESS_KEY: {{ include "sam.s3.accessKey" . | b64enc }}
S3_SECRET_KEY: {{ include "sam.s3.secretKey" . | b64enc }}
{{- end }}
AWS_REGION: {{ .Values.dataStores.s3.region | default "us-east-1" | b64enc }}
{{- if eq (.Values.sam.platform | default "python") "go" }}
OBJECT_STORAGE_BUCKET_NAME: {{ include "sam.s3.bucketName" . | b64enc }}
ARTIFACT_BUCKET_NAME: {{ include "sam.s3.bucketName" . | b64enc }}
STR_BUCKET_NAME: {{ include "sam.s3.bucketName" . | b64enc }}
{{- end }}
{{- end }}
{{- end -}}
