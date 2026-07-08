- name: db-init
  image: {{ include "sam.images.image" (dict "root" . "image" .Values.samDeployment.dbInit.image) | quote }}
  securityContext:
    {{- include "sam.security.containerContext" (dict "override" dict) | nindent 4 }}
  volumeMounts:
    - name: empty-dir
      mountPath: /tmp
      subPath: tmp
    {{- if (dig "customCA" "enabled" false .cfg) }}
    {{- include "sam.cacert.trustVolumeMount" . | nindent 4 }}
    {{- end }}
  envFrom:
    {{- if .Values.global.persistence.enabled }}
    - secretRef:
        name: {{ include "postgresql.secretName" (index .Subcharts "persistence-layer") }}
    {{- end }}
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-database
  {{- $caEnabled := dig "customCA" "enabled" false .cfg -}}
  {{- if or $caEnabled .Values.extraSecretEnvironmentVars }}
  env:
    {{- if $caEnabled }}
    {{- include "sam.cacert.env" nil | nindent 4 }}
    {{- end }}
    {{- range .Values.extraSecretEnvironmentVars }}
    {{- include "sam.utils.envFromSecretRef" . | nindent 4 }}
    {{- end }}
  {{- end }}
  command:
    - "sh"
    - "-c"
    - |
      RETRIES=0
      until pg_isready; do
        RETRIES=$((RETRIES + 1))
        if [ "$RETRIES" -ge 60 ]; then
          echo "ERROR: postgres not ready after 300s. Giving up."
          exit 1
        fi
        echo "Waiting for postgres... (attempt $RETRIES/60)"
        sleep 5
      done
      # Create users
      psql -c "CREATE USER \"$ORCHESTRATOR_DATABASE_USER\" WITH LOGIN PASSWORD '$ORCHESTRATOR_DATABASE_PASSWORD';" || true
      psql -c "CREATE USER \"$WEB_UI_GATEWAY_DATABASE_USER\" WITH LOGIN PASSWORD '$WEB_UI_GATEWAY_DATABASE_PASSWORD';" || true
      psql -c "CREATE USER \"$PLATFORM_DATABASE_USER\" WITH LOGIN PASSWORD '$PLATFORM_DATABASE_PASSWORD';" || true

      # Create databases
      psql -c "CREATE DATABASE \"$ORCHESTRATOR_DATABASE_NAME\";" || true
      psql -c "CREATE DATABASE \"$WEB_UI_GATEWAY_DATABASE_NAME\";" || true
      psql -c "CREATE DATABASE \"$PLATFORM_DATABASE_NAME\";" || true

      # Grant database-level privileges
      psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$ORCHESTRATOR_DATABASE_NAME\" TO \"$ORCHESTRATOR_DATABASE_USER\";" || true
      psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$WEB_UI_GATEWAY_DATABASE_NAME\" TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true
      psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$PLATFORM_DATABASE_NAME\" TO \"$PLATFORM_DATABASE_USER\";" || true

      # Grant schema-level privileges - ORCHESTRATOR
      psql -d "$ORCHESTRATOR_DATABASE_NAME" -c "GRANT USAGE ON SCHEMA public TO \"$ORCHESTRATOR_DATABASE_USER\";" || true
      psql -d "$ORCHESTRATOR_DATABASE_NAME" -c "GRANT CREATE ON SCHEMA public TO \"$ORCHESTRATOR_DATABASE_USER\";" || true
      psql -d "$ORCHESTRATOR_DATABASE_NAME" -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"$ORCHESTRATOR_DATABASE_USER\";" || true
      psql -d "$ORCHESTRATOR_DATABASE_NAME" -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"$ORCHESTRATOR_DATABASE_USER\";" || true
      psql -d "$ORCHESTRATOR_DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$ORCHESTRATOR_DATABASE_USER\";" || true
      psql -d "$ORCHESTRATOR_DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$ORCHESTRATOR_DATABASE_USER\";" || true

      # Grant schema-level privileges - WEB_UI_GATEWAY
      psql -d "$WEB_UI_GATEWAY_DATABASE_NAME" -c "GRANT USAGE ON SCHEMA public TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true
      psql -d "$WEB_UI_GATEWAY_DATABASE_NAME" -c "GRANT CREATE ON SCHEMA public TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true
      psql -d "$WEB_UI_GATEWAY_DATABASE_NAME" -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true
      psql -d "$WEB_UI_GATEWAY_DATABASE_NAME" -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true
      psql -d "$WEB_UI_GATEWAY_DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true
      psql -d "$WEB_UI_GATEWAY_DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$WEB_UI_GATEWAY_DATABASE_USER\";" || true

      # Grant schema-level privileges - PLATFORM
      psql -d "$PLATFORM_DATABASE_NAME" -c "GRANT USAGE ON SCHEMA public TO \"$PLATFORM_DATABASE_USER\";" || true
      psql -d "$PLATFORM_DATABASE_NAME" -c "GRANT CREATE ON SCHEMA public TO \"$PLATFORM_DATABASE_USER\";" || true
      psql -d "$PLATFORM_DATABASE_NAME" -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"$PLATFORM_DATABASE_USER\";" || true
      psql -d "$PLATFORM_DATABASE_NAME" -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"$PLATFORM_DATABASE_USER\";" || true
      psql -d "$PLATFORM_DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$PLATFORM_DATABASE_USER\";" || true
      psql -d "$PLATFORM_DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$PLATFORM_DATABASE_USER\";" || true
