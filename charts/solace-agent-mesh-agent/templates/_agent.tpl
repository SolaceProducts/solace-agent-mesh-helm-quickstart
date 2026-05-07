{{/*
Agent container command.
*/}}
{{- define "sam.agent.command" -}}
- solace-agent-mesh
- run
- --system-env
- /app/config/agent.yaml
{{- end -}}

{{/*
Agent container env vars.
*/}}
{{- define "sam.agent.env" -}}
- name: LOGGING_CONFIG_PATH
  value: /app/config/logging/logging_config.yaml
{{- end -}}

{{/*
Agent container envFrom — secret refs for environment and persistence.
*/}}
{{- define "sam.agent.envFrom" -}}
{{- include "sam.agent.envFrom.persistence" . }}
{{- if .Values.global.persistence.namespaceId }}
- secretRef:
    name: {{ .Values.global.persistence.namespaceId }}-env-overrides
    optional: true
{{- end }}
- secretRef:
    name: {{ include "sam.names.component" (dict "root" . "component" "env-vars") }}
{{- end -}}

{{/*
Persistence secret refs for envFrom based on persistence.createSecrets
*/}}
{{- define "sam.agent.envFrom.persistence" -}}
{{- if .Values.persistence.createSecrets }}
- secretRef:
    name: {{ include "sam.names.component" (dict "root" . "component" "persistence") }}
{{- else }}
- secretRef:
    name: {{ include "sam.postgresql.secretName" . }}
- secretRef:
    name: {{ include "sam.names.component" (dict "root" . "component" "init-credentials") }}
{{- $storageType := include "sam.objectStorage.type" . }}
{{- if eq $storageType "azure" }}
- secretRef:
    name: {{ include "sam.azure.secretName" . }}
{{- else if eq $storageType "gcs" }}
- secretRef:
    name: {{ include "sam.gcs.secretName" . }}
{{- else }}
- secretRef:
    name: {{ include "sam.s3.secretName" . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Agent pod labels — includes azure workload identity when needed.
*/}}
{{- define "sam.agent.podLabels" -}}
{{- with .Values.podLabels }}
{{- toYaml . }}
{{- end }}
{{- if and (eq .Values.component "gateway") .Values.componentType }}
componentType: {{ .Values.componentType | quote }}
{{- end }}
{{- if and (eq (include "sam.objectStorage.type" .) "azure") .Values.persistence.objectStorage.workloadIdentity.enabled }}
azure.workload.identity/use: "true"
{{- end }}
{{- end -}}
