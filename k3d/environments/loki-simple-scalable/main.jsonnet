local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local jaeger = import 'jaeger/jaeger.libsonnet';
local minio = import 'minio/minio.libsonnet';

local grafana = import 'grafana-loki/grafana.libsonnet';
local prometheus = import 'kube-prometheus-stack/kube-prometheus-stack.libsonnet';
local agentOperator = import 'agent-operator/agent-operator.libsonnet';

local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};

local clusterName = 'loki-simple-scalable';
local normalizedClusterName = std.strReplace(clusterName, '-', '_');
local registry = 'k3d-grafana:41139';

grafana + prometheus + agentOperator + jaeger + minio + {
  local gatewayName = self.loki.service_loki_gateway.metadata.name,
  local gatewayHost = '%s' % gatewayName,
  local gatewayUrl = 'http://%s' % gatewayHost,
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
    promtailLokiHost: gatewayHost,
    jaegerAgentName: jaegerAgentName,
    jaegerAgentPort: 6831,
    namespace: namespace,
    promtail+: {
      promtailLokiHost: gatewayHost,
    },

    grafana+: {
      dashboardsConfigMaps: [
        'loki-dashboards-1',
        'loki-dashboards-2',
      ],
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
        //TODO: should expose this via configmap
        {
          name: 'loki',
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
      ],
    },

    minio+: {
      accessKey: 'loki',
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
    },
  },

  loki: helm.template($._config.clusterName, '../../charts/loki-simple-scalable', {
    namespace: $._config.namespace,
    values: {
      loki+: {
        auth_enabled: false,
        image: {
          registry: $._config.registry,
          repository: 'loki',
          tag: 'latest',
          pullPolicy: 'Always',
        },
        storage: {
          bucketNames: {
            chunks: 'loki-data',
            ruler: 'loki-rules',
          },
          type: 's3',
          s3: {
            s3: 's3://loki:supersecret@minio:9000/loki-data',
            //Must require endpoint since minio doesn't follow s3 standards
            endpoint: 'minio:9000',
            s3ForcePathStyle: true,
            insecure: true,
          },
        },
      },
      monitoring: {
        serviceMonitor: {
          //TODO: this is required because of the service monitor selector match labels
          // from kube-prometheus-stack. Should we make this something loki specific?
          labels: { release: 'prometheus' },
        },
      },
    },
  }) + {
    ['stateful_set_loki_%s' % [name]]+:
      k.apps.v1.statefulSet.mapContainers($._addJaegerEnvVars)
    for name in [
      'read',
      'write',
    ]
  },
}
