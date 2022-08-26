local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};
{
  _config+:: {
    namespace: error 'please provide $._config.namespace',
    promtail: {
      provisionerSecret: null,
      cloudLokiAddress: null,
      promtailLokiHost: error 'please provide $._config.promtailLokiHost',
    },
  },

  promtail: helm.template('promtail', '../../charts/promtail', {
    namespace: $._config.namespace,
    values: {
      extraArgs: ['--config.expand-env=true'],
      extraEnv: if $._config.promtail.provisionerSecret == null then [] else [{
        name: 'PROVISIONING_TOKEN_PROMTAIL_L',
        valueFrom: {
          secretKeyRef: { name: $._config.promtail.provisionerSecret, key: 'token-promtail-l' },
        },
      }],

      local lokiAddress = if $._config.promtail.provisionerSecret == null then
        'http://%s/loki/api/v1/push' else
        'http://team-l:${PROVISIONING_TOKEN_PROMTAIL_L}@%s/loki/api/v1/push',

      config: {
        clients: [
          {
            url: lokiAddress % $._config.promtail.promtailLokiHost,
          },
        ],
        snippets: if $._config.promtail.cloudLokiAddress == null then {} else {
          extraClientConfigs: [
            { url: $._config.promtail.cloudLokiAddress },
          ],
        },
      },
      initContainer: {
        enabled: true,
        fsInotifyMaxUserInstances: 256,
      },
    },
    kubeVersion: 'v1.18.0',
    noHooks: false,
  }),
}
