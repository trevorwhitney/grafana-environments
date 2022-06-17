local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};
{
  _config+:: {
    namespace: error 'plase prvoide $._config.namespace',
  },

  kubePrometheusStack: helm.template('prometheus', '../../charts/kube-prometheus-stack', {
    namespace: $._config.namespace,
    values+: {
      grafana+: {
        enabled: false,
      },
    },
    kubeVersion: 'v1.18.0',
    noHooks: false,
  }),
}
