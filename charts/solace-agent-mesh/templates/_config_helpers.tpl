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
{{- /* Go-mode URL fixups (apply unconditionally — both ingress and no-ingress branches above respected operator overrides):

      1. frontendServerUrl: values.yaml ships "http://localhost:8000" as the
         Python-mode local-cluster default (matches Python's container port 8000).
         Go's GWE serves the UI on container port 8080. When the operator has
         left the values.yaml default in place (i.e. local-cluster smoke test
         on kind), swap to localhost:8080 so port-forward 8080:80 produces
         a frontend bootstrap URL the browser can actually reach. Any
         operator-supplied value (DNS name, ingress host, real URL) is
         left untouched.

      2. platformServiceUrl, authServiceUrl: in Go mode both the platform
         service and the auth service are in-process with GWE — they must
         equal the frontend URL unconditionally. The Python-mode no-ingress
         branch above computes platformServiceUrl on port 8080/4443 and
         authServiceUrl on port 5050; neither port is exposed by
         service_gwe.yaml (8080/8443 webui + 9090 health only), so leaving
         them unmapped breaks platform UI calls and the OIDC auth flow when
         sam.dnsName is set. Override both to match frontendServerUrl —
         parallels the ingress branch, which already does this for Python. */ -}}
{{- if eq (.Values.sam.platform | default "python") "go" }}
  {{- if eq $frontendServerUrl "http://localhost:8000" }}
    {{- $frontendServerUrl = "http://localhost:8080" }}
    {{- $externalBaseUrl = $frontendServerUrl }}
    {{- $authCallbackUrl = printf "%s/api/v1/auth/callback" $frontendServerUrl }}
  {{- end }}
  {{- $platformServiceUrl = $frontendServerUrl }}
  {{- $authServiceUrl = $frontendServerUrl }}
{{- end }}
{{- /* FE-only API base URL overrides. Default to the shared frontendServerUrl /
       platformServiceUrl so the value the FE sees via /api/v1/config is
       identical to today's behavior. Operators opt into a different value
       (e.g., "" for same-origin) by setting sam.fe.apiBaseUrl /
       sam.fe.platformBaseUrl. Only affects the FE config response — env vars
       consumed by OAuth callback construction, MCP gateway issuer, and
       connector service URL are unchanged.

       The same `hasKey` gates are repeated in configmap-webui.yaml (lines 56,
       120) — the consumer chooses between $urls.feApiBaseUrl and the legacy
       ${FRONTEND_SERVER_URL, ""} substitution based on whether the operator
       opted in. Keep both sides of the gate in sync. */ -}}
{{- $feApiBaseUrl := $frontendServerUrl }}
{{- if and .Values.sam.fe (hasKey .Values.sam.fe "apiBaseUrl") }}
  {{- $feApiBaseUrl = .Values.sam.fe.apiBaseUrl }}
{{- end }}
{{- $fePlatformBaseUrl := $platformServiceUrl }}
{{- if and .Values.sam.fe (hasKey .Values.sam.fe "platformBaseUrl") }}
  {{- $fePlatformBaseUrl = .Values.sam.fe.platformBaseUrl }}
{{- end }}
{{- /* toolCallbackUrl: where a tool's OAuth provider (e.g. Atlassian Rovo MCP)
       redirects after interactive consent. Consumed by the agent runtime in
       Go mode (cmd/awe → internal/auth/toolauth/oauth2.go) and emitted into
       the auth-secrets Secret as OAUTH_TOOL_REDIRECT_URI. Always derives from
       the post-fixup frontendServerUrl so it tracks ingress / dnsName / Go's
       localhost:8080 fixup uniformly. */ -}}
{{- $toolCallbackUrl := printf "%s/api/v1/auth/tool/callback" $frontendServerUrl }}
frontendServerUrl: {{ $frontendServerUrl }}
platformServiceUrl: {{ $platformServiceUrl }}
feApiBaseUrl: {{ $feApiBaseUrl | quote }}
fePlatformBaseUrl: {{ $fePlatformBaseUrl | quote }}
externalBaseUrl: {{ $externalBaseUrl }}
authCallbackUrl: {{ $authCallbackUrl }}
toolCallbackUrl: {{ $toolCallbackUrl }}
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
