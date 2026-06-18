{{/*
Build the deployment config dict for the AWE component (Go mode).

The output is a YAML text block that deployment_awe.yaml parses via `fromYaml`
and hands to the sam.deployment library helper. AWE configs themselves are
baked into /etc/sam/configs/awe/ in the image (Dockerfile COPY). By default
only sam.yaml (the agent-less base config — carries the trust_manager,
agent_identity, tool_defaults and broker framework blocks but defines no chat
agent) is loaded. The editable Orchestrator agent is seeded into the platform
DB on first run and pushed to AWE over the control plane, not baked here.
Additional baked agents are opt-in via samDeployment.awe.extraConfigs.

AWE does not serve a public HTTP port (only the kubelet probe port) and does
not mount the rbac-config volume. It DOES consume auth-secrets — narrowly,
for the OAUTH_TOOL_REDIRECT_URI key that the agent runtime hands to a tool's
OAuth provider on interactive consent (Atlassian Rovo MCP, etc.). The other
OIDC_* keys in that Secret are unused on AWE; they ride along because envFrom
is whole-Secret. Without auth-secrets on AWE the runtime falls back to
http://localhost:8000/api/v1/auth/tool/callback and the IdP shows an unusable
consent screen with a localhost redirect.

Image resolves via sam.component.image so an empty samDeployment.awe.image.*
field falls back to the corresponding samDeployment.gwe.image.* field.
*/}}
{{- define "sam.awe.config" -}}
{{- $aweImage := include "sam.component.image" (dict "root" . "component" "awe") | fromYaml -}}
component: awe
replicaCount: 1
rollout:
  strategy: Recreate
annotations:
  {{- toYaml .Values.samDeployment.annotations | nindent 2 }}
podAnnotations:
  {{- toYaml .Values.samDeployment.podAnnotations | nindent 2 }}
podLabels:
  {{- with .Values.samDeployment.podLabels }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- if and (eq (include "sam.objectStorage.type" .) "azure") .Values.dataStores.objectStorage.workloadIdentity.enabled }}
  azure.workload.identity/use: "true"
  {{- end }}
podSecurityContext:
  {{- toYaml .Values.samDeployment.podSecurityContext | nindent 2 }}
checksums:
  goEnv: {{ include (print $.Template.BasePath "/configmap-go-env.yaml") . | sha256sum }}
  coreSecrets: {{ include (print $.Template.BasePath "/secret-core.yaml") . | sha256sum }}
  authSecrets: {{ include (print $.Template.BasePath "/secret-auth.yaml") . | sha256sum }}
  database: {{ include (print $.Template.BasePath "/secret-database.yaml") . | sha256sum }}
  storage: {{ include (print $.Template.BasePath "/secret-storage.yaml") . | sha256sum }}
  envOverrides: {{ include (print $.Template.BasePath "/secret_env_overrides.yaml") . | sha256sum }}
serviceAccount:
  name: {{ .Values.samDeployment.serviceAccount.name }}
  annotations:
    {{- toYaml .Values.samDeployment.serviceAccount.annotations | nindent 4 }}
nodeSelector:
  {{- toYaml .Values.samDeployment.nodeSelector | nindent 2 }}
tolerations:
  {{- toYaml .Values.samDeployment.tolerations | nindent 2 }}
podRuntime: {{ .Values.samDeployment.awe.podRuntime | quote }}
imagePullSecrets:
  {{- toYaml (ternary (list .Values.samDeployment.imagePullSecret) nil (not (empty .Values.samDeployment.imagePullSecret))) | nindent 2 }}
caInitImage:
  {{- toYaml (ternary .Values.samDeployment.caInitImage $aweImage (not (empty .Values.samDeployment.caInitImage.repository))) | nindent 2 }}
customCA:
  enabled: {{ .Values.samDeployment.customCA.enabled }}
  configMapName: {{ .Values.samDeployment.customCA.configMapName | quote }}
{{- /* Pass operator extraSecretEnvironmentVars (e.g. Azure Speech STT/TTS creds) into the pod, mirroring sam.core.env for the Python core path. Without this the block is silently dropped on Go pods. */ -}}
{{- with .Values.extraSecretEnvironmentVars }}
extraSecretEnvironmentVars:
  {{- toYaml . | nindent 2 }}
{{- end }}
container:
  image:
    {{- toYaml $aweImage | nindent 4 }}
  command:
    - sam-awe
    - --config
    - /etc/sam/configs/awe/sam.yaml
    {{- range .Values.samDeployment.awe.extraConfigs }}
    - --config
    - {{ . | quote }}
    {{- end }}
    - --health-addr
    - :8090
  ports:
    - name: health
      containerPort: 8090
  envFrom:
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-core-secrets
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-auth-secrets
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-database
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-storage
    - configMapRef:
        name: {{ include "sam.names.fullname" . }}-go-env
  securityContext:
    {{- toYaml .Values.samDeployment.securityContext | nindent 4 }}
  resources:
    {{- toYaml .Values.samDeployment.awe.resources | nindent 4 }}
  probes:
    startup:
      httpGet:
        path: /health
        port: 8090
      initialDelaySeconds: 25
      periodSeconds: 5
      failureThreshold: 30
    readiness:
      httpGet:
        path: /ready
        port: 8090
      periodSeconds: 10
      failureThreshold: 3
    liveness:
      httpGet:
        path: /health
        port: 8090
      periodSeconds: 10
      failureThreshold: 3
  volumeMounts:
    - name: data-dir
      mountPath: /app/data
    {{- if .Values.volumes.enabled }}
    - name: volumes-data
      mountPath: {{ .Values.volumes.mountPath }}
    {{- end }}
{{- if .Values.volumes.enabled }}
volumes:
  - name: volumes-data
    persistentVolumeClaim:
      claimName: {{ .Values.volumes.existingClaim | quote }}
{{- end }}
{{- end -}}
