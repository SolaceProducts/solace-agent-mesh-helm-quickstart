{{/*
Adapter helpers for the agent-deployer component.
*/}}

{{/*
Agent deployer envFrom — only what it needs: broker/LLM creds + deployer config.
Does NOT get auth-secrets, database, or storage (least privilege).
*/}}
{{- define "sam.agentDeployer.envFrom" -}}
- secretRef:
    name: {{ include "sam.names.fullname" . }}-core-secrets
- configMapRef:
    name: {{ include "sam.names.fullname" . }}-agent-deployer-config
- configMapRef:
    name: {{ include "sam.names.fullname" . }}-core-env
{{- end -}}

{{/*
Agent deployer env overrides.

When the chart is installed with HTTP_PROXY/HTTPS_PROXY set, kubelet's default
KUBERNETES_SERVICE_HOST (a raw cluster IP) doesn't match string-based NO_PROXY
rules — so the deployer's helm client routes its in-cluster API calls through
the forward proxy and fails. Overriding to the FQDN lets the chart's existing
.svc NO_PROXY entry bypass the proxy.

Disabled by default (no proxy detected) and when kubeApiHost is empty.
*/}}
{{- define "sam.agentDeployer.env" -}}
{{- $envVars := include "sam.utils.envAsMap" .Values.environmentVariables | fromYaml -}}
{{- $proxySet := or (hasKey $envVars "HTTPS_PROXY") (hasKey $envVars "HTTP_PROXY") (hasKey $envVars "https_proxy") (hasKey $envVars "http_proxy") -}}
{{- $kubeApiHost := .Values.samDeployment.agentDeployer.kubeApiHost | default "" -}}
{{- if and $proxySet $kubeApiHost }}
- name: KUBERNETES_SERVICE_HOST
  value: {{ $kubeApiHost | quote }}
{{- end }}
{{- end -}}
