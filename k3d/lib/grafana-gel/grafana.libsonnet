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
    gelUrl: error 'please provide $._config.gelUrl',
    grafana: {
      datasources: [],
      provisionerSecret: error 'please provide $._config.provisionerSecret',
    },
  },

  _images+:: {
    grafana: {
      repository: 'grafana/grafana-enterprise',
      tag: '8.2.5',
      pullPolicy: 'IfNotPresent',
    },
  },

  local configMap = k.core.v1.configMap,
  pluginsConfigMap+:
    configMap.new('grafana-plugins') +
    configMap.withDataMixin({
      'grafana-enterprise-logs.yml': std.manifestYamlDoc({
        apiVersion: 1,
        apps: [{
          type: 'grafana-enterprise-logs-app',
          jsonData: {
            backendUrl: $._config.gelUrl,
            base64EncodedAccessTokenSet: true,
          },
          secureJsonData: {
            base64EncodedAccessToken: '${GEL_ADMIN_TOKEN}',
          },
        }],
      }),
    }),

  grafana: helm.template('grafana', '../../charts/grafana', {
    namespace: $._config.namespace,
    values: {
      image: $._images.grafana,
      testFramework: {
        enabled: false,
      },
      env: {
        GF_AUTH_ANONYMOUS_ENABLED: true,
        GF_AUTH_ANONYMOUS_ORG_ROLE: 'Admin',
        GF_FEATURE_TOGGLES_ENABLE: 'ngalert',
        JAEGER_AGENT_PORT: 6831,
        JAEGER_AGENT_HOST: $._config.jaegerAgentName,
      },
      podAnnotations: {
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '3000',
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
        enterprise: {
          license_text: importstr '../../secrets/grafana.jwt',
        },
        paths: {
          provisioning: $._config.provisioningDir,
        },
      },
      plugins: [
        'https://storage.googleapis.com/plugins-community/grafana-enterprise-logs-app/release/2.3.0/grafana-enterprise-logs-app-2.3.0.zip;grafana-enterprise-logs-app',
      ],
    },
    kubeVersion: 'v1.18.0',
    noHooks: false,
  }) + {
    local addEnvVars(c) =
      c +
      k.core.v1.container.withEnvMixin([
        {
          name: 'GEL_ADMIN_TOKEN',
          valueFrom: {
            secretKeyRef: { name: 'gel-admin-token', key: 'grafana-token' },
          },
        },
        {
          name: 'PROVISIONING_TOKEN_GRAFANA_L',
          valueFrom: {
            secretKeyRef: { name: $._config.grafana.provisionerSecret, key: 'token-grafana-l' },
          },
        },
      ]),
    deployment_grafana+:
      k.apps.v1.deployment.mapContainers(addEnvVars) +
      k.util.configVolumeMount($.pluginsConfigMap.metadata.name, $._config.provisioningDir + '/plugins'),
  },

}
