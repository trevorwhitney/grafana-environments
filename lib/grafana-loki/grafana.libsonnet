local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local spec = (import './spec.json').spec;
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};
{
  _config+:: {
    jaegerAgentName: error 'please provide $._config.jaegerAgentName',
    jaegerAgentPort: 6831,
    namespace: error 'plase provide $._config.namespace',
    provisioningDir: '/etc/grafana/provisioning',
    lokiUrl: error 'please provide $._config.lokiUrl',
    grafana+: {
      datasources: [],
      dashboardsConfigMaps: [],
      extraVolumeMounts: []
    },
  },

  _images+:: {
    grafana: {
      repository: 'grafana/grafana-enterprise',
      tag: '8.2.5',
      pullPolicy: 'IfNotPresent',
    },
  },

  grafana: helm.template('grafana', '../../charts/grafana', {
    namespace: $._config.namespace,
    values: {
      image: $._images.grafana,
      testFramework: {
        enabled: false,
      },
      serviceMonitor: {
        enabled: true,
      },
      env: {
        GF_AUTH_ANONYMOUS_ENABLED: true,
        GF_AUTH_ANONYMOUS_ORG_ROLE: 'Admin',
        GF_FEATURE_TOGGLES_ENABLE: 'ngalert',
        JAEGER_AGENT_PORT: 6831,
        JAEGER_AGENT_HOST: $._config.jaegerAgentName,
      },
      datasources: {
        'datasources.yaml': {
          apiVersion: 1,
          datasources: $._config.grafana.datasources,
        },
      },
      'grafana.ini': {
        'tracing.jaeger': {
          always_included_tag: 'app=grafana',
          sampler_type: 'const',
          sampler_param: 1,
        },
        paths: {
          provisioning: $._config.provisioningDir,
        },
      },
    } + if std.length($._config.grafana.dashboardsConfigMaps) > 0 then {
      dashboardProviders: {
        'loki.yaml': {
          apiVersion: 1,
          providers: std.map(function(provider) {
            name: provider,
            editable: true,
            options: {
              path: '/var/lib/grafana/dashboards/%s' % provider,
            },
          }, $._config.grafana.dashboardsConfigMaps),
        },
      },
      dashboardsConfigMaps: {
        [provider]: provider
        for provider in $._config.grafana.dashboardsConfigMaps
      },
    } else {},
    kubeVersion: 'v1.18.0',
    noHooks: false,
  }),
}
