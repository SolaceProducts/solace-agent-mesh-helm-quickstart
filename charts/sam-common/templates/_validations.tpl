{{/*
Validation helpers.

Input validation (calls fail directly):
  sam.validations.required      - Fail if a value is empty/nil.
  sam.validations.requiredOneOf - Fail if none of the given values are set.

Cluster-resource existence (lookup-based, RETURN error strings — consumer aggregates and fails once):
  sam.validations.resourcesExist      - Generic primitive.
  sam.validations.secretsExist        - v1 Secret (namespaced).
  sam.validations.configMapsExist     - v1 ConfigMap (namespaced).
  sam.validations.storageClassesExist - storage.k8s.io/v1 StorageClass (cluster-scoped).
  sam.validations.ingressClassesExist - networking.k8s.io/v1 IngressClass (cluster-scoped).

Existence helpers assume the consumer has already verified cluster reachability (e.g. a
release-namespace probe in the aggregator). These primitives call GET per ref, and GET
returns `{}` in both template mode and on a genuine 404 — so without an upstream probe
they cannot distinguish "no cluster" from "resource not found". The consumer aggregator
owns that gate; the library stays pure.
*/}}

{{/*
Fail if a required value is missing.
Expects: (dict "value" $val "field" "path.to.field" "context" "template name")
*/}}
{{- define "sam.validations.required" -}}
{{- if not .value }}
{{- fail (printf "[%s] %s is required but was empty" .context .field) }}
{{- end }}
{{- end }}

{{/*
Fail if none of the provided values are set (at least one required).
Expects: (dict "values" (list $a $b) "fields" "field1 or field2" "context" "template name")
*/}}
{{- define "sam.validations.requiredOneOf" -}}
{{- $found := false -}}
{{- range .values }}
{{- if . }}
{{- $found = true }}
{{- end }}
{{- end }}
{{- if not $found }}
{{- fail (printf "[%s] one of %s is required but all were empty" .context .fields) }}
{{- end }}
{{- end }}

{{/*
Generic cluster-resource existence check using per-ref GET.

Must be called only after the consumer has verified cluster reachability.
If called during `helm template` / `--dry-run=client`, every ref will be reported
as missing because GET-by-name returns `{}` with no cluster contact.

Expects:
  (dict "apiVersion" "v1"
        "kind"       "Secret"
        "namespace"  "<release-ns>"  ; empty string for cluster-scoped kinds
        "refs"       (list (dict "name" "foo" "context" "values.path[0]") ...))

Returns: "" on success, or "\nMissing <Kind>s:\n  - [ctx] <Kind> 'name' not found\n..."
*/}}
{{- define "sam.validations.resourcesExist" -}}
{{- $missing := list -}}
{{- range .refs -}}
  {{- $obj := lookup $.apiVersion $.kind $.namespace .name -}}
  {{- if not $obj -}}
    {{- $missing = append $missing (printf "  - [%s] %s '%s' not found" .context $.kind .name) -}}
  {{- end -}}
{{- end -}}
{{- if $missing -}}
  {{- $plural := ternary (printf "%ses" .kind) (printf "%ss" .kind) (hasSuffix "s" .kind) -}}
{{ printf "\nMissing %s:\n%s" $plural (join "\n" $missing) }}
{{- end -}}
{{- end -}}

{{/*
Thin wrappers. Each expects: (dict "root" $ "refs" <refs-list>).
*/}}

{{- define "sam.validations.secretsExist" -}}
{{- include "sam.validations.resourcesExist" (dict "apiVersion" "v1" "kind" "Secret" "namespace" .root.Release.Namespace "refs" .refs) -}}
{{- end -}}

{{- define "sam.validations.configMapsExist" -}}
{{- include "sam.validations.resourcesExist" (dict "apiVersion" "v1" "kind" "ConfigMap" "namespace" .root.Release.Namespace "refs" .refs) -}}
{{- end -}}

{{- define "sam.validations.storageClassesExist" -}}
{{- include "sam.validations.resourcesExist" (dict "apiVersion" "storage.k8s.io/v1" "kind" "StorageClass" "namespace" "" "refs" .refs) -}}
{{- end -}}

{{- define "sam.validations.ingressClassesExist" -}}
{{- include "sam.validations.resourcesExist" (dict "apiVersion" "networking.k8s.io/v1" "kind" "IngressClass" "namespace" "" "refs" .refs) -}}
{{- end -}}
