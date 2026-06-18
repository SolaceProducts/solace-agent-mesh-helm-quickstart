{{/*
Build the deployment config dict for the GWE component (Go mode).
Maps feature-driven values.yaml to the library's config dict shape.

The output is a YAML text block that deployment_gwe.yaml parses via `fromYaml`
and hands to the sam.deployment library helper. GWE configs themselves are
baked into /etc/sam/configs/gwe/ in the image (Dockerfile COPY); this helper
wires the pod's shape, env-var sources, probes, and mounts.
*/}}
{{- define "sam.gwe.config" -}}
component: gwe
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
podRuntime: {{ .Values.samDeployment.gwe.podRuntime | quote }}
imagePullSecrets:
  {{- toYaml (ternary (list .Values.samDeployment.imagePullSecret) nil (not (empty .Values.samDeployment.imagePullSecret))) | nindent 2 }}
caInitImage:
  {{- toYaml (ternary .Values.samDeployment.caInitImage .Values.samDeployment.gwe.image (not (empty .Values.samDeployment.caInitImage.repository))) | nindent 2 }}
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
    {{- toYaml .Values.samDeployment.gwe.image | nindent 4 }}
  command:
    - sam-gwe
    - --config
    - /etc/sam/configs/gwe/gwe.yaml
    - --platform-config
    - /etc/sam/configs/gwe/platform.yaml
    - --listen
    - :8080
    - --static-dir
    - /opt/sam/frontend
    - --health-addr
    - :9090
  ports:
    - name: webui
      containerPort: 8080
    - name: health
      containerPort: 9090
    {{- if .Values.service.tls.enabled }}
    - name: webui-tls
      containerPort: 8443
    {{- end }}
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
    {{- toYaml .Values.samDeployment.gwe.resources | nindent 4 }}
  probes:
    startup:
      httpGet:
        path: /health
        port: 9090
      initialDelaySeconds: 25
      periodSeconds: 5
      failureThreshold: 30
    readiness:
      httpGet:
        path: /ready
        port: 9090
      periodSeconds: 10
      failureThreshold: 3
    liveness:
      httpGet:
        path: /health
        port: 9090
      periodSeconds: 10
      failureThreshold: 3
  volumeMounts:
    - name: data-dir
      mountPath: /app/data
    - name: rbac-config
      mountPath: /app/data/config/auth
      readOnly: true
    {{- if .Values.service.tls.enabled }}
    - name: tls-certs
      mountPath: /app/certs
      readOnly: true
    {{- end }}
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
