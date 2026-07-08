{{/*
solace-agent-mesh.validations.all

Template-time cluster-resource existence checks. Encodes the feature-toggle → required-
resources contract: for each feature the user enabled, verify every referenced Secret /
ConfigMap / StorageClass / IngressClass exists in the target cluster. Fails fast at
`helm install`/`upgrade` instead of letting the deployment proceed into ImagePullBackOff,
CreateContainerConfigError, or a PVC stuck Pending on a missing StorageClass.

Input validation (shape, enums, required fields, mutual exclusion) lives in
values.schema.json — this helper only checks cluster-resource existence.

Pattern: per-kind sub-checks RETURN message strings (from sam.validations.*Exist).
This aggregator joins them and calls a single fail when any are non-empty, so the user
sees every missing resource across all kinds in one error.

No-op during `helm template` / `--dry-run=client` (namespace probe returns empty).

Gated by .Values.validations.clusterResourceChecks (default true) — operators whose
helm-install identity lacks `get` RBAC on these kinds can disable with --set
validations.clusterResourceChecks=false to bypass the lookup entirely.

Consumer: include once near the top of a template that always renders (deployment_core.yaml).
*/}}
{{- define "solace-agent-mesh.validations.all" -}}
{{- $key := .Values.global.imagePullKey | trim -}}
{{- if and $key (gt (len .Values.global.imagePullSecrets) 0) -}}
{{- fail "global.imagePullKey and global.imagePullSecrets are mutually exclusive. Use imagePullKey to let the chart manage the pull secret, or imagePullSecrets to reference a pre-created one — not both." -}}
{{- end -}}
{{- if $key -}}
{{- $parsed := $key | fromJson -}}
{{- if or (not (kindIs "map" $parsed)) (hasKey $parsed "Error") -}}
{{- fail "global.imagePullKey must be a valid JSON object with a \".dockerconfigjson\" field" -}}
{{- end -}}
{{- if not (hasKey $parsed ".dockerconfigjson") -}}
{{- fail "global.imagePullKey must contain a \".dockerconfigjson\" field" -}}
{{- end -}}
{{- if not (get $parsed ".dockerconfigjson") -}}
{{- fail "global.imagePullKey \".dockerconfigjson\" must be non-empty" -}}
{{- end -}}
{{- end -}}
{{- if .Values.validations.clusterResourceChecks -}}
{{- /* Cluster-reachability probe. Short-circuits during helm template / --dry-run=client
       (probe returns empty) so the downstream per-ref GETs never misfire. */ -}}
{{- $probe := lookup "v1" "Namespace" "" .Release.Namespace -}}
{{- if $probe -}}
{{- $root := . -}}

