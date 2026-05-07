{{/*
Render a Secret.
Expects: (dict "root" . "config" $config)

config keys:
  name         string    Required  — secret name suffix: {fullname}-{name}
  component    string    Optional  — for labels (app.kubernetes.io/component)
  type         string    Optional  — defaults to Opaque
  data         object    Optional  — base64-encoded key/value pairs
  stringData   object    Optional  — plain-text key/value pairs (K8s encodes automatically)
  annotations  object    Optional
*/}}
{{- define "sam.secret" -}}
{{- $root := .root -}}
{{- $cfg := .config -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "sam.names.component" (dict "root" $root "component" $cfg.name) }}
  labels:
    {{- include "sam.labels.standard" (dict "root" $root "config" $cfg) | nindent 4 }}
  {{- include "sam.utils.annotations" (dict "annotations" $cfg.annotations) | nindent 2 }}
type: {{ $cfg.type | default "Opaque" }}
{{- with $cfg.data }}
data:
  {{- range $key, $value := . }}
  {{ $key }}: {{ $value }}
  {{- end }}
{{- end }}
{{- with $cfg.stringData }}
stringData:
  {{- range $key, $value := . }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end }}
