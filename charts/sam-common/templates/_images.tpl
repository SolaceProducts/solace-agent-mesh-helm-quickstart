{{/*
Image helpers with global registry support.

sam.images.image       - Resolve full image string (image.registry > global.imageRegistry > none).
sam.images.pullSecrets - Merge global + local imagePullSecrets.
*/}}

{{/*
Build a fully qualified image string.
Expects: (dict "root" . "image" $imageDict)
  $imageDict: { repository, tag, registry (optional), digest (optional), pullPolicy (optional) }
  Priority: image.registry > global.imageRegistry > none
  Tag/Digest: digest takes precedence over tag when present

Returns: "registry/repository:tag", "registry/repository@digest", "repository:tag", or "repository@digest"
*/}}
{{- define "sam.images.image" -}}
{{- $repo := .image.repository -}}

{{- $registry := "" -}}
{{- if .image.registry }}
{{- $registry = printf "%s/" .image.registry }}
{{- else if and .root.Values.global .root.Values.global.imageRegistry}}
{{- $registry = printf "%s/" .root.Values.global.imageRegistry }}
{{- end }}

{{- $reference := "" -}}
{{- if .image.digest }}
{{- $reference = printf "@%s" .image.digest }}
{{- else }}
{{- $tag := .image.tag | default "latest" -}}
{{- $reference = printf ":%s" (toString $tag) }}
{{- end }}

{{- printf "%s%s%s" $registry $repo $reference }}
{{- end }}

{{/*
Render imagePullSecrets merging global and local values.
Expects: (dict "root" . "pullSecrets" $localList)
  $localList: list of secret name strings (optional, can be nil)
  Also checks .root.Values.global.imagePullSecrets (list of strings).

Returns: imagePullSecrets block or empty string.
*/}}
{{- define "sam.images.pullSecrets" -}}
{{- $secrets := list -}}
{{- if .root.Values.global }}
{{- range .root.Values.global.imagePullSecrets }}
{{- $secrets = append $secrets . }}
{{- end }}
{{- if (.root.Values.global.imagePullKey | default "" | trim) }}
{{- $autoName := printf "%s-pull-secret" .root.Release.Name }}
{{- $secrets = append $secrets $autoName }}
{{- end }}
{{- end }}
{{- range .pullSecrets }}
{{- $secrets = append $secrets . }}
{{- end }}
{{- if $secrets }}
imagePullSecrets:
{{- range $secrets | uniq }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
