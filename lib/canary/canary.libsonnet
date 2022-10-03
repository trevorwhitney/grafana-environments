local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  _config+: {
    canary+: {
      lokiAddress: error 'must set lokiAddress',
    },
  },
  canary: helm.template('promtail', '../../charts/loki-canary', {
    namespace: $._config.namespace,
    values: {
      lokiAddress: $._config.canary.lokiAddress,
      serviceMonitor: {
        enabled: true,
        labels: { release: 'prometheus' },
      },
      extraArgs: [
        '-labelname=pod',
        '-labelvalue=$(POD_NAME)',
      ],
    },
  }),
}
