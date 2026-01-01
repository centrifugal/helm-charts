{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "centrifugo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "centrifugo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "centrifugo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "centrifugo.labels" -}}
helm.sh/chart: {{ include "centrifugo.chart" . }}
{{ include "centrifugo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: centrifugo
app.kubernetes.io/component: server
{{- end }}

{{/*
Selector labels
*/}}
{{- define "centrifugo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "centrifugo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "centrifugo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "centrifugo.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "centrifugo.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{- define "centrifugo.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := coalesce .Values.image.tag (printf "v%s" .Chart.AppVersion ) | toString -}}
{{- if .Values.global -}}
    {{- if .Values.global.imageRegistry }}
        {{- printf "%s/%s:%s" .Values.global.imageRegistry $repositoryName $tag -}}
    {{- else -}}
        {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "centrifugo.imagePullSecrets" -}}
{{- if .Values.global }}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- else if .Values.imagePullSecrets}}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- else if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Worker deployment full name
Usage: {{ include "centrifugo.worker.fullname" (dict "root" . "worker" $worker) }}
*/}}
{{- define "centrifugo.worker.fullname" -}}
{{- printf "%s-%s" (include "centrifugo.fullname" .root) .worker.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Worker component label value
Usage: {{ include "centrifugo.worker.component" $worker }}
*/}}
{{- define "centrifugo.worker.component" -}}
{{- printf "worker-%s" .name -}}
{{- end -}}

{{/*
Worker selector labels (includes component for pod targeting)
Usage: {{ include "centrifugo.worker.selectorLabels" (dict "root" . "worker" $worker) }}
*/}}
{{- define "centrifugo.worker.selectorLabels" -}}
{{ include "centrifugo.selectorLabels" .root }}
app.kubernetes.io/component: {{ include "centrifugo.worker.component" .worker }}
{{- end -}}

{{/*
Worker labels (full set including version, managed-by, etc.)
Usage: {{ include "centrifugo.worker.labels" (dict "root" . "worker" $worker) }}
*/}}
{{- define "centrifugo.worker.labels" -}}
helm.sh/chart: {{ include "centrifugo.chart" .root }}
{{ include "centrifugo.worker.selectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: centrifugo
{{- end -}}

{{/*
Main deployment selector labels (includes component for pod targeting)
Usage: {{ include "centrifugo.main.selectorLabels" . }}
*/}}
{{- define "centrifugo.main.selectorLabels" -}}
{{ include "centrifugo.selectorLabels" . }}
app.kubernetes.io/component: server
{{- end -}}
