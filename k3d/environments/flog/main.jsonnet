local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet',
      deployment = k.apps.v1.deployment,
      container = k.core.v1.container;

{
  deployment: deployment.new(name='flog', replicas=1, containers=[
    container.new('flog', 'mingrammer/flog')
    + container.withCommand([
      '/bin/flog',
      '-f',
      'json',
      '-l',
      '-s',
      '5s',
    ]),
  ]),

}
