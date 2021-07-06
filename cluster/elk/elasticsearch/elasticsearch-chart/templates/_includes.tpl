{{- define "serviceName" -}}
    {{- .Values.serviceName -}}
{{- end -}}

{{- define "servicePort" -}}
    {{- .Values.servicePort -}}
{{- end -}}

{{- define "replicasCount" -}}
    {{- .Values.replicasCount -}}
{{- end -}}

{{- define "initialMasterNodes" -}}
    elasticsearch-0,elasticsearch-1,elasticsearch-2
{{- end -}}

{{- define "imageUrl" -}}
    {{- .Values.imageUrl -}}
{{- end -}}

{{- define "storageClassName" -}}
    {{- .Values.storageClassName -}}
{{- end -}}