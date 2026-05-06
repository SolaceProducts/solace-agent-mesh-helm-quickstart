{{/*
Kubernetes API version detection helpers.

sam.capabilities.kubeVersion         - Cluster Kubernetes version
sam.capabilities.ingress.apiVersion  - Correct Ingress API version
sam.capabilities.hpa.apiVersion      - Correct HPA API version
sam.capabilities.policy.apiVersion   - Correct PodDisruptionBudget API version

All expect root Helm context (.).
*/}}

{{/*
Return the Kubernetes version.
*/}}
{{- define "sam.capabilities.kubeVersion" -}}
{{- default .Capabilities.KubeVersion.Version .Values.kubeVersionOverride }}
{{- end }}

{{/*
Ingress API version: networking.k8s.io/v1 for >= 1.19, extensions/v1beta1 otherwise.
*/}}
{{- define "sam.capabilities.ingress.apiVersion" -}}
{{- if semverCompare ">=1.19-0" (include "sam.capabilities.kubeVersion" .) }}
{{- print "networking.k8s.io/v1" }}
{{- else }}
{{- print "extensions/v1beta1" }}
{{- end }}
{{- end }}

{{/*
HPA API version: autoscaling/v2 for >= 1.23, autoscaling/v2beta2 otherwise.
*/}}
{{- define "sam.capabilities.hpa.apiVersion" -}}
{{- if semverCompare ">=1.23-0" (include "sam.capabilities.kubeVersion" .) }}
{{- print "autoscaling/v2" }}
{{- else }}
{{- print "autoscaling/v2beta2" }}
{{- end }}
{{- end }}

{{/*
PDB API version: policy/v1 for >= 1.21, policy/v1beta1 otherwise.
*/}}
{{- define "sam.capabilities.policy.apiVersion" -}}
{{- if semverCompare ">=1.21-0" (include "sam.capabilities.kubeVersion" .) }}
{{- print "policy/v1" }}
{{- else }}
{{- print "policy/v1beta1" }}
{{- end }}
{{- end }}
