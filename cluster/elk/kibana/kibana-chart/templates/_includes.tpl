{{- define "serviceName" -}}
    {{- .Values.serviceName -}}
{{- end -}}

{{- define "servicePort" -}}
    {{- .Values.servicePort -}}
{{- end -}}

{{- define "replicasCount" -}}
    1
{{- end -}}

{{- define "imageUrl" -}}
    {{- .Values.imageUrl -}}
{{- end -}}

{{- define "storageClassName" -}}
    {{- .Values.storageClassName -}}
{{- end -}}