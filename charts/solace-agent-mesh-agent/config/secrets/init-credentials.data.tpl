DATABASE_USER: {{ include "sam.database.agentUser" . | b64enc }}
DATABASE_PASSWORD: {{ include "sam.database.agentPassword" . | b64enc }}
DATABASE_NAME: {{ include "sam.database.agentName" . | b64enc }}
{{- if .Values.persistence.database.host }}
DATABASE_URL: {{ printf "%s://%s:%s@%s:%s/%s" .Values.persistence.database.protocol (include "sam.database.agentUser" .) (include "sam.database.agentPassword" .) .Values.persistence.database.host (.Values.persistence.database.port | toString) (include "sam.database.agentName" .) | b64enc }}
{{- end }}