{{- /* ---- Secrets ---- */ -}}
{{- $secretRefs := list -}}
{{- if and (hasKey .Values "service") (hasKey .Values.service "tls") -}}
  {{- if and .Values.service.tls.enabled .Values.service.tls.existingSecret -}}
    {{- $secretRefs = append $secretRefs (dict "name" .Values.service.tls.existingSecret "context" "service.tls.existingSecret") -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.ingress.enabled .Values.ingress.tls -}}
  {{- range $i, $t := .Values.ingress.tls -}}
    {{- if $t.secretName -}}
      {{- $secretRefs = append $secretRefs (dict "name" $t.secretName "context" (printf "ingress.tls[%d].secretName" $i)) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $i, $v := .Values.extraSecretEnvironmentVars -}}
  {{- if $v.secretName -}}
    {{- $secretRefs = append $secretRefs (dict "name" $v.secretName "context" (printf "extraSecretEnvironmentVars[%d].secretName" $i)) -}}
  {{- end -}}
{{- end -}}
{{- range $i, $s := .Values.global.imagePullSecrets -}}
  {{- if $s -}}
    {{- $secretRefs = append $secretRefs (dict "name" $s "context" (printf "global.imagePullSecrets[%d]" $i)) -}}
  {{- end -}}
{{- end -}}
{{- if .Values.samDeployment.imagePullSecret -}}
  {{- $secretRefs = append $secretRefs (dict "name" .Values.samDeployment.imagePullSecret "context" "samDeployment.imagePullSecret") -}}
{{- end -}}
{{- if .Values.global.broker.embedded -}}
  {{- range $i, $s := .Values.embeddedBroker.imagePullSecrets -}}
    {{- if $s -}}
      {{- $secretRefs = append $secretRefs (dict "name" $s "context" (printf "embeddedBroker.imagePullSecrets[%d]" $i)) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if .Values.global.persistence.enabled -}}
  {{- $pl := index .Values "persistence-layer" -}}
  {{- if $pl -}}
    {{- if $pl.postgresql -}}
      {{- range $i, $s := $pl.postgresql.imagePullSecrets -}}
        {{- if $s -}}
          {{- $secretRefs = append $secretRefs (dict "name" $s "context" (printf "persistence-layer.postgresql.imagePullSecrets[%d]" $i)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- if $pl.seaweedfs -}}
      {{- range $i, $s := $pl.seaweedfs.imagePullSecrets -}}
        {{- if $s -}}
          {{- $secretRefs = append $secretRefs (dict "name" $s "context" (printf "persistence-layer.seaweedfs.imagePullSecrets[%d]" $i)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* ---- ConfigMaps ---- */ -}}
{{- $cmRefs := list -}}
{{- if .Values.samDeployment.customCA.enabled -}}
  {{- $cmName := .Values.samDeployment.customCA.configMapName | default "truststore" -}}
  {{- $cmRefs = append $cmRefs (dict "name" $cmName "context" "samDeployment.customCA.configMapName") -}}
{{- end -}}

{{- /* ---- StorageClasses ---- */ -}}
{{- $scRefs := list -}}
{{- if and .Values.global.broker.embedded .Values.embeddedBroker.storageClassName -}}
  {{- $scRefs = append $scRefs (dict "name" .Values.embeddedBroker.storageClassName "context" "embeddedBroker.storageClassName") -}}
{{- end -}}
{{- if .Values.global.persistence.enabled -}}
  {{- $pl := index .Values "persistence-layer" -}}
  {{- if $pl -}}
    {{- if and $pl.postgresql $pl.postgresql.persistence -}}
      {{- with $pl.postgresql.persistence.storageClassName -}}
        {{- $scRefs = append $scRefs (dict "name" . "context" "persistence-layer.postgresql.persistence.storageClassName") -}}
      {{- end -}}
    {{- end -}}
    {{- if and $pl.seaweedfs $pl.seaweedfs.persistence -}}
      {{- with $pl.seaweedfs.persistence.storageClassName -}}
        {{- $scRefs = append $scRefs (dict "name" . "context" "persistence-layer.seaweedfs.persistence.storageClassName") -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* ---- IngressClasses ---- */ -}}
{{- $icRefs := list -}}
{{- if and .Values.ingress.enabled .Values.ingress.className -}}
  {{- $icRefs = append $icRefs (dict "name" .Values.ingress.className "context" "ingress.className") -}}
{{- end -}}

{{- /* ---- Collect messages and fail once ---- */ -}}
{{- $messages := list -}}
{{- if $secretRefs -}}
  {{- $m := include "sam.validations.secretsExist" (dict "root" $root "refs" $secretRefs) -}}
  {{- if $m }}{{- $messages = append $messages $m -}}{{- end -}}
{{- end -}}
{{- if $cmRefs -}}
  {{- $m := include "sam.validations.configMapsExist" (dict "root" $root "refs" $cmRefs) -}}
  {{- if $m }}{{- $messages = append $messages $m -}}{{- end -}}
{{- end -}}
{{- if $scRefs -}}
  {{- $m := include "sam.validations.storageClassesExist" (dict "root" $root "refs" $scRefs) -}}
  {{- if $m }}{{- $messages = append $messages $m -}}{{- end -}}
{{- end -}}
{{- if $icRefs -}}
  {{- $m := include "sam.validations.ingressClassesExist" (dict "root" $root "refs" $icRefs) -}}
  {{- if $m }}{{- $messages = append $messages $m -}}{{- end -}}
{{- end -}}
{{- if $messages -}}
  {{- fail (printf "\nVALUES VALIDATION FAILED:\n%s\n\nCreate the missing cluster resources before installing/upgrading." (join "\n" $messages)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
