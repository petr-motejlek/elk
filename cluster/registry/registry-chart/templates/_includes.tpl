{{- define "serviceName" -}}
    {{- .Values.serviceName -}}
{{- end -}}

{{- define "servicePort" -}}
    {{- .Values.servicePort -}}
{{- end -}}

{{- define "imageUrl" -}}
    {{- .Values.imageUrl -}}
{{- end -}}

{{- define "replicasCount" -}}
    1
{{- end -}}

{{- define "storageClassName" -}}
    {{- .Values.storageClassName -}}
{{- end -}}

{{- define "tlsKeyPem" -}}
    {{- .Values.tlsKeyPem | b64enc -}}
{{- end -}}

{{- define "tlsCrtPem" -}}
    {{- .Values.tlsCrtPem | b64enc -}}
{{- end -}}