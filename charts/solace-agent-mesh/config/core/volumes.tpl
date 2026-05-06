- name: shared-storage
  emptyDir: {}
- name: tls-certs
  secret:
    secretName: {{ .Values.service.tls.existingSecret | default (printf "%s-tls" (include "sam.names.fullname" .)) }}
    optional: {{ not .Values.service.tls.enabled }}
- name: logging-config-volume
  configMap:
    name: {{ include "sam.names.fullname" . }}-logging-config
- name: config-volume
  projected:
    sources:
      - configMap:
          name: {{ include "sam.names.fullname" . }}-shared-config
      {{- if not .Values.sam.communityMode }}
      - configMap:
          name: {{ include "sam.names.fullname" . }}-oauth2-server-config
          items:
            - key: oauth2_server.yaml
              path: auth/oauth2_server.yaml
      - configMap:
          name: {{ include "sam.names.fullname" . }}-oauth2-config
          items:
            - key: oauth2_config.yaml
              path: auth/oauth2_config.yaml
      - configMap:
          name: {{ include "sam.names.fullname" . }}-enterprise-config
      - configMap:
          name: {{ include "sam.names.fullname" . }}-role-definitions
          items:
            - key: role-to-scope-definitions.yaml
              path: auth/role-to-scope-definitions.yaml
      - configMap:
          name: {{ include "sam.names.fullname" . }}-user-roles
          items:
            - key: user-to-role-assignments.yaml
              path: auth/user-to-role-assignments.yaml
      {{- end }}
      - configMap:
          name: {{ include "sam.names.fullname" . }}-orchestrator-config
      - configMap:
          name: {{ include "sam.names.fullname" . }}-webui-config
      - configMap:
          name: {{ include "sam.names.fullname" . }}-platform-config
