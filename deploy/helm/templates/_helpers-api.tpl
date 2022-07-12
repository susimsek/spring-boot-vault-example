{{- define "myapp.selectorLabels" -}}
app: {{ template "app.shortname" . }}-myapp
release: {{ .Release.Name }}
{{- end }}

{{- define "myapp.labels" -}}
chart: {{ include "app.chart" . }}
{{ include "myapp.selectorLabels" . }}
heritage: {{ .Release.Service }}
app: {{ template "app.shortname" . }}-myapp
{{- end }}