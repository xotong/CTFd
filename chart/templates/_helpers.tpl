{{/*
Expand the name of the chart.
*/}}
{{- define "ctfd.name" -}}
{{- default .Chart.Name .Values.ctfd.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ctfd.fullname" -}}
{{- if .Values.ctfd.fullnameOverride }}
{{- .Values.ctfd.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.ctfd.nameOverride }}
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
{{- define "ctfd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ctfd.labels" -}}
helm.sh/chart: {{ include "ctfd.chart" . }}
{{ include "ctfd.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ctfd.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ctfd.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ctfd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ctfd.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
MariaDB fullname
*/}}
{{- define "ctfd.mariadb.fullname" -}}
{{- printf "%s-mariadb" (include "ctfd.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Redis fullname
*/}}
{{- define "ctfd.redis.fullname" -}}
{{- printf "%s-redis" (include "ctfd.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Nginx fullname
*/}}
{{- define "ctfd.nginx.fullname" -}}
{{- printf "%s-nginx" (include "ctfd.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get the MariaDB database URL
*/}}
{{- define "ctfd.databaseUrl" -}}
{{- if .Values.ctfd.env.databaseUrl }}
{{- .Values.ctfd.env.databaseUrl }}
{{- else if .Values.mariadb.enabled }}
{{- printf "mysql+pymysql://%s:%s@%s:%d/%s" .Values.mariadb.auth.username .Values.mariadb.auth.password (include "ctfd.mariadb.fullname" .) (.Values.mariadb.service.port | int) .Values.mariadb.auth.database }}
{{- else }}
{{- fail "Either ctfd.env.databaseUrl must be set or mariadb.enabled must be true" }}
{{- end }}
{{- end }}

{{/*
Get the Redis URL
*/}}
{{- define "ctfd.redisUrl" -}}
{{- if .Values.ctfd.env.redisUrl }}
{{- .Values.ctfd.env.redisUrl }}
{{- else if .Values.redis.enabled }}
{{- printf "redis://%s:%d" (include "ctfd.redis.fullname" .) (.Values.redis.service.port | int) }}
{{- else }}
{{- fail "Either ctfd.env.redisUrl must be set or redis.enabled must be true" }}
{{- end }}
{{- end }}

{{/*
Get the secret key
*/}}
{{- define "ctfd.secretKey" -}}
{{- if .Values.ctfd.env.secretKey }}
{{- .Values.ctfd.env.secretKey }}
{{- else }}
{{- randAlphaNum 64 }}
{{- end }}
{{- end }}

{{/*
MariaDB labels
*/}}
{{- define "ctfd.mariadb.labels" -}}
helm.sh/chart: {{ include "ctfd.chart" . }}
{{ include "ctfd.mariadb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: database
{{- end }}

{{/*
MariaDB selector labels
*/}}
{{- define "ctfd.mariadb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ctfd.name" . }}-mariadb
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Redis labels
*/}}
{{- define "ctfd.redis.labels" -}}
helm.sh/chart: {{ include "ctfd.chart" . }}
{{ include "ctfd.redis.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: cache
{{- end }}

{{/*
Redis selector labels
*/}}
{{- define "ctfd.redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ctfd.name" . }}-redis
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Nginx labels
*/}}
{{- define "ctfd.nginx.labels" -}}
helm.sh/chart: {{ include "ctfd.chart" . }}
{{ include "ctfd.nginx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: proxy
{{- end }}

{{/*
Nginx selector labels
*/}}
{{- define "ctfd.nginx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ctfd.name" . }}-nginx
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
