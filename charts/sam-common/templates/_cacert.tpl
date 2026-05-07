{{/*
CA certificate helpers.

sam.cacert.volume            - ConfigMap volume (name: truststore, optional: true).
sam.cacert.trustVolume       - emptyDir volume for the merged CA bundle.
sam.cacert.trustVolumeMount  - Read-only /ca-trust mount for main container and init containers.
sam.cacert.env               - Four CA env vars pointing to /ca-trust/ca-bundle.crt.
sam.cacert.initContainerSpec - ca-merge init container. Copies system bundle, appends every *.crt from ConfigMap.

All five are injected automatically by sam.deployment when config.customCA.enabled is true.
Consumers only need to set customCA.enabled and pass caInitImage in the config dict.
*/}}

{{/*
Pod-level ConfigMap volume.
optional: true — pod starts normally when ConfigMap is absent (system bundle only).
Expects: the ConfigMap name as a string.
*/}}
{{- define "sam.cacert.volume" -}}
- name: cacert
  configMap:
    name: {{ . }}
    optional: true
{{- end -}}

{{/*
Pod-level emptyDir for the merged CA bundle.
Written by ca-merge init container, read by all subsequent containers.
*/}}
{{- define "sam.cacert.trustVolume" -}}
- name: ca-trust
  emptyDir: {}
{{- end -}}

{{/*
Read-only /ca-trust mount plus a subPath overlay at the Debian system CA path.
The subPath mount causes the merged bundle to replace /etc/ssl/certs/ca-certificates.crt
so that OpenSSL-based clients (e.g. Solace C SDK, libpq) pick it up from the default
system store path, without needing any env var awareness.
Used by main container and db-init containers.
*/}}
{{- define "sam.cacert.trustVolumeMount" -}}
- name: ca-trust
  mountPath: /ca-trust
  readOnly: true
- name: ca-trust
  mountPath: /etc/ssl/certs/ca-certificates.crt
  subPath: ca-bundle.crt
  readOnly: true
{{- end -}}

{{/*
CA environment variables pointing to the merged bundle.
  SSL_CERT_FILE       — Python ssl module, Go crypto/tls
  REQUESTS_CA_BUNDLE  — Python requests library
  TRUST_STORE         — Solace PubSub+ client (directory path)
  PGSSLROOTCERT       — libpq / psycopg2 (does not read SSL_CERT_FILE)
*/}}
{{- define "sam.cacert.env" -}}
- name: SSL_CERT_FILE
  value: /ca-trust/ca-bundle.crt
- name: REQUESTS_CA_BUNDLE
  value: /ca-trust/ca-bundle.crt
- name: TRUST_STORE
  value: /ca-trust/
- name: PGSSLROOTCERT
  value: /ca-trust/ca-bundle.crt
{{- end -}}

{{/*
ca-merge init container spec.
Copies system bundle to emptyDir, then appends every *.crt file from the
cacert ConfigMap (if present). Supports one file or many — any key ending
in .crt is appended to the merged bundle.

Uses config.caInitImage — assumed to be a Debian-based image with sh, cp,
cat, and the system CA bundle at /etc/ssl/certs/ca-certificates.crt.
If the base image changes to a different distro, update the cp path below.

Expects: (dict "root" . "config" $cfg)
*/}}
{{- define "sam.cacert.initContainerSpec" -}}
{{- $img := .config.caInitImage -}}
- name: ca-merge
  image: {{ include "sam.images.image" (dict "root" .root "image" $img) | quote }}
  imagePullPolicy: {{ $img.pullPolicy | default "IfNotPresent" }}
  command: ["sh", "-c"]
  args:
    - |
      SRC=/etc/ssl/certs/ca-certificates.crt
      if [ ! -f "$SRC" ]; then
        echo "ERROR: system CA bundle not found at $SRC. caInitImage must be a Debian-based image. Set samDeployment.caInitImage to a Debian-based image or disable customCA."
        exit 1
      fi
      cp "$SRC" /ca-trust/ca-bundle.crt
      for cert in /custom-ca/*.crt; do
        if [ -f "$cert" ]; then
          cat "$cert" >> /ca-trust/ca-bundle.crt
          cp "$cert" /ca-trust/
        fi
      done
      command -v openssl >/dev/null 2>&1 && openssl rehash /ca-trust/ || true
  securityContext:
    {{- include "sam.security.containerContext" (dict "override" dict) | nindent 4 }}
  volumeMounts:
    - name: empty-dir
      mountPath: /tmp
      subPath: tmp
    - name: cacert
      mountPath: /custom-ca
      readOnly: true
    - name: ca-trust
      mountPath: /ca-trust
{{- end -}}
