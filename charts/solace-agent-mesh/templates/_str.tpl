{{/*
Build the deployment config dict for the STR component (Go mode).

The output is a YAML text block that deployment_str.yaml parses via `fromYaml`
and hands to the sam.deployment library helper. STR's config is baked into
/etc/sam/configs/str/str.yaml in the image (Dockerfile.str COPY); the binary's
ENTRYPOINT loads it by default. The chart restates --config and --tools-dir
explicitly for self-documentation and operator override.

STR is an enterprise-side tool runtime: it does NOT serve a public HTTP port
(only the kubelet probe port), does NOT consume auth-secrets, and does NOT
access the database directly (no `database` envFrom, no `database` checksum).

Writable mounts (data-dir / tools-dir / skills-dir) match the layout that
the previous chart on mradwan/go-platform-helm-updates rendered for this
component. They are required because sam-common's container security
defaults set readOnlyRootFilesystem=true: without an emptyDir overlay at
/opt/sam/tools and /opt/sam/skills, the STR's objectstore-mirror fails to
MkdirAll <toolset|skill>/ with EROFS and the toolset never registers in
memory — silently breaking every uploaded toolset's invoke path. The
mirror is the ONLY writer to these paths; /opt/sam/builtin-tools stays
unmounted so the baked Python venvs for built-in tools survive.

Image MUST resolve to `solace-agent-mesh-str`, NOT `solace-agent-mesh`,
because only the STR image has Python venvs for the baked tools. The chart
ships str.image.repository = "solace-agent-mesh-str" so an empty operator
override would not silently fall back to gwe.image (which has no venvs).
*/}}
{{- define "sam.str.config" -}}
{{- $strImage := include "sam.component.image" (dict "root" . "component" "str") | fromYaml -}}
component: str
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
podRuntime: {{ .Values.samDeployment.str.podRuntime | quote }}
imagePullSecrets:
  {{- toYaml (ternary (list .Values.samDeployment.imagePullSecret) nil (not (empty .Values.samDeployment.imagePullSecret))) | nindent 2 }}
caInitImage:
  {{- toYaml (ternary .Values.samDeployment.caInitImage $strImage (not (empty .Values.samDeployment.caInitImage.repository))) | nindent 2 }}
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
    {{- toYaml $strImage | nindent 4 }}
  command:
    - sam-str
    - --config
    - /etc/sam/configs/str/str.yaml
    - --tools-dir
    - /opt/sam/builtin-tools
    - --health-addr
    - :8090
  ports:
    - name: health
      containerPort: 8090
  envFrom:
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-core-secrets
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-storage
    - configMapRef:
        name: {{ include "sam.names.fullname" . }}-go-env
  securityContext:
    {{- toYaml .Values.samDeployment.securityContext | nindent 4 }}
  resources:
    {{- toYaml .Values.samDeployment.str.resources | nindent 4 }}
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
    - name: tools-dir
      mountPath: /opt/sam/tools
    - name: skills-dir
      mountPath: /opt/sam/skills
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
