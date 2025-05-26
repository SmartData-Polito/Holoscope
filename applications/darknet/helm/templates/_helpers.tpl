{{/*
Expand the name of the chart.
*/}}
{{- define "darknet.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "darknet.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "darknet.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "darknet.labels" -}}
helm.sh/chart: {{ include "darknet.chart" . }}
{{ include "darknet.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "darknet.selectorLabels" -}}
app.kubernetes.io/name: {{ include "darknet.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "darknet.capture.labels" -}}
{{ include "darknet.labels" . }}
app.kubernetes.io/component: capture
{{- end }}

{{- define "darknet.arp.labels" -}}
{{ include "darknet.labels" . }}
app.kubernetes.io/component: arp
{{- end }}

{{- define "darknet.collector.labels" -}}
{{ include "darknet.labels" . }}
app.kubernetes.io/component: collector
{{- end }}