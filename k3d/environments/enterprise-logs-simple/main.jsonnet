local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local jaeger = import 'jaeger/jaeger.libsonnet';

local secrets = import '../secrets/secrets.json';

local grafana = import 'grafana-gel/grafana.libsonnet';
local prometheus = import 'prometheus/prometheus.libsonnet';
local promtail = import 'promtail/promtail.libsonnet';
local provisioner = import 'provisioner/provisioner.libsonnet';

local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};

local clusterName = 'enterprise-logs-simple';
local licenseClusterName = 'enterprise-logs-test-fixture';
local normalizedClusterName = std.strReplace(clusterName, '-', '_');
local registry = 'k3d-grafana:41139';

grafana + prometheus + promtail + jaeger + provisioner + {
  local gatewayName = self.enterprise_logs_simple["service_%s_gateway" % normalizedClusterName].metadata.name,
  // local gatewayName = '%s-gateway' % clusterName,
  local gatewayHost = '%s' % gatewayName,
  local gatewayUrl = 'http://%s' % gatewayHost,
  local jaegerQueryName = self.jaeger.query_service.metadata.name,
  local jaegerQueryUrl = 'http://%s' % jaegerQueryName,
  local jaegerAgentName = self.jaeger.agent_service.metadata.name,
  local jaegerAgentUrl = 'http://%s' % jaegerAgentName,
  local prometheusServerName = self.prometheus.service_prometheus_server.metadata.name,
  local prometheusUrl = 'http://%s' % prometheusServerName,
  local namespace = spec.namespace,
  local provisionerSecret = 'gel-provisioning-tokens',

  _images+: {
    provisioner: '%s/enterprise-metrics-provisioner' % registry,
    gel: {
      registry: registry,
      repository: 'enterprise-logs',
      tag: 'latest',
      pullPolicy: 'Always',
    },
  },

  _config+:: {
    registry: registry,
    clusterName: clusterName,
    gatewayName: gatewayName,
    gatewayHost: gatewayHost,
    gelUrl: gatewayUrl,
    jaegerAgentName: jaegerAgentName,
    jaegerAgentPort: 6831,
    promtail: {
      cloudLokiAddress: 'https://%s:%s@%s/loki/api/v1/push' % [secrets.cloud.user, secrets.cloud.token, secrets.cloud.host],
      promtailLokiHost: gatewayHost,
      provisionerSecret: provisionerSecret,
    },
    adminToken: 'gel-admin-token',
    namespace: namespace,

    grafana+: {
      provisionerSecret: provisionerSecret,
      datasources: [
        {
          name: 'Prometheus',
          type: 'prometheus',
          access: 'proxy',
          url: prometheusUrl,
        },
        {
          name: 'Jaeger',
          type: 'jaeger',
          access: 'proxy',
          url: jaegerQueryUrl,
          uid: 'jaeger_uid',
        },
        {
          name: 'GEL',
          type: 'loki',
          access: 'proxy',
          url: gatewayUrl,
          basicAuth: true,
          basicAuthUser: 'team-l',
          secureJsonData: {
            basicAuthPassword: '${PROVISIONING_TOKEN_GRAFANA_L}',
          },
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
    provisioner: {
      initCommand: [
        '/usr/bin/enterprise-metrics-provisioner',

        '-bootstrap-path=/shared',
        '-cluster-name=' + licenseClusterName,
        '-cortex-url=' + gatewayUrl,
        '-token-file=/bootstrap/token',

        '-tenant=team-l',

        '-access-policy=promtail-l:team-l:logs:write',
        '-access-policy=grafana-l:team-l:logs:read',

        '-token=promtail-l',
        '-token=grafana-l',
      ],
      containerCommand: [
        'bash',
        '-c',
        'kubectl create secret generic '
        + provisionerSecret
        + ' --from-literal=token-promtail-l="$(cat /shared/token-promtail-l)"'
        + ' --from-literal=token-grafana-l="$(cat /shared/token-grafana-l)" ',
      ],
    },
  },

  enterprise_logs_simple: helm.template($._config.clusterName, '../../charts/enterprise-logs-simple', {
    namespace: $._config.namespace,
    values: {
      license: {
        contents: importstr '../../secrets/gel.jwt',
      },
      image: $._images.gel,
      tokengen: {
        adminTokenSecret: $._config.adminToken,
        extraArgs: ['-cluster-name=%s' % licenseClusterName],
      },
      'loki-simple-scalable'+: {
        loki+: {
          image: {
            registry: registry,
            repository: 'enterprise-logs',
            tag: 'latest',
            pullPolicy: 'Always',
          },
        },
        read: {
          extraArgs: [
            '-cluster-name=%s' % licenseClusterName,
            '-log.level=debug',
            '-print-config-stderr',
          ],
          persistence: {
            storageClass: 'local-path',
          },
        },
        write: {
          extraArgs: ['-cluster-name=%s' % licenseClusterName],
          persistence: {
            storageClass: 'local-path',
          },
        },
      },
    },
  }) + {
    ['stateful_set_%s_%s' % [normalizedClusterName, name]]+:
      k.apps.v1.statefulSet.mapContainers($._addJaegerEnvVars) +
      k.apps.v1.statefulSet.spec.template.metadata.withAnnotations($._prometheusAnnotations)
    for name in [
      'read',
      'write',
    ]
  },
}
