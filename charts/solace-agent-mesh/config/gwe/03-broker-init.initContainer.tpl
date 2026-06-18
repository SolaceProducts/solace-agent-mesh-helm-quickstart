{{- if (include "sam.broker.embedded" .) -}}
{{- include "sam.broker.initContainer" (dict "root" . "image" .Values.samDeployment.gwe.image) }}
{{- end }}
