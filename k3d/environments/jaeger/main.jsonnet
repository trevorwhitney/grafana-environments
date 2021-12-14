local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
{
  local deployment = k.apps.v1.deployment,
  local container = k.core.v1.container,
  local port = k.core.v1.containerPort,
  local service = k.core.v1.service,
  local servicePort = k.core.v1.servicePort,
  local envVar = if std.objectHasAll(k.core.v1, 'envVar') then k.core.v1.envVar else k.core.v1.container.envType,

  _agentPort:: 6831,
  _queryPort:: 16686,
  _queryGrpcPort:: 16685,
  _agentConfigsPort:: 5778,
  _collectorZipkinHttpPort:: 9411,

  _deployment:: deployment.new(name='jaeger', replicas=1, containers=[
    container.new('jaeger', 'jaegertracing/all-in-one')
    + container.withPorts([
      port.newNamed($._queryGrpcPort, 'query-grpc'),
      port.newNamed($._agentConfigsPort, 'agent-configs'),
      port.newNamed($._collectorZipkinHttpPort, 'zipkin'),
      port.newNamed($._queryPort, 'query'),
      port.newNamedUDP($._agentPort, 'agent'),
      port.newNamedUDP(5775, 'zipkin-thrift'),
      port.newNamedUDP(6832, 'jaeger-thrift'),
    ]) +
    container.withEnv([
      envVar.new('COLLECTOR_ZIPKIN_HTTP_PORT', '%d' % [$._collectorZipkinHttpPort]),
      envVar.new('JAEGER_AGENT_HOST', 'jaeger-agent.jaeger.svc.cluster.local'),
      envVar.new('JAEGER_AGENT_PORT', '%d' % [$._agentPort]),
    ]) + container.mixin.readinessProbe.httpGet.withPath('/')
    + container.mixin.readinessProbe.httpGet.withPort(14269)
    + container.mixin.readinessProbe.withInitialDelaySeconds(5),
  ]),

  jaeger: {
    deployment: $._deployment,

    query_service: service.new('jaeger-query', {
      name: 'jaeger',
    }, [
      servicePort.newNamed('query', 80, $._queryPort),
      servicePort.newNamed('query-gprc', $._queryGrpcPort, $._queryGrpcPort),
    ]),

    agent_service: service.new('jaeger-agent', {
      name: 'jaeger',
    }, [
      servicePort.newNamed('agent-compat', $._agentPort, $._agentPort) + servicePort.withProtocol('UDP'),
      servicePort.newNamed('agent-configs', $._agentConfigsPort, $._agentConfigsPort),
    ]),
  },
}
