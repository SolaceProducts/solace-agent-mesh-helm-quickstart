{{- if (include "sam.broker.embedded" .) -}}
{{- $strImage := include "sam.component.image" (dict "root" . "component" "str") | fromYaml -}}
{{- include "sam.broker.initContainer" (dict "root" . "image" $strImage) }}
{{- end }}
