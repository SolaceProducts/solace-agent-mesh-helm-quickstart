{{/*
Render the dockerconfigjson Secret created when global.imagePullKey is set.
Expects: (dict "root" .)

The rendered Secret is named `<Release.Name>-pull-secret` to match the
auto-generated reference in `sam.images.pullSecrets`. Renders nothing if
global.imagePullKey is empty.

Input format: a JSON object with a single top-level `.dockerconfigjson` field
whose value is the base64-encoded dockerconfigjson document — the data shape
of a kubernetes.io/dockerconfigjson Secret.
*/}}
{{- define "sam.imagePullSecret" -}}
{{- $root := .root -}}
{{- $cfg := $root.Values.global.imagePullKey | default "" | trim -}}
{{- if $cfg -}}
{{- $parsed := $cfg | fromJson -}}
{{- $b64 := get $parsed ".dockerconfigjson" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ printf "%s-pull-secret" $root.Release.Name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "sam.labels.standard" (dict "root" $root "config" (dict "component" "pull-secret")) | nindent 4 }}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ $b64 }}
{{- end }}
{{- end }}
