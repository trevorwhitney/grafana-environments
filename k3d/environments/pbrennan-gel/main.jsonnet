local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local provisioner = import 'provisioner/provisioner.libsonnet';
local jaeger = import 'jaeger/jaeger.libsonnet';

local gelDistributed = import 'gel-distributed-openshift/main.libsonnet';
local grafana = import 'grafana-gel/grafana.libsonnet';
local prometheus = import 'prometheus/prometheus.libsonnet';
local promtail = import 'promtail/promtail.libsonnet';

gelDistributed + grafana + prometheus + promtail + jaeger + provisioner {
  local namespace = spec.namespace,
  //todo: parameterize this
  local registry = 'k3d-grafana:41139',
  local clusterName = 'enterprise-logs-test-fixture',
  local normalizedClusterName = std.strReplace(clusterName, '-', '_'),
  local gatewayName = self.gel['service_%s_gateway' % normalizedClusterName].metadata.name,
  local gatewayHost = '%s:3100' % gatewayName,
  local gatewayUrl = 'http://%s' % gatewayHost,
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
    analytics: {
      reporting_enabled: false,
    },
    common: {
      path_prefix: '/var/loki',
      ring: {
        kvstore: {
          store: 'memberlist',
        },
      },
      storage: {
        s3: {
          s3: 's3://enterprise-logs:supersecret@enterprise-logs-test-fixture-minio:9000/enterprise-logs-tsdb',
          //Must require endpoint since minio doesn't follow s3 standards
          endpoint: 'enterprise-logs-test-fixture-minio:9000',
          s3forcepathstyle: true,
          insecure: true,
        },
      },
    },
    license: {
      path: '/etc/enterprise-logs/license/license.jwt',
    },
    admin_client: {
      storage: {
        s3: {
          bucket_name: 'enterprise-logs-admin',
        },
      },
    },
    // todo: need this for the helm chart, but shouldn't
    compactor: {
      working_directory: '/data',
    },
    memberlist: {
      join_members: [
        '{{ include "loki.fullname" . }}-memberlist',
      ],
    },
    frontend: {
      tail_proxy_url: 'http://{{ include "loki.querierFullname" . }}:3100',
    },
    frontend_worker: {
      frontend_address: '{{ include "loki.queryFrontendFullname" . }}:9095',
    },
    ingester: {
      max_chunk_age: '2h',
    },
    querier: {
      query_ingesters_within: '2h',
    },
    ruler: {
      enable_sharding: true,
      storage: {
        s3: {
          bucketnames: 'enterprise-logs-ruler'
        },
      },
    },
    server: {
      http_listen_port: 3100,
      grpc_listen_port: 9095,
      log_level: 'debug',
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
      registry: $._config.registry,
      repository: 'enterprise-logs',
      tag: 'latest',
      pullPolicy: 'Always',
    },
  },

  _config+:: {
    registry: registry,
    clusterName: 'enterprise-logs-test-fixture',
    gatewayName: gatewayName,
    gatewayHost: gatewayHost,
    promtailLokiHost: gatewayHost,
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
}
