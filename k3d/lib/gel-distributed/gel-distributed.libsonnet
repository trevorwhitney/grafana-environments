local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};
{
  local registry = 'k3d-grafana:45629',
  local prometheusAnnotations = { 'prometheus.io/scrape': 'true', 'prometheus.io/port': '3100' },
  local envVar = if std.objectHasAll(k.core.v1, 'envVar') then k.core.v1.envVar else k.core.v1.container.envType,

  _images+:: {
    gel: {
          registry: registry,
          repository: 'enterprise-logs',
          tag: 'latest',
          pullPolicy: 'Always',
        }
  },

  _config+:: {
    namespace: error 'please provide $._config.namespace',
    clusterName: error 'please provide $._config.clusterName',
    jaegerAgentName: error 'plase provide $._config.jaegerAgentName',
    gel: {
      common: {
        path_prefix: '/var/loki',
        replication_factor: 1,
        ring: {
          kvstore: {
            store: 'memberlist',
          },
        },
      },
      server: {
        log_level: 'debug',
      },
      ingester: {
        max_chunk_age: '2h',
        lifecycler: {
          ring: {
            replication_factor: 1,
          },
        },
      },
      frontend_worker: {
        parallelism: 2,
      },
      querier: {
        max_concurrent: 2,
        query_ingesters_within: '2h',
      },
      ruler: {
        enable_sharding: true,
      },
    },
  },

  local normalizedClusterName = std.strReplace($._config.clusterName, '-', '_'),
  local gatewayName = self.gel['service_%s_gateway' % normalizedClusterName].metadata.name,
  local gatewayUrl = 'http://%s:3100' % gatewayName,
  local addJaegerEnvVars(c) = c {
    env: [
      envVar.new('JAEGER_AGENT_HOST', $._config.jaegerAgentName),
      envVar.new('JAEGER_AGENT_PORT', '6831'),
      envVar.new('JAEGER_SAMPLER_TYPE', 'const'),
      envVar.new('JAEGER_SAMPLER_PARAM', '1'),
      envVar.new('JAEGER_TAGS', 'app=gel'),
    ],
  },

  gel:
    helm.template($._config.clusterName, '../../charts/enterprise-logs', {
      namespace: $._config.namespace,
      values: {
        image: $._images.gel,
        gateway: { extraArgs: { 'log.level': 'debug' } },
        license: {
          contents: importstr '../../secrets/gel.jwt',
        },
        tokengen: { enable: true },
        config: k.util.manifestYaml($._config.gel),
        'loki-distributed': {
          loki: {
            image: {
              registry: registry,
              repository: 'enterprise-logs',
              tag: 'latest',
              pullPolicy: 'Always',
            },
          },
          ingester: {
            replicas: 1,
            persistence: {
              enabled: true,
              storageClass: 'local-path',
            },
          },
        },
      },
      kubeVersion: 'v1.18.0',
      noHooks: false,
    }) + {
      ['deployment_%s_%s' % [normalizedClusterName, name]]+:
        k.apps.v1.deployment.mapContainers(addJaegerEnvVars) +
        k.apps.v1.deployment.spec.template.metadata.withAnnotations(prometheusAnnotations)
      for name in [
        'admin_api',
        'distributor',
        'gateway',
        'querier',
        'query_frontend',
        'ruler',
      ]
    } + {
      ['stateful_set_%s_%s' % [normalizedClusterName, name]]+:
        k.apps.v1.statefulSet.mapContainers(addJaegerEnvVars) +
        k.apps.v1.statefulSet.spec.template.metadata.withAnnotations(prometheusAnnotations)
      for name in [
        'compactor',
        'index_gateway',
        'ingester',
      ]
    },
}
