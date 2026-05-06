{{/*
Resource helpers.

sam.resources.preset  - Return resources block for a named preset.
sam.resources.resolve - Resolve resources from explicit dict or preset name.

Expects for resolve: (dict "resources" $dictOrNil "preset" "small")
  Priority: resources (explicit) > preset > empty
Expects for preset:  (dict "preset" "small")
  Presets: nano, small, medium, large, xlarge
*/}}

{{/*
Resolve container resources.
Expects: (dict "resources" $dictOrNil "preset" $stringOrNil)
Returns: full resources block or empty string.
*/}}
{{- define "sam.resources.resolve" -}}
{{- if .resources }}
resources:
  {{- toYaml .resources | nindent 2 }}
{{- else if .preset }}
resources:
  {{- include "sam.resources.preset" (dict "preset" .preset) | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "sam.resources.preset" -}}
{{- $preset := .preset | default "" -}}
{{- if eq $preset "nano" }}
requests:
  cpu: 50m
  memory: 64Mi
limits:
  cpu: 100m
  memory: 128Mi
{{- else if eq $preset "small" }}
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 250m
  memory: 256Mi
{{- else if eq $preset "medium" }}
requests:
  cpu: 250m
  memory: 256Mi
limits:
  cpu: 500m
  memory: 512Mi
{{- else if eq $preset "large" }}
requests:
  cpu: 500m
  memory: 512Mi
limits:
  cpu: 1000m
  memory: 1Gi
{{- else if eq $preset "xlarge" }}
requests:
  cpu: 1000m
  memory: 1Gi
limits:
  cpu: 2000m
  memory: 2Gi
{{- end }}
{{- end }}
