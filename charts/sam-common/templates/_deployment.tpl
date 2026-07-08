{{/*
Render a Deployment.
Expects: (dict "root" . "config" $config)

config keys:
  component          string    Required  — used for naming, labels, SA, globs
  container:
    image:
      repository     string    Required
      tag            string    Required
      registry       string    Optional  — overrides global.imageRegistry
      pullPolicy     string    Optional  — defaults to IfNotPresent
    command          []string  Optional
    args             []string  Optional
    ports            []object  Optional
    env              []object  Optional
    envFrom          []object  Optional
    securityContext   object   Optional  — merged over container security defaults
    resources        object    Optional  — explicit resources (takes priority)
    resourcePreset   string    Optional  — named preset: nano|small|medium|large|xlarge
    probes:
      startup        object   Optional
      readiness      object   Optional
      liveness       object   Optional
    volumeMounts     []object  Optional  — additional mounts (/tmp is always mounted)
  replicaCount       int       Optional  — defaults to 1
  volumes            []object  Optional  — inline volumes (rendered before glob volumes)
  rollout:
    strategy         string    Optional  — defaults to RollingUpdate
    rollingUpdate    object    Optional
  annotations        object    Optional  — deployment-level annotations
  podSecurityContext  object   Optional  — merged over pod security defaults
  podLabels          object    Optional
  podAnnotations     object    Optional
  checksums          object    Optional  — config/env/loggingConfig checksums
  azureWorkloadIdentity bool   Optional
  serviceAccount:
    name             string    Optional  — explicit SA name (default: {fullname}-{component}-sa)
    annotations      object    Optional  — SA annotations (rendered by sam.serviceAccount, not here)
  imagePullSecrets   []string  Optional  — merged with global.imagePullSecrets
  nodeSelector       object    Optional
  tolerations        []object  Optional
  caInitImage        object    Optional  — image dict for the ca-merge init container (which image runs the merge)
                                           assumed Debian-based: needs sh, cp, cat, /etc/ssl/certs/ca-certificates.crt
  customCA:
    enabled          bool      Optional  — set true to inject ca-merge init container, ca-trust volumes, and CA env vars
                                           when enabled, create a 'truststore' ConfigMap with *.crt keys in the namespace

Security defaults are always applied (pod: UID 999, non-root, seccomp; container: drop ALL, no privilege escalation). Override via podSecurityContext / container.securityContext.

Volumes: emptyDir (always) → cacert + ca-trust (when customCA.enabled) → config.volumes (inline) → config/{component}/volumes.tpl (glob)
VolumeMounts: /tmp (always) → /ca-trust read-only (when customCA.enabled) → config.container.volumeMounts
Init containers: ca-merge (when customCA.enabled, always first) → config/{component}/*.initContainer.tpl (glob)
ServiceAccount: config.serviceAccount.name or {fullname}-{component}-sa
*/}}
{{- define "sam.deployment" -}}
{{- $root := .root -}}
{{- $cfg := .config -}}
{{- $name := include "sam.names.component" (dict "root" $root "component" $cfg.component) -}}
{{- $caEnabled := dig "customCA" "enabled" false $cfg -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  labels:
    {{- include "sam.labels.standard" (dict "root" $root "config" $cfg) | nindent 4 }}
  {{- include "sam.utils.annotations" (dict "annotations" $cfg.annotations) | nindent 2 }}
spec:
  replicas: {{ $cfg.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- include "sam.labels.matchLabels" (dict "root" $root "component" $cfg.component) | nindent 6 }}
  strategy:
    type: {{ dig "rollout" "strategy" "RollingUpdate" $cfg }}
    {{- with (dig "rollout" "rollingUpdate" nil $cfg) }}
    rollingUpdate:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  template:
    metadata:
      {{- with (include "sam.utils.podAnnotations" $cfg) }}
      annotations:
        {{- . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "sam.labels.matchLabels" (dict "root" $root "component" $cfg.component) | nindent 8 }}
        {{- include "sam.labels.pod" $cfg | nindent 8 }}
    spec:
      serviceAccountName: {{ include "sam.names.serviceAccount" (dict "root" $root "config" $cfg) }}
      securityContext:
        {{- include "sam.security.podContext" (dict "override" $cfg.podSecurityContext) | nindent 8 }}
      {{- include "sam.images.pullSecrets" (dict "root" $root "pullSecrets" $cfg.imagePullSecrets) | nindent 6 }}
      {{- $initContainerGlob := printf "config/%s/*.initContainer.tpl" $cfg.component }}
      {{- if or $caEnabled ($root.Files.Glob $initContainerGlob) }}
      {{- $tplCtx := deepCopy $root -}}
      {{- $_ := set $tplCtx "cfg" $cfg }}
      initContainers:
        {{- if $caEnabled }}
        {{- include "sam.cacert.initContainerSpec" (dict "root" $root "config" $cfg) | nindent 8 }}
        {{- end }}
        {{- $initPaths := list }}
        {{- range $path, $_ := $root.Files.Glob $initContainerGlob }}
        {{- $initPaths = append $initPaths $path }}
        {{- end }}
        {{- range $path := $initPaths | sortAlpha }}
        {{- tpl ($root.Files.Get $path) $tplCtx | trim | nindent 8 }}
        {{- end }}
      {{- end }}
      containers:
        - name: {{ $cfg.component }}
          image: {{ include "sam.images.image" (dict "root" $root "image" $cfg.container.image) | quote }}
          imagePullPolicy: {{ $cfg.container.image.pullPolicy | default "IfNotPresent" }}
          {{- with $cfg.container.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $cfg.container.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $cfg.container.ports }}
          ports:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- include "sam.utils.env" (dict "config" $cfg "root" $root) | nindent 10 }}
          {{- with $cfg.container.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          securityContext:
            {{- include "sam.security.containerContext" (dict "override" $cfg.container.securityContext) | nindent 12 }}
          {{- include "sam.resources.resolve" (dict "resources" $cfg.container.resources "preset" $cfg.container.resourcePreset) | nindent 10 }}
          {{- include "sam.deployment.probes" $cfg.container.probes | nindent 10 }}
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp
            {{- if $caEnabled }}
            {{- include "sam.cacert.trustVolumeMount" . | nindent 12 }}
            {{- end }}
            {{- with $cfg.container.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      {{- with $cfg.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $cfg.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: empty-dir
          emptyDir: {}
        {{- if $caEnabled }}
        {{- include "sam.cacert.volume" (dig "customCA" "configMapName" "truststore" $cfg) | nindent 8 }}
        {{- include "sam.cacert.trustVolume" . | nindent 8 }}
        {{- end }}
        {{- with $cfg.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- $volumesGlob := printf "config/%s/volumes.tpl" $cfg.component }}
        {{- $volPaths := list }}
        {{- range $path, $_ := $root.Files.Glob $volumesGlob }}
        {{- $volPaths = append $volPaths $path }}
        {{- end }}
        {{- range $path := $volPaths | sortAlpha }}
        {{- tpl ($root.Files.Get $path) $root | trim | nindent 8 }}
        {{- end }}
{{- end -}}

{{/*
Render container probes (startup, readiness, liveness).
Expects: probes dict with optional keys: .startup, .readiness, .liveness
*/}}
{{- define "sam.deployment.probes" -}}
{{- if . -}}
{{- with .startup }}
startupProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .readiness }}
readinessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .liveness }}
livenessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
{{- end -}}