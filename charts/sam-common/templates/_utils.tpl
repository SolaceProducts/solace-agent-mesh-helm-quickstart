{{/*
Utility helpers: checksums, env, annotations.

sam.utils.checksumAnnotation  - Checksum annotation for a file path.
sam.utils.envFromSecretRef    - Env var from a Secret key ref.
sam.utils.annotations         - Render annotations block.
sam.utils.podAnnotations      - Render pod annotations with optional checksums.
sam.utils.env                 - Render env block for a container.
sam.utils.envAsMap            - Normalize env-vars (map or KEY=VALUE string) to a map.
*/}}

{{/*
Checksum annotation for rolling restart on config change.
Expects: (dict "root" . "path" "path/to/file")
Returns: a single annotation line.
*/}}
{{- define "sam.utils.checksumAnnotation" -}}
checksum/{{ base .path }}: {{ .root.Files.Get .path | sha256sum }}
{{- end }}

{{/*
Render an env var sourced from a Secret key.
Expects: (dict "envName" "VAR" "secretName" "my-secret" "secretKey" "key")
*/}}
{{- define "sam.utils.envFromSecretRef" -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: {{ .secretKey }}
{{- end }}

{{/*
Render annotations block (with "annotations:" key).
Expects: (dict "annotations" $annotationsDict)
Returns empty string if no annotations.
*/}}
{{- define "sam.utils.annotations" -}}
{{- with .annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Render pod annotations (no wrapping key — meant for template.metadata.annotations).
Supports extra annotations dict + checksum entries.
Expects: config dict with optional keys: .podAnnotations, .checksums (arbitrary key/value pairs)
*/}}
{{- define "sam.utils.podAnnotations" -}}
{{- with .podAnnotations }}
{{- toYaml . }}
{{- end }}
{{- range $key, $value := .checksums }}
checksum/{{ $key }}: {{ $value }}
{{- end -}}
{{- end }}


{{/*
Normalize an env-vars value (map or KEY=VALUE multiline string) to a map.
Caller pattern:
  {{- $envVars := include "sam.utils.envAsMap" .Values.environmentVariables | fromYaml -}}

Accepts:
  - map: returned as-is (values stringified)
  - string: parsed line-by-line as KEY=VALUE; blanks and lines starting with '#' skipped
  - anything else (nil, list, ...): treated as empty

Output is YAML suitable for piping to fromYaml. Empty input yields empty output,
which fromYaml parses as an empty map.
*/}}
{{- define "sam.utils.envAsMap" -}}
{{- $envVars := . -}}
{{- if kindIs "map" $envVars -}}
{{- range $key, $value := $envVars }}
{{ $key }}: {{ $value | toString | quote }}
{{- end }}
{{- else if kindIs "string" $envVars -}}
{{- range $line := splitList "\n" $envVars -}}
{{- $line := trim $line -}}
{{- if and $line (not (hasPrefix "#" $line)) -}}
{{- $parts := splitn "=" 2 $line -}}
{{- if eq (len $parts) 2 }}
{{ trim (index $parts "_0") }}: {{ trim (index $parts "_1") | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Render env block for a container.
Expects: (dict "config" $cfg "root" $root)
  $cfg should have .container.env (list) and optionally .extraSecretEnvironmentVars (list).
*/}}
{{- define "sam.utils.env" -}}
{{- $caEnabled := dig "customCA" "enabled" false .config -}}
{{- if or $caEnabled .config.container.env .config.extraSecretEnvironmentVars -}}
env:
{{- if $caEnabled }}
{{ include "sam.cacert.env" nil | indent 2 }}
{{- end }}
{{- if .config.container.env }}
{{ toYaml .config.container.env | indent 2 }}
{{- end }}
{{- range .config.extraSecretEnvironmentVars }}
{{ include "sam.utils.envFromSecretRef" . | indent 2 }}
{{- end }}
{{- end -}}
{{- end -}}

