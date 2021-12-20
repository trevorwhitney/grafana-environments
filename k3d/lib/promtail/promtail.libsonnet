local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};
{
  _config+:: {
    provisionerSecret: error 'please provide $._config.provisionerSecret',
    namespace: error 'please provide $._config.namespace',
    gatewayName: error 'please provide $._config.gatewayName',
  },

  promtail: helm.template('promtail', '../../charts/promtail', {
    namespace: $._config.namespace,
    values: {
      extraArgs: ['--config.expand-env=true'],
      extraEnv: [{
        name: 'PROVISIONING_TOKEN_PROMTAIL_L',
        valueFrom: {
          secretKeyRef: { name: $._config.provisionerSecret, key: 'token-promtail-l' },
        },
      }],

      config: {
        lokiAddress: 'http://team-l:${PROVISIONING_TOKEN_PROMTAIL_L}@%s:3100/loki/api/v1/push' % $._config.gatewayName,
      },
    },
    kubeVersion: 'v1.18.0',
    noHooks: false,
  }),
}
