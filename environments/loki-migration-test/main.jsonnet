local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local jaeger = import 'jaeger/jaeger.libsonnet';
local minio = import 'minio/minio.libsonnet';

local grafana = import 'grafana-loki/grafana.libsonnet';
local prometheus = import 'kube-prometheus-stack/kube-prometheus-stack.libsonnet';

local promtail = import 'promtail/promtail.libsonnet';
local canary = import 'canary/canary.libsonnet';

local helm = tanka.helm.new(std.thisFile);
local clusterName = 'loki-migration-test';
local normalizedClusterName = std.strReplace(clusterName, '-', '_');
local registry = 'k3d-grafana:41139';

minio + grafana + prometheus + jaeger {
  local gatewayName = 'loki-loki-distributed-gateway.loki.svc.cluster.local',
  local newGatewayName = 'loki-loki-distributed-gateway.loki.svc.cluster.local',
  local gatewayHost = '%s' % gatewayName,
  local newGatewayHost = '%s' % newGatewayName,
  local gatewayUrl = 'http://%s' % gatewayHost,
  local newGatewayUrl = 'http://%s' % newGatewayHost,
  local jaegerQueryName = self.jaeger.query_service.metadata.name,
  local jaegerQueryUrl = 'http://%s' % jaegerQueryName,
  local jaegerAgentName = self.jaeger.agent_service.metadata.name,
  local jaegerAgentUrl = 'http://%s' % jaegerAgentName,
  local prometheusServerName = self.kubePrometheusStack.service_prometheus_kube_prometheus_prometheus.metadata.name,
  local prometheusUrl = 'http://%s:9090' % prometheusServerName,
  local agentOperatorSA = self.agentOperator.service_account_agent_operator_grafana_agent_operator.metadata.name,
  local namespace = spec.namespace,

  _config+:: {
    registry: registry,
    clusterName: clusterName,
    gatewayName: gatewayName,
    gatewayHost: gatewayHost,
    jaegerAgentName: jaegerAgentName,
    jaegerAgentPort: 6831,
    namespace: namespace,
    minio: {
      buckets: [
        {
          name: 'loki-data',
          policy: 'none',
          purge: false,
        },
        {
          name: 'loki-rules',
          policy: 'none',
          purge: false,
        },
      ],
      accessKey: 'loki',
      secretKey: 'supersecret',
    },

    grafana+: {
      datasources: [
        {
          name: 'prometheus',
          type: 'prometheus',
          access: 'proxy',
          url: prometheusUrl,
        },
        {
          name: 'jaeger',
          type: 'jaeger',
          access: 'proxy',
          url: jaegerQueryUrl,
          uid: 'jaeger_uid',
        },
        {
          name: 'loki-old',
          type: 'loki',
          access: 'proxy',
          url: gatewayUrl,
          jsonData: {
            derivedFields: [
              {
                datasourceUid: 'jaeger_uid',
                matcherRegex: 'traceID=(\\w+)',
                name: 'TraceID',
                url: '$${__value.raw}',
              },
            ],
          },
        },
        {
          name: 'loki-new-no-auth',
          type: 'loki',
          access: 'proxy',
          url: 'http://loki-gateway.loki.svc.cluster.local',
          jsonData: {
            derivedFields: [
              {
                datasourceUid: 'jaeger_uid',
                matcherRegex: 'traceID=(\\w+)',
                name: 'TraceID',
                url: '$${__value.raw}',
              },
            ],
          },
        },
        {
          name: 'loki-new-auth',
          type: 'loki',
          access: 'proxy',
          url: 'http://loki-gateway.loki.svc.cluster.local',
          jsonData: {
            httpHeaderName1: 'X-Scope-OrgID',
            derivedFields: [
              {
                datasourceUid: 'jaeger_uid',
                matcherRegex: 'traceID=(\\w+)',
                name: 'TraceID',
                url: '$${__value.raw}',
              },
            ],
          },
          secureJsonData: {
            httpHeaderValue1: 'self-monitoring',
          },
        },
      ],
      // dashboardsConfigMaps: [
      //   'foo',
      // ],
    },
  },
}
