{{/*
Expand the name of the chart.
*/}}
{{- define "cloud-native-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cloud-native-app.fullname" -}}
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
Chart label: chart name + version.
*/}}
{{- define "cloud-native-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "cloud-native-app.labels" -}}
helm.sh/chart: {{ include "cloud-native-app.chart" . }}
{{ include "cloud-native-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — keep these stable between upgrades.
*/}}
{{- define "cloud-native-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloud-native-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Backend-specific selector labels.
*/}}
{{- define "cloud-native-app.backendSelectorLabels" -}}
app: backend
app.kubernetes.io/name: {{ include "cloud-native-app.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Frontend-specific selector labels.
*/}}
{{- define "cloud-native-app.frontendSelectorLabels" -}}
app: frontend
app.kubernetes.io/name: {{ include "cloud-native-app.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Database-specific selector labels.
*/}}
{{- define "cloud-native-app.databaseSelectorLabels" -}}
app: postgres
app.kubernetes.io/name: {{ include "cloud-native-app.name" . }}-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

