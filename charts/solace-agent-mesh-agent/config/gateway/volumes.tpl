- name: shared-storage
  emptyDir: {}
- name: config-volume
  configMap:
    name: {{ include "sam.names.component" (dict "root" . "component" "config") }}
- name: logging-config-volume
  configMap:
    name: {{ include "sam.names.component" (dict "root" . "component" "logging-config") }}
