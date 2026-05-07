{{/*
Render a ServiceAccount.
Expects: (dict "root" . "config" $config)

config keys:
  component            string  Required  — used for auto-generated SA name
  serviceAccount:
    name               string  Optional  — explicit SA name (skips auto-generation)
    annotations        object  Optional  — SA annotations (e.g., IRSA, Workload Identity)
  imagePullSecrets     []string Optional — merged with global.imagePullSecrets
  hook                 bool    Optional  — render Helm hook annotations (default false)
  hookWeight           string  Optional  — hook weight (default "-5")
  hookDeletePolicy     string  Optional  — hook delete policy (default "before-hook-creation,hook-succeeded")
*/}}
{{- define "sam.serviceAccount" -}}
{{- $root := .root -}}
{{- $cfg := .config -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "sam.names.serviceAccount" (dict "root" $root "config" $cfg) }}
  labels:
    {{- include "sam.labels.standard" (dict "root" $root "config" $cfg) | nindent 4 }}
  {{- if or $cfg.hook (and $cfg.serviceAccount $cfg.serviceAccount.annotations) }}
  annotations:
    {{- if $cfg.hook }}
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": {{ $cfg.hookWeight | default "-5" | quote }}
    "helm.sh/hook-delete-policy": {{ $cfg.hookDeletePolicy | default "before-hook-creation,hook-succeeded" | quote }}
    {{- end }}
    {{- if and $cfg.serviceAccount $cfg.serviceAccount.annotations }}
    {{- toYaml $cfg.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- include "sam.images.pullSecrets" (dict "root" $root "pullSecrets" $cfg.imagePullSecrets) }}
{{- end }}
