{{/*
Build the deployment config dict for the core component.
Maps feature-driven values.yaml to the library's config dict shape.
*/}}
{{- define "sam.core.command" -}}
- solace-agent-mesh
- run
- --system-env
- /app/config/a2a_orchestrator.yaml
- /app/config/webui_backend.yaml
- /app/config/platform.yaml
{{- if not .Values.sam.communityMode }}
- /app/config/enterprise_config.yaml
- /app/config/auth/oauth2_server.yaml
{{- end }}
{{- end -}}

{{/*
Core container env vars.
Merges static env with extraSecretEnvironmentVars.
*/}}
{{- define "sam.core.env" -}}
- name: LOGGING_CONFIG_PATH
  value: /app/config/logging/logging_config.yaml
{{- range .Values.extraSecretEnvironmentVars }}
{{- include "sam.utils.envFromSecretRef" . }}
{{- end }}
{{- end -}}

{{/*
Core container envFrom — secrets and configmaps for the core component.
*/}}
{{- define "sam.core.envFrom" -}}
- secretRef:
    name: {{ include "sam.names.fullname" . }}-core-secrets
{{- if not .Values.sam.communityMode }}
- secretRef:
    name: {{ include "sam.names.fullname" . }}-auth-secrets
{{- end }}
- secretRef:
    name: {{ include "sam.names.fullname" . }}-database
- secretRef:
    name: {{ include "sam.names.fullname" . }}-storage
- configMapRef:
    name: {{ include "sam.names.fullname" . }}-core-env
{{- end -}}

{{/*
Core pod labels — includes azure workload identity when needed.
*/}}
{{- define "sam.core.podLabels" -}}
{{- with .Values.samDeployment.podLabels }}
{{- toYaml . }}
{{- end }}
{{- if and (eq (include "sam.objectStorage.type" .) "azure") .Values.dataStores.objectStorage.workloadIdentity.enabled }}
azure.workload.identity/use: "true"
{{- end }}
{{- end -}}
