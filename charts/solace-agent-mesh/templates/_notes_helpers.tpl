{{/*
NOTES.txt display helpers — DRY blocks for host/scheme resolution used in NOTES.txt.
*/}}

{{/*
Resolve the external ingress host from various sources.
Priority: external-dns annotation (if set) > sam.dnsName > ingress.host > ingress.hosts[].host
Aligned with templates/_config_helpers.tpl `sam.urls.compute` so NOTES.txt
output matches the URLs the chart emits to configmaps/secrets.
Expects root context (.) as input.
Returns: a string (the resolved hostname, or empty string if none found).
*/}}
{{- define "sam.notes.ingressHost" -}}
{{- $host := .Values.sam.dnsName -}}
{{- if not $host -}}
  {{- $host = .Values.ingress.host -}}
{{- end -}}
{{- if not $host -}}
  {{- range .Values.ingress.hosts -}}
    {{- if .host -}}
      {{- $host = .host -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if .Values.ingress.annotations -}}
  {{- if hasKey .Values.ingress.annotations "external-dns.alpha.kubernetes.io/hostname" -}}
    {{- $host = index .Values.ingress.annotations "external-dns.alpha.kubernetes.io/hostname" -}}
  {{- end -}}
{{- end -}}
{{- $host -}}
{{- end -}}

{{/*
Detect whether TLS is configured for ingress.
Checks ingress.tls entries and ALB certificate-arn annotation.
Expects root context (.) as input.
Returns: string "true" or "false".
*/}}
{{- define "sam.notes.ingressTls" -}}
{{- $hasTls := false -}}
{{- if and .Values.ingress.tls (gt (len .Values.ingress.tls) 0) -}}
  {{- $hasTls = true -}}
{{- else if and .Values.ingress.annotations (hasKey .Values.ingress.annotations "alb.ingress.kubernetes.io/certificate-arn") -}}
  {{- $hasTls = true -}}
{{- end -}}
{{- ternary "true" "false" $hasTls -}}
{{- end -}}

{{/*
Compute the URL scheme for ingress (https or http).
Expects root context (.) as input.
Returns: "https" or "http".
*/}}
{{- define "sam.notes.ingressScheme" -}}
{{- $hasTls := include "sam.notes.ingressTls" . -}}
{{- ternary "https" "http" (eq $hasTls "true") -}}
{{- end -}}
