{{/*
Chart-specific helpers for solace-agent-mesh.

NOTE: Generic helpers (naming, labels, images, security) are provided by the
sam-common library chart. Only chart-specific helpers belong here.

The old generic helpers (sam.name, sam.fullname, sam.labels, sam.annotations)
are kept temporarily for backward compatibility with secret templates that have
not been migrated yet. They will be removed in the secrets refactor PR.
*/}}

{{/* ---- Temporary: kept for unmigrated secret templates ---- */}}

{{- define "sam.name" -}}
{{- include "sam.names.name" . }}
{{- end }}

{{- define "sam.fullname" -}}
{{- include "sam.names.fullname" . }}
{{- end }}

{{- define "sam.chart" -}}
{{- include "sam.names.chart" . }}
{{- end }}

{{- define "sam.labels" -}}
helm.sh/chart: {{ include "sam.chart" . }}
{{ include "sam.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "sam.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sam.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sam.annotations" -}}
{{- if .Values.samDeployment.annotations }}
annotations:
  {{- .Values.samDeployment.annotations | toYaml | nindent 2 }}
{{- end }}
{{- end }}

{{/* ---- Broker mode ---- */}}

{{/*
Determine if the embedded broker should be deployed.
Returns "true" if embedded mode is enabled. Fails if both embedded and external broker credentials are provided.
*/}}
{{- define "sam.broker.embedded" -}}
{{- if .Values.global.broker.embedded -}}
{{- if .Values.broker.url -}}
{{- fail "Conflicting broker configuration: cannot set broker.url when global.broker.embedded is true. Either set global.broker.embedded to false, or remove the broker credentials." -}}
{{- end -}}
true
{{- end -}}
{{- end }}

{{/*
Init container that waits for the embedded broker to accept connections.
This init container is common across core and agent-deployer. Any changes should consider both base images.
Args: (dict "root" . "image" <imageSpec>)
*/}}
{{- define "sam.broker.initContainer" -}}
{{- $brokerHost := include "sam.names.component" (dict "root" .root "component" "broker") -}}
- name: broker-init
  image: {{ include "sam.images.image" (dict "root" .root "image" .image) | quote }}
  securityContext:
    {{- include "sam.security.containerContext" (dict "override" dict) | nindent 4 }}
  command:
    - bash
    - -c
    - |
      echo "Waiting for broker at {{ $brokerHost }}:55555..."
      RETRIES=0
      until (echo > /dev/tcp/{{ $brokerHost }}/55555) 2>/dev/null; do
        RETRIES=$((RETRIES + 1))
        if [ "$RETRIES" -ge 60 ]; then
          echo "ERROR: broker at {{ $brokerHost }}:55555 not ready after 300s. Giving up."
          exit 1
        fi
        echo "Broker not ready yet... (attempt $RETRIES/60)"
        sleep 5
      done
      echo "Broker is ready."
{{- end -}}

{{/* ---- Validation ---- */}}

{{- define "sam.validateApplicationPassword" -}}
{{- if and (not .Values.global.persistence.enabled) (not .Values.dataStores.database.applicationPassword) }}
{{- fail "dataStores.database.applicationPassword is required when using external persistence (global.persistence.enabled=false)" }}
{{- end }}
{{- end }}

{{/* ---- Object storage type ---- */}}

{{- define "sam.objectStorage.type" -}}
{{- if .Values.global.persistence.enabled -}}s3{{- else -}}{{ .Values.dataStores.objectStorage.type | default "s3" }}{{- end -}}
{{- end -}}

{{/* ---- S3 helpers ---- */}}

{{- define "sam.s3.bucketName" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s" .Values.global.persistence.namespaceId }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.bucketName }}
{{- end }}
{{- end }}

{{- define "sam.s3.accessKey" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s" .Values.global.persistence.namespaceId }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.accessKey }}
{{- end }}
{{- end }}

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

{{- define "sam.s3.connectorSpecBucketName" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s-connector-specs" .Values.global.persistence.namespaceId }}
{{- else -}}
{{- printf "%s" .Values.dataStores.s3.connectorSpecBucketName }}
{{- end }}
{{- end }}

{{- define "sam.s3.evalDataBucketName" -}}
{{- if .Values.global.persistence.enabled }}
{{- include "sam.s3.bucketName" . }}
{{- else if .Values.dataStores.s3.evalDataBucketName -}}
{{- printf "%s" .Values.dataStores.s3.evalDataBucketName }}
{{- else -}}
{{- include "sam.s3.bucketName" . }}
{{- end }}
{{- end }}

{{/* ---- Azure helpers ---- */}}

{{- define "sam.azure.containerName" -}}
{{- .Values.dataStores.azure.containerName }}
{{- end -}}

{{- define "sam.azure.connectorSpecContainerName" -}}
{{- .Values.dataStores.azure.connectorSpecContainerName }}
{{- end -}}

{{- define "sam.azure.evalDataContainerName" -}}
{{- if .Values.dataStores.azure.evalDataContainerName -}}
{{- .Values.dataStores.azure.evalDataContainerName }}
{{- else -}}
{{- include "sam.azure.containerName" . }}
{{- end }}
{{- end -}}

{{/* ---- GCS helpers ---- */}}

{{- define "sam.gcs.bucketName" -}}
{{- .Values.dataStores.gcs.bucketName }}
{{- end -}}

{{- define "sam.gcs.connectorSpecBucketName" -}}
{{- .Values.dataStores.gcs.connectorSpecBucketName }}
{{- end -}}

{{- define "sam.gcs.evalDataBucketName" -}}
{{- if .Values.dataStores.gcs.evalDataBucketName -}}
{{- .Values.dataStores.gcs.evalDataBucketName }}
{{- else -}}
{{- include "sam.gcs.bucketName" . }}
{{- end }}
{{- end -}}

{{/* ---- Database helpers ---- */}}

{{- define "sam.database.qualifyUsername" -}}
{{- if and .context.Values.dataStores.database.supabaseTenantId (not .context.Values.global.persistence.enabled) }}
{{- printf "%s.%s" .username .context.Values.dataStores.database.supabaseTenantId }}
{{- else }}
{{- .username }}
{{- end }}
{{- end }}

{{- define "sam.database.webuiName" -}}
{{- printf "%s_webui" .Values.global.persistence.namespaceId }}
{{- end }}

{{- define "sam.database.webuiUser" -}}
{{- printf "%s_webui" .Values.global.persistence.namespaceId }}
{{- end }}

{{- define "sam.database.webuiPassword" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s_webui" .Values.global.persistence.namespaceId }}
{{- else }}
{{- required "dataStores.database.applicationPassword is required for external persistence" .Values.dataStores.database.applicationPassword }}
{{- end }}
{{- end }}

{{- define "sam.database.orchestratorName" -}}
{{- printf "%s_orchestrator" .Values.global.persistence.namespaceId }}
{{- end }}

{{- define "sam.database.orchestratorUser" -}}
{{- printf "%s_orchestrator" .Values.global.persistence.namespaceId }}
{{- end }}

{{- define "sam.database.orchestratorPassword" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s_orchestrator" .Values.global.persistence.namespaceId }}
{{- else }}
{{- required "dataStores.database.applicationPassword is required for external persistence" .Values.dataStores.database.applicationPassword }}
{{- end }}
{{- end }}

{{- define "sam.database.platformName" -}}
{{- printf "%s_platform" .Values.global.persistence.namespaceId }}
{{- end }}

{{- define "sam.database.platformUser" -}}
{{- printf "%s_platform" .Values.global.persistence.namespaceId }}
{{- end }}

{{- define "sam.database.platformPassword" -}}
{{- if .Values.global.persistence.enabled }}
{{- printf "%s_platform" .Values.global.persistence.namespaceId }}
{{- else }}
{{- required "dataStores.database.applicationPassword is required for external persistence" .Values.dataStores.database.applicationPassword }}
{{- end }}
{{- end }}
