local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local provisioner = import 'provisioner/provisioner.libsonnet';
local jaeger = import 'jaeger/jaeger.libsonnet';

local gelDistributed = import 'gel-distributed/gel-distributed.libsonnet';
local grafana = import 'grafana/grafana.libsonnet';
local prometheus = import 'prometheus/prometheus.libsonnet';
local promtail = import 'promtail/promtail.libsonnet';

gelDistributed + grafana + prometheus + promtail + jaeger + provisioner {
  local namespace = spec.namespace,
  local registry = 'k3d-grafana:45629',
  local clusterName = 'enterprise-logs-test-fixture',
  local normalizedClusterName = std.strReplace(clusterName, '-', '_'),
  local gatewayName = self.gel['service_%s_gateway' % normalizedClusterName].metadata.name,
  local gatewayUrl = 'http://%s:3100' % gatewayName,
  local jaegerQueryName = self.jaeger.query_service.metadata.name,
  local jaegerQueryUrl = 'http://%s' % jaegerQueryName,
  local jaegerAgentName = self.jaeger.agent_service.metadata.name,
  local jaegerAgentUrl = 'http://%s' % jaegerAgentName,
  local prometheusServerName = self.prometheus.service_prometheus_server.metadata.name,
  local prometheusUrl = 'http://%s' % prometheusServerName,
  local provisionerSecret = 'gel-provisioning-tokens',
  local prometheusAnnotations = { 'prometheus.io/scrape': 'true', 'prometheus.io/port': '3100' },
  local envVar = if std.objectHasAll(k.core.v1, 'envVar') then k.core.v1.envVar else k.core.v1.container.envType,
  local parseYaml = std.native('parseYaml'),

  gelConfig:: {
    common: {
      path_prefix: '/var/loki',
      replication_factor: 1,
      ring: {
        kvstore: {
          store: 'memberlist',
        },
      },
      storage: {
        s3: {
          s3: 's3://enterprise-logs:supersecret@enterprise-logs-test-fixture-minio.gel-distributed.svc:9000/enterprise-logs-admin',
          insecure: true,
        },
      },
    },
    memberlist: {
      join_members: [
        '{{ include "loki.fullname" . }}-memberlist',
      ],
    },
    frontend_worker: {
      parallelism: 2,
    },
    ingester: {
      // TODO: remove once this fix is in GEL
      lifecycler: {
        ring: {
          replication_factor: 1,
        },
      },
      max_chunk_age: '2h',
    },
    querier: {
      max_concurrent: 2,
      query_ingesters_within: '2h',
    },
    ruler: {
      enable_sharding: true,
      // TODO: remove this once the ring prefix bug is merged into GEL
      ring: {
        kvstore: {
          store: 'memberlist',
          prefix: 'ruler',
        },
      },
    },
    server: {
      http_listen_port: 3100,
      grpc_listen_port: 9095,
    },
    schema_config: {
      configs: [
        {
          from: '2021-01-01',
          store: 'boltdb-shipper',
          object_store: 's3',
          schema: 'v11',
          index: {
            prefix: 'index_',
            period: '24h',
          },
        },
      ],
    },
  },

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
    clusterName: 'enterprise-logs-test-fixture',
    gatewayName: gatewayName,
    gelUrl: gatewayUrl,
    jaegerAgentName: jaegerAgentName,
    jaegerAgentPort: 6831,
    namespace: namespace,
    provisionerSecret: provisionerSecret,
    adminToken: 'gel-admin-token',

    gel: $.gelConfig,

    grafana: {
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
        '-cluster-name=' + clusterName,
        '-cortex-url=' + gatewayUrl,
        '-token-file=/bootstrap/token',

        '-instance=team-l',

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
}
