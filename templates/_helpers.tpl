{{/*
aap-gateway.chart — chart label (name-version)
*/}}
{{- define "aap-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
aap-gateway.labels — standard Helm labels applied to all resources
*/}}
{{- define "aap-gateway.labels" -}}
helm.sh/chart: {{ include "aap-gateway.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
aap-gateway.resourceRequirements — builds a resource_requirements value dict.

Input: a map with shape {requests: {cpu, memory}, limits: {cpu, memory}}
Returns: serialized YAML of {requests: {...}, limits: {...}}, or empty string.
Usage in template:
  {{- $rr := include "aap-gateway.resourceRequirements" .Values.api.resource_requirements | fromYaml }}
  {{- if gt (len $rr) 0 }}{{- $_ := set $someDict "resource_requirements" $rr }}{{- end }}
*/}}
{{- define "aap-gateway.resourceRequirements" -}}
{{- $rr := . -}}
{{- if $rr -}}
{{- $req := dict -}}
{{- if dig "requests" "cpu" "" $rr -}}{{- $_ := set $req "cpu" (dig "requests" "cpu" "" $rr) -}}{{- end -}}
{{- if dig "requests" "memory" "" $rr -}}{{- $_ := set $req "memory" (dig "requests" "memory" "" $rr) -}}{{- end -}}
{{- $lim := dict -}}
{{- if dig "limits" "cpu" "" $rr -}}{{- $_ := set $lim "cpu" (dig "limits" "cpu" "" $rr) -}}{{- end -}}
{{- if dig "limits" "memory" "" $rr -}}{{- $_ := set $lim "memory" (dig "limits" "memory" "" $rr) -}}{{- end -}}
{{- $result := dict -}}
{{- if gt (len $req) 0 -}}{{- $_ := set $result "requests" $req -}}{{- end -}}
{{- if gt (len $lim) 0 -}}{{- $_ := set $result "limits" $lim -}}{{- end -}}
{{- if gt (len $result) 0 -}}{{- toYaml $result -}}{{- end -}}
{{- end -}}
{{- end }}

{{/*
aap-gateway.deepMerge — recursively merges src dict into dst dict in place.
When both dst and src have the same key and both values are maps, recurse.
Otherwise src value wins (shallow overwrite at that level).

Usage: {{- $_ := include "aap-gateway.deepMerge" (list $dst $src) | fromYaml }}
The return value can be discarded — dst is mutated in place as a side effect.
*/}}
{{- define "aap-gateway.deepMerge" -}}
{{- $dst := index . 0 -}}
{{- $src := index . 1 -}}
{{- range $k, $v := $src -}}
  {{- if and (hasKey $dst $k) (kindIs "map" $v) (kindIs "map" (index $dst $k)) -}}
    {{- $_ := set $dst $k (include "aap-gateway.deepMerge" (list (index $dst $k) $v) | fromYaml) -}}
  {{- else -}}
    {{- $_ := set $dst $k $v -}}
  {{- end -}}
{{- end -}}
{{- $dst | toYaml -}}
{{- end }}

{{/*
aap-gateway.storageRequirements — builds a storage_requirements value dict.

Input: a map with shape {requests: {storage}, limits: {storage}}
Returns: serialized YAML of {requests: {...}, limits: {...}}, or empty string.
Usage:
  {{- $sr := include "aap-gateway.storageRequirements" .Values.database.storage_requirements | fromYaml }}
  {{- if gt (len $sr) 0 }}{{- $_ := set $dbDict "storage_requirements" $sr }}{{- end }}
*/}}
{{- define "aap-gateway.storageRequirements" -}}
{{- $sr := . -}}
{{- if $sr -}}
{{- $req := dict -}}
{{- if dig "requests" "storage" "" $sr -}}{{- $_ := set $req "storage" (dig "requests" "storage" "" $sr) -}}{{- end -}}
{{- $lim := dict -}}
{{- if dig "limits" "storage" "" $sr -}}{{- $_ := set $lim "storage" (dig "limits" "storage" "" $sr) -}}{{- end -}}
{{- $result := dict -}}
{{- if gt (len $req) 0 -}}{{- $_ := set $result "requests" $req -}}{{- end -}}
{{- if gt (len $lim) 0 -}}{{- $_ := set $result "limits" $lim -}}{{- end -}}
{{- if gt (len $result) 0 -}}{{- toYaml $result -}}{{- end -}}
{{- end -}}
{{- end }}
