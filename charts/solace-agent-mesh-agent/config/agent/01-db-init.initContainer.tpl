- name: db-init
  image: {{ include "sam.images.image" (dict "root" . "image" .Values.dbInit.image) | quote }}
  imagePullPolicy: {{ .Values.dbInit.image.pullPolicy }}
  securityContext:
    {{- include "sam.security.containerContext" (dict "override" dict) | nindent 4 }}
  volumeMounts:
    - name: empty-dir
      mountPath: /tmp
      subPath: tmp
    {{- if (dig "customCA" "enabled" false .cfg) }}
    {{- include "sam.cacert.trustVolumeMount" . | nindent 4 }}
    {{- end }}
  {{- if (dig "customCA" "enabled" false .cfg) }}
  env:
    {{- include "sam.cacert.env" . | nindent 4 }}
  {{- end }}
  envFrom:
    - secretRef:
        name: {{ include "sam.postgresql.secretName" . }} 
    - secretRef:
        name: {{ include "sam.names.component" (dict "root" . "component" "init-credentials") }}
  command:
    - "sh"
    - "-c"
    - |
      until pg_isready; do
        echo "Waiting for postgres..."
        sleep 5
      done
      # Create user and database
      psql -c "CREATE USER \"$DATABASE_USER\" WITH LOGIN PASSWORD '$DATABASE_PASSWORD';" || true
      psql -c "CREATE DATABASE \"$DATABASE_NAME\";" || true

      # Grant database-level privileges
      psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DATABASE_NAME\" TO \"$DATABASE_USER\";" || true

      # Grant schema-level privileges
      psql -d "$DATABASE_NAME" -c "GRANT USAGE ON SCHEMA public TO \"$DATABASE_USER\";" || true
      psql -d "$DATABASE_NAME" -c "GRANT CREATE ON SCHEMA public TO \"$DATABASE_USER\";" || true
      psql -d "$DATABASE_NAME" -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"$DATABASE_USER\";" || true
      psql -d "$DATABASE_NAME" -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"$DATABASE_USER\";" || true
      psql -d "$DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$DATABASE_USER\";" || true
      psql -d "$DATABASE_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"$DATABASE_USER\";" || true
