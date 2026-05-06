{{/*
Naming helpers with override support.

All helpers expect the root Helm context (.) unless noted otherwise.

sam.names.name            - Chart name, respects .Values.nameOverride
sam.names.fullname        - Release-qualified name, respects .Values.fullnameOverride
sam.names.chart           - Chart name + version for chart label
sam.names.namespace       - Release namespace
sam.names.component       - Expects (dict "root" . "component" "xxx")
sam.names.serviceAccount  - SA name with override support. Expects (dict "root" . "config" $cfg)
*/}}

{{/*
Expand the name of the chart.
Allows override via .Values.nameOverride.
*/}}
{{- define "sam.names.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
Truncated at 63 chars (DNS naming spec).
Priority: fullnameOverride > release-name (if it contains chart name) > release-chart.
*/}}
{{- define "sam.names.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version for the chart label.
*/}}
{{- define "sam.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Release namespace.
*/}}
{{- define "sam.names.namespace" -}}
{{- .Release.Namespace }}
{{- end }}

{{/*
Component-qualified name: {fullname}-{component}
Expects: (dict "root" . "component" "core")
*/}}
{{- define "sam.names.component" -}}
{{- printf "%s-%s" (include "sam.names.fullname" .root) .component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Service name.
Expects: (dict "root" . "config" $cfg)
  $cfg.name      — explicit override (custom service name)
  $cfg.component — used to auto-generate: {fullname}-{component}
*/}}
{{- define "sam.names.service" -}}
{{- if .config.name -}}
{{- .config.name -}}
{{- else -}}
{{- include "sam.names.component" (dict "root" .root "component" .config.component) -}}
{{- end -}}
{{- end }}

{{/*
ServiceAccount name.
Expects: (dict "root" . "config" $cfg)
  $cfg.serviceAccount.name — explicit override (use existing SA)
  $cfg.component           — used to auto-generate: {fullname}-{component}-sa
*/}}
{{- define "sam.names.serviceAccount" -}}
{{- if and .config.serviceAccount .config.serviceAccount.name -}}
{{- .config.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-sa" (include "sam.names.component" (dict "root" .root "component" .config.component)) -}}
{{- end -}}
{{- end }}

