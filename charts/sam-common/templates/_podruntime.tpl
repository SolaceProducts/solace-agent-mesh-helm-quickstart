{{/*
Resolve scheduling fields for a sandbox pod runtime profile.

Looks up an optional named profile in `global.podRuntimes` and emits
runtimeClassName, nodeSelector, and tolerations as a YAML fragment at
indentation 0. The caller supplies the desired indentation via nindent.

Profiles couple the three fields that always travel together for sandbox
runtimes (gVisor, Kata, Firecracker, etc.):
  global:
    podRuntimes:
      gvisor:
        runtimeClassName: gvisor
        nodeSelector: { runtime: gvisor }
        tolerations:
          - { key: sandbox, operator: Equal, value: gvisor, effect: NoSchedule }

The library ships no default profiles. Operators must define `global.podRuntimes`
explicitly. Two render-failure conditions guard against silently degrading to
the default runtime:
  - Referenced profile is not defined in global.podRuntimes
  - Referenced profile is defined but has an empty runtimeClassName
Either case defeats the security intent and so fails loudly with a clear error.

Args: (dict "root" . "config" $config)
config keys read:
  podRuntime       string  Optional  — name of a profile in global.podRuntimes
  nodeSelector     object  Optional  — explicit selectors, merged with profile
  tolerations      []obj   Optional  — explicit tolerations, concatenated with profile
  component        string  Optional  — used only for error messages

Merge rules:
  runtimeClassName  comes from the profile only (no direct cfg key)
  nodeSelector      profile keys win on collision; cfg keys add non-conflicting
  tolerations       profile entries first, cfg entries appended

Use:
  {{- with (include "sam.podRuntime.scheduling" (dict "root" $root "config" $cfg)) }}
  {{- . | nindent 6 }}
  {{- end }}
*/}}
{{- define "sam.podRuntime.scheduling" -}}
{{- $root := .root -}}
{{- $cfg := .config -}}
{{- $name := default "" $cfg.podRuntime -}}
{{- $profile := dict -}}
{{- if $name -}}
  {{- $global := default (dict) $root.Values.global -}}
  {{- $registry := default (dict) $global.podRuntimes -}}
  {{- $profile = index $registry $name -}}
  {{- if not $profile -}}
    {{- fail (printf "podRuntime %q referenced by component %q is not defined in global.podRuntimes" $name (default "<unknown>" $cfg.component)) -}}
  {{- end -}}
  {{- if not (default "" $profile.runtimeClassName) -}}
    {{- fail (printf "podRuntime %q referenced by component %q has no runtimeClassName set in global.podRuntimes.%s — a profile without a RuntimeClass would defeat the sandbox intent" $name (default "<unknown>" $cfg.component) $name) -}}
  {{- end -}}
{{- end -}}
{{- $runtimeClassName := default "" $profile.runtimeClassName -}}
{{- $cfgSelector := default (dict) $cfg.nodeSelector -}}
{{- $profileSelector := default (dict) $profile.nodeSelector -}}
{{- /* merge: dest wins on collision; deepCopy so we don't mutate the registry */ -}}
{{- $nodeSelector := merge (deepCopy $profileSelector) $cfgSelector -}}
{{- $tolerations := concat (default (list) $profile.tolerations) (default (list) $cfg.tolerations) -}}
{{- $parts := list -}}
{{- if $runtimeClassName -}}
  {{- $parts = append $parts (printf "runtimeClassName: %q" $runtimeClassName) -}}
{{- end -}}
{{- if $nodeSelector -}}
  {{- $parts = append $parts (printf "nodeSelector:\n%s" (toYaml $nodeSelector | indent 2 | trimSuffix "\n")) -}}
{{- end -}}
{{- if $tolerations -}}
  {{- $parts = append $parts (printf "tolerations:\n%s" (toYaml $tolerations | indent 2 | trimSuffix "\n")) -}}
{{- end -}}
{{- join "\n" $parts -}}
{{- end -}}
