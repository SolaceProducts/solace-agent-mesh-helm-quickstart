- name: data-dir
  emptyDir: {}
- name: rbac-config
  projected:
    sources:
      - configMap:
          name: {{ include "sam.names.fullname" . }}-role-definitions
      - configMap:
          name: {{ include "sam.names.fullname" . }}-user-roles
{{- if .Values.service.tls.enabled }}
- name: tls-certs
  secret:
    secretName: {{ .Values.service.tls.existingSecret | default (printf "%s-tls" (include "sam.names.fullname" .)) }}
    optional: {{ not .Values.service.tls.enabled }}
{{- end }}
