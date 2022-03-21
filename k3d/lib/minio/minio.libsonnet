local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet',
      helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};

{
  _config+:: {
    namespace: error 'must prvoide $._config.namespace',
    minio: {
      buckets: error 'must provide an array of minio buckets to create at $._config.minio.buckets',
      accessKey: 'minio',
      secretKey: 'supersecret',
    }
  },

  minio: helm.template('minio', '../../charts/minio', {
  namespace: $._config.namespace,
  values: {
    enabled: true,
    accessKey: $._config.minio.accessKey,
    secretKey: $._config.minio.secretKey,
    buckets: $._config.minio.buckets,
    persistence: {
      size: '5Gi',
    },
    resources: {
      requests: {
        cpu: '100m',
        memory: '128Mi',
      },
    },
  },
}),
}
