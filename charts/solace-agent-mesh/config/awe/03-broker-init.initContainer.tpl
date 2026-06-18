{{- if (include "sam.broker.embedded" .) -}}
{{- $aweImage := include "sam.component.image" (dict "root" . "component" "awe") | fromYaml -}}
{{- include "sam.broker.initContainer" (dict "root" . "image" $aweImage) }}
{{- end }}
