{{- if .Values.global.persistence.enabled }}
- name: s3-init
  image: {{ include "sam.images.image" (dict "root" . "image" .Values.samDeployment.s3Init.image) | quote }}
  securityContext:
    {{- include "sam.security.containerContext" (dict "override" dict) | nindent 4 }}
  volumeMounts:
    - name: empty-dir
      mountPath: /tmp
      subPath: tmp
  envFrom:
    - secretRef:
        name: {{ include "seaweedfs.secretName" (index .Subcharts "persistence-layer") }}
    - secretRef:
        name: {{ include "sam.names.fullname" . }}-storage
  {{- with .Values.extraSecretEnvironmentVars }}
  env:
    {{- range . }}
    {{- include "sam.utils.envFromSecretRef" . | nindent 4 }}
    {{- end }}
  {{- end }}
  command:
    - sh
    - -c
    - |
      echo "Waiting for SeaweedFS server to be ready..."
      RETRIES=0
      until wget --timeout=3 --tries=1 -qO- $SEAWEEDFS_MASTER_ENDPOINT_STATUS_URL >/dev/null; do
        RETRIES=$((RETRIES + 1))
        if [ "$RETRIES" -ge 60 ]; then
          echo "ERROR: SeaweedFS server not ready after 300s. Giving up."
          exit 1
        fi
        echo "SeaweedFS server not ready yet... (attempt $RETRIES/60)"
        sleep 5
      done

      echo -e "SeaweedFS server is ready.\n"

      echo "Waiting for SeaweedFS S3 API to be ready..."
      RETRIES=0
      until wget --timeout=3 --tries=1 -qO- $SEAWEEDFS_S3_ENDPOINT_STATUS_URL >/dev/null; do
        RETRIES=$((RETRIES + 1))
        if [ "$RETRIES" -ge 60 ]; then
          echo "ERROR: SeaweedFS S3 API not ready after 300s. Giving up."
          exit 1
        fi
        echo "S3 API not ready yet... (attempt $RETRIES/60)"
        sleep 5
      done

      echo -e "SeaweedFS S3 API is ready.\n"

      echo "Configuring SeaweedFS S3 credentials and buckets..."
      echo "s3.bucket.create -name=$S3_BUCKET_NAME" | weed shell -master=$SEAWEEDFS_MASTER_ENDPOINT || exit 1
      echo "s3.bucket.create -name=$CONNECTOR_SPEC_BUCKET_NAME" | weed shell -master=$SEAWEEDFS_MASTER_ENDPOINT || exit 1
      echo "s3.configure -apply -access_key=$S3_ACCESS_KEY -secret_key=$S3_SECRET_KEY -user=$S3_ACCESS_KEY -actions=Read,Write,List -buckets=$S3_BUCKET_NAME" | weed shell -master=$SEAWEEDFS_MASTER_ENDPOINT > /dev/null || exit 1
      echo "s3.configure -apply -access_key=$S3_ACCESS_KEY -secret_key=$S3_SECRET_KEY -user=$S3_ACCESS_KEY -actions=Read,Write,List,Tagging,Admin -buckets=$CONNECTOR_SPEC_BUCKET_NAME" | weed shell -master=$SEAWEEDFS_MASTER_ENDPOINT > /dev/null || exit 1
      echo "s3.configure -apply -user=anonymous -actions=Read,List -buckets=$CONNECTOR_SPEC_BUCKET_NAME" | weed shell -master=$SEAWEEDFS_MASTER_ENDPOINT > /dev/null || exit 1

      echo "SeaweedFS S3 setup completed successfully!"
{{- end }}
