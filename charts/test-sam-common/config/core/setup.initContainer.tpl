- name: init-setup
  image: {{ include "sam.images.image" (dict "root" . "image" (dict "repository" "busybox" "tag" "1.36")) | quote }}
  securityContext:
    {{- include "sam.security.containerContext" (dict "override" dict) | nindent 4 }}
  {{- include "sam.resources.resolve" (dict "resources" nil "preset" "nano") | nindent 2 }}
  command: ['sh', '-c', 'echo "Component: {{ .cfg.component }}" && echo "Initializing..." && sleep 2']
  volumeMounts:
    - name: empty-dir
      mountPath: /tmp
      subPath: tmp
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
