{{/*
Render a ConfigMap.
Expects: (dict "root" . "config" $config)

config keys:
  name         string    Required  — ConfigMap name suffix: {fullname}-{name}
  component    string    Optional  — for labels (app.kubernetes.io/component)
  data         object    Required  — key/value pairs (values rendered as YAML block scalars)
  annotations  object    Optional
*/}}
{{- define "sam.configMap" -}}
{{- $root := .root -}}
{{- $cfg := .config -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sam.names.component" (dict "root" $root "component" $cfg.name) }}
  labels:
    {{- include "sam.labels.standard" (dict "root" $root "config" $cfg) | nindent 4 }}
  {{- include "sam.utils.annotations" (dict "annotations" $cfg.annotations) | nindent 2 }}
data:
  {{- range $key, $value := $cfg.data }}
  {{ $key }}: |
{{ $value | nindent 4 }}
  {{- end }}
{{- end }}
