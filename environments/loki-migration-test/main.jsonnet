local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local jaeger = import 'jaeger/jaeger.libsonnet';
local minio = import 'minio/minio.libsonnet';

local grafana = import 'grafana-loki/grafana.libsonnet';
local prometheus = import 'kube-prometheus-stack/kube-prometheus-stack.libsonnet';


local promtail = import 'promtail/promtail.libsonnet';

local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};

local clusterName = 'loki-migration-test';
local normalizedClusterName = std.strReplace(clusterName, '-', '_');
local registry = 'k3d-grafana:41139';

minio + grafana + prometheus + jaeger + promtail {
  local lokiOld = helm.template($._config.clusterName, '../../charts/loki-old', {
    namespace: $._config.namespace,
    values: {
      tracing: {
        jaegerAgentHost: jaegerAgentName,
      },
      config+: {
        auth_enabled: false,
        server: {
          log_level: 'debug',
        },
      },
    },
  }),

  local lokiOldGatewayName = lokiOld['service_%s' % normalizedClusterName].metadata.name,

  local lokiNew = helm.template($._config.clusterName, '../../charts/loki', {
    namespace: $._config.namespace,
    values: {
      upgradeFromV2: true,
      loki+: {
        auth_enabled: false,
        commonConfig: {
          replication_factor: 1,
        },
        deploymentMode: 'single-binary',
        storage: {
          type: 'filesystem',
        },
      },
      monitoring: {
        dashboards: {
          enabled: false,
        },
        selfMonitoring: {
          enabled: false,
          grafanaAgent: {
            installOperator: false,
          },
        },
      },
    },
  }),
  local lokiNewGatewayName = lokiNew.service_loki.metadata.name,

  local useNewLoki = true,

  // local gatewayName = '%s' % if useNewLoki then lokiNewGatewayName else lokiOldGatewayName,
  local gatewayName = "loki-loki-distributed-gateway.loki.svc.cluster.local",
  local gatewayHost = '%s' % gatewayName,
  // local gatewayUrl = 'http://%s:3100' % gatewayHost,
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
    jaegerAgentName: jaegerAgentName,
    jaegerAgentPort: 6831,
    namespace: namespace,
    promtail+: {
      // promtailLokiHost: '%s:3100' % gatewayHost,
      promtailLokiHost: '%s' % gatewayHost,
    },

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
  },

  // loki: if useNewLoki then lokiNew else lokiOld,
}
