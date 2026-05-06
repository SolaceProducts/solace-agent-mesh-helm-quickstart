{{/*
Shared config block helpers — DRY blocks used across multiple configmaps and secrets.
*/}}

{{/*
Compute external URLs based on Ingress vs Service exposure.
Returns YAML dict with: frontendServerUrl, platformServiceUrl, externalBaseUrl, authCallbackUrl, authServiceUrl, externalHost
Used by: configmap-core-env.yaml, secret-auth.yaml
*/}}
{{- define "sam.urls.compute" -}}
{{- $serviceDns := printf "%s-core.%s.svc.cluster.local" (include "sam.names.fullname" .) .Release.Namespace }}
{{- $externalHost := "" }}
{{- $externalScheme := "" }}
{{- $externalBaseUrl := "" }}
{{- $authCallbackUrl := "" }}
{{- $authServiceUrl := "" }}
{{- $frontendServerUrl := "" }}
{{- $platformServiceUrl := "" }}
{{- if .Values.ingress.enabled }}
  {{- $ingressHost := .Values.ingress.host }}
  {{- if not $ingressHost }}
    {{- range .Values.ingress.hosts }}
      {{- if .host }}{{ $ingressHost = .host }}{{ end }}
    {{- end }}
  {{- end }}
  {{- /* Prefer sam.dnsName over ingress.host: K8s Ingress.spec.rules[].host
         is port-less by spec; dnsName carries the operator's external URL
         and may include a non-standard port (kind hostPort, NodePort). */ -}}
  {{- $externalHost = .Values.sam.dnsName | default $ingressHost | default $serviceDns }}
  {{- $hasIngressTls := false }}
  {{- if and .Values.ingress.tls (gt (len .Values.ingress.tls) 0) }}
    {{- $hasIngressTls = true }}
  {{- else if and .Values.ingress.annotations (hasKey .Values.ingress.annotations "alb.ingress.kubernetes.io/certificate-arn") }}
    {{- $hasIngressTls = true }}
  {{- end }}
  {{- $externalScheme = ternary "https" "http" $hasIngressTls }}
  {{- $externalBaseUrl = printf "%s://%s" $externalScheme $externalHost }}
  {{- if or $ingressHost .Values.sam.dnsName }}
  {{- $frontendServerUrl = $externalBaseUrl }}
  {{- else }}
  {{- $frontendServerUrl = .Values.sam.frontendServerUrl | default $externalBaseUrl }}
  {{- end }}
  {{- $externalBaseUrl = $frontendServerUrl }}
  {{- if or $ingressHost .Values.sam.dnsName }}
  {{- $platformServiceUrl = $externalBaseUrl }}
  {{- else }}
  {{- $platformServiceUrl = .Values.sam.platformServiceUrl | default $externalBaseUrl }}
  {{- end }}
  {{- $authCallbackUrl = printf "%s/api/v1/auth/callback" $frontendServerUrl }}
  {{- $authServiceUrl = $frontendServerUrl }}
{{- else }}
  {{- $externalHost = .Values.sam.dnsName | default $serviceDns }}
  {{- $externalScheme = ternary "https" "http" .Values.service.tls.enabled }}
  {{- $authPort := "5050" }}
  {{- $platformPort := ternary "4443" "8080" .Values.service.tls.enabled }}
  {{- $frontendServerUrl = .Values.sam.frontendServerUrl | default (printf "%s://%s" $externalScheme $externalHost) }}
  {{- /* When dnsName is not set, leave platformServiceUrl empty so the UI shows "unconfigured" rather than an unreachable cluster-internal URL */}}
  {{- if .Values.sam.dnsName }}
  {{- $platformServiceUrl = .Values.sam.platformServiceUrl | default (printf "%s://%s:%s" $externalScheme $externalHost $platformPort) }}
  {{- else }}
  {{- $platformServiceUrl = .Values.sam.platformServiceUrl | default "" }}
  {{- end }}
  {{- $externalBaseUrl = $frontendServerUrl }}
  {{- $authCallbackUrl = printf "%s/api/v1/auth/callback" $frontendServerUrl }}
  {{- $authServiceUrl = printf "%s://%s:%s" $externalScheme $externalHost $authPort }}
{{- end }}
frontendServerUrl: {{ $frontendServerUrl }}
platformServiceUrl: {{ $platformServiceUrl }}
externalBaseUrl: {{ $externalBaseUrl }}
authCallbackUrl: {{ $authCallbackUrl }}
authServiceUrl: {{ $authServiceUrl }}
externalHost: {{ $externalHost }}
{{- end -}}

{{/*
Artifact service config block (S3 / Azure / GCS).
Used by orchestrator-config and webui-config.
*/}}
{{- define "sam.config.artifactService" -}}
{{- $storageType := include "sam.objectStorage.type" . }}
artifact_service:
{{- if eq $storageType "azure" }}
  type: "azure"
  container_name: "${AZURE_STORAGE_CONTAINER_NAME}"
  account_name: "${AZURE_STORAGE_ACCOUNT_NAME}"
{{- else if eq $storageType "gcs" }}
  type: "gcs"
  bucket_name: "${GCS_BUCKET_NAME}"
{{- else }}
  type: "s3"
  bucket_name: "${S3_BUCKET_NAME}"
  endpoint_url: "${S3_ENDPOINT_URL}"
{{- end }}
{{- end -}}

{{/*
ConfigMap metadata helper — consistent naming and labels.
Args: (dict "root" . "name" "shared-config" "component" "core")
*/}}
{{- define "sam.config.metadata" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sam.names.fullname" .root }}-{{ .name }}
  labels:
    {{- include "sam.labels.standard" (dict "root" .root "config" (dict "component" (.component | default "core"))) | nindent 4 }}
{{- end -}}
