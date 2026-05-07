{{/*
Standard Kubernetes label helpers.

sam.labels.standard     - Full set of recommended labels. Expects (dict "root" . "config" $cfg).
sam.labels.matchLabels  - Selector labels + component. Expects (dict "root" . "component" "xxx") or root context (.).
sam.labels.component    - Single component label. Expects (dict "component" "xxx").
sam.labels.pod          - Extra pod labels. Expects config dict with optional .podLabels.
*/}}

{{/*
Standard labels (helm.sh/chart, app.kubernetes.io/*).
Expects: (dict "root" . "config" $cfg)
$cfg may contain .component (optional).
*/}}
{{- define "sam.labels.standard" -}}
helm.sh/chart: {{ include "sam.names.chart" .root }}
{{ include "sam.labels.matchLabels" (dict "root" .root "component" .config.component) }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Selector / matchLabels.
Expects: (dict "root" . "component" "xxx") or root Helm context (.).
When component is provided, includes app.kubernetes.io/component in selectors.
*/}}
{{- define "sam.labels.matchLabels" -}}
{{- $root := .root | default . -}}
app.kubernetes.io/name: {{ include "sam.names.name" $root }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Component label.
Expects: dict or config with .component key.
*/}}
{{- define "sam.labels.component" -}}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Extra pod labels.
Expects: config dict with optional .podLabels key.
*/}}
{{- define "sam.labels.pod" -}}
{{- with .podLabels }}
{{- toYaml . }}
{{- end }}
{{- end }}

