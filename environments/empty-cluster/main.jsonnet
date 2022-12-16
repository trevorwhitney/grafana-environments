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

minio + prometheus + jaeger {
  local namespace = spec.namespace,
  local jaegerQueryName = self.jaeger.query_service.metadata.name,
  local jaegerQueryUrl = 'http://%s.%s' % [jaegerQueryName, namespace],
  local jaegerAgentName = self.jaeger.agent_service.metadata.name,
  local prometheusServerName = self.kubePrometheusStack.service_prometheus_kube_prometheus_prometheus.metadata.name,
  local prometheusUrl = 'http://%s.%s.svc.cluster.local:9090' % [prometheusServerName, namespace],

  grafanaNamespace: k.core.v1.namespace.new('grafana'),
  lokiNamespace: k.core.v1.namespace.new('loki'),

  grafanaLicenseSecret: k.core.v1.secret.new('grafana-license', {}, type='Opaque')
                        + k.core.v1.secret.withStringData({
                          'license.jwt': importstr '../../secrets/grafana.jwt',
                        })
                        + k.core.v1.secret.metadata.withNamespace('grafana'),

  gelLicenseSecret: k.core.v1.secret.new('gel-license', {}, type='Opaque')
                        + k.core.v1.secret.withStringData({
                          'license.jwt': importstr '../../secrets/gel.jwt',
                        })
                        + k.core.v1.secret.metadata.withNamespace('loki'),

  _config+:: {
    registry: registry,
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
        {
          name: 'loki-admin',
          policy: 'none',
          purge: false,
        },
      ],
      accessKey: 'loki',
      secretKey: 'supersecret',
    },
  },
}
