{{/*
solace-agent-mesh-agent.validations.all

Input validation for the standalone agent chart. Currently only validates
global.imagePullKey: mutual exclusivity with imagePullSecrets sources, JSON
shape, and the .dockerconfigjson field.

Mutual-exclusivity check considers BOTH .Values.imagePullSecrets (chart-local)
and .Values.global.imagePullSecrets (cross-chart) — the agent chart accepts
either source, both flow into the rendered pod spec via sam.images.pullSecrets.

Consumer: include once near the top of a template that always renders
(deployment.yaml).
*/}}
{{- define "solace-agent-mesh-agent.validations.all" -}}
{{- $key := .Values.global.imagePullKey | trim -}}
{{- $localSecrets := .Values.imagePullSecrets | default list -}}
{{- $globalSecrets := .Values.global.imagePullSecrets | default list -}}
{{- if and $key (or (gt (len $localSecrets) 0) (gt (len $globalSecrets) 0)) -}}
{{- fail "global.imagePullKey is mutually exclusive with imagePullSecrets and global.imagePullSecrets. Use imagePullKey to let the chart manage the pull secret, or imagePullSecrets to reference a pre-created one — not both." -}}
{{- end -}}
{{- if $key -}}
{{- $parsed := $key | fromJson -}}
{{- if or (not (kindIs "map" $parsed)) (hasKey $parsed "Error") -}}
{{- fail "global.imagePullKey must be a valid JSON object with a \".dockerconfigjson\" field" -}}
{{- end -}}
{{- if not (hasKey $parsed ".dockerconfigjson") -}}
{{- fail "global.imagePullKey must contain a \".dockerconfigjson\" field" -}}
{{- end -}}
{{- if not (get $parsed ".dockerconfigjson") -}}
{{- fail "global.imagePullKey \".dockerconfigjson\" must be non-empty" -}}
{{- end -}}
{{- end -}}
{{- end -}}
