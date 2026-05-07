{{/*
Render a Service.
Expects: (dict "root" . "config" $config)

config keys:
  name                     string    Optional  — explicit service name (overrides component-based name)
  component                string    Required  — used for naming (if name not set) and selector
  type                     string    Optional  — ClusterIP (default), NodePort, LoadBalancer
  clusterIP                string    Optional  — set to "None" for headless services
  ports:                   []object  Required
    - port                 int       Required
      targetPort           int       Required
      protocol             string    Optional  — defaults to TCP
      name                 string    Required
      nodePort             int       Optional  — only for NodePort/LoadBalancer
  annotations              object    Optional  — service-level annotations
  publishNotReadyAddresses bool      Optional  — only rendered if explicitly set
*/}}
{{- define "sam.service" -}}
{{- $root := .root -}}
{{- $cfg := .config -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sam.names.service" (dict "root" $root "config" $cfg) }}
  labels:
    {{- include "sam.labels.standard" (dict "root" $root "config" $cfg) | nindent 4 }}
  {{- include "sam.utils.annotations" (dict "annotations" $cfg.annotations) | nindent 2 }}
spec:
  type: {{ $cfg.type | default "ClusterIP" }}
  {{- if $cfg.clusterIP }}
  clusterIP: {{ $cfg.clusterIP }}
  {{- end }}
  {{- if hasKey $cfg "publishNotReadyAddresses" }}
  publishNotReadyAddresses: {{ $cfg.publishNotReadyAddresses }}
  {{- end }}
  ports:
    {{- range $cfg.ports }}
    - port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol | default "TCP" }}
      name: {{ .name }}
      {{- if .nodePort }}
      nodePort: {{ .nodePort }}
      {{- end }}
    {{- end }}
  selector:
    {{- include "sam.labels.matchLabels" (dict "root" $root "component" $cfg.component) | nindent 4 }}
{{- end }}
