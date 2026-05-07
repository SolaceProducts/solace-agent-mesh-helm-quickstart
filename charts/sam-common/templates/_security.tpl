{{/*
Security context defaults.

sam.security.podContext       - Pod-level securityContext with sane defaults.
sam.security.containerContext - Container-level securityContext with sane defaults.

Both accept an optional override dict. If provided, it is merged over defaults.
Expects: (dict "override" $dictOrNil) or empty dict.
*/}}

{{/*
Pod-level security context.
Defaults: fsGroup 999, runAsUser 999, runAsGroup 999, runAsNonRoot, seccomp RuntimeDefault.
Expects: (dict "override" $podSecurityContext) — override is optional.
*/}}
{{- define "sam.security.podContext" -}}
{{- $defaults := dict
  "fsGroup" 999
  "runAsUser" 999
  "runAsGroup" 999
  "runAsNonRoot" true
  "seccompProfile" (dict "type" "RuntimeDefault")
-}}
{{- $ctx := deepCopy (.override | default dict) -}}
{{- toYaml (merge $ctx $defaults) }}
{{- end }}

{{/*
Container-level security context.
Defaults: allowPrivilegeEscalation false, readOnlyRootFilesystem true, drop ALL caps.
Expects: (dict "override" $containerSecurityContext) — override is optional.
*/}}
{{- define "sam.security.containerContext" -}}
{{- $defaults := dict
  "allowPrivilegeEscalation" false
  "readOnlyRootFilesystem" true
  "capabilities" (dict "drop" (list "ALL"))
-}}
{{- $ctx := deepCopy (.override | default dict) -}}
{{- toYaml (merge $ctx $defaults) }}
{{- end }}
