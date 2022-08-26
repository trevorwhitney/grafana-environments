local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local grafana = import 'grafana/grafana.libsonnet';

local spec = (import './spec.json').spec;
local minio = import 'minio/minio.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};

local prometheus = import 'kube-prometheus-stack/kube-prometheus-stack.libsonnet';

local clusterName = 'loki-origin-hackathon';
local normalizedClusterName = std.strReplace(clusterName, '-', '_');
local registry = 'k3d-grafana:41139';

local envVar = if std.objectHasAll(k.core.v1, 'envVar') then k.core.v1.envVar else k.core.v1.container.envType;


prometheus + minio + {
  local gatewayName = 'loki-gateway',
  local gatewayHost = '%s' % gatewayName,
  local gatewayUrl = 'http://%s' % gatewayHost,
  local prometheusServerName = self.kubePrometheusStack.service_prometheus_kube_prometheus_prometheus.metadata.name,
  local prometheusUrl = 'http://%s:9090' % prometheusServerName,
  local agentOperatorSA = self.agentOperator.service_account_agent_operator_grafana_agent_operator.metadata.name,
  local namespace = spec.namespace,

  _config+:: {
    namespace: namespace,
    promtail+: {
      promtailLokiHost: gatewayHost,
    },

    minio+: {
      accessKey: 'loki',
      buckets: [
        {
          name: 'loki-data',
          policy: 'none',
          purge: false,
        },
        {
          name: 'loki-rules',
          policy: 'none',
          purge: false,
        },
      ],
    },
  },

  namespace: k.core.v1.namespace.new(namespace),

  prometheus_datasource:: grafana.datasource.new('prometheus', prometheusUrl, type='prometheus', default=true),


  grafana: grafana
           + grafana.withAnonymous()
           + grafana.withImage('grafana/grafana-enterprise:8.2.5')
           + grafana.withGrafanaIniConfig({
             sections+: {
               server: {
                 http_port: 3000,
                 router_logging: true,
               },
               analytics: {
                 reporting_enabled: false,
               },
               users: {
                 default_theme: 'light',
               },
               'log.frontend': {
                 enabled: true,
               },
               paths: {
                 provisioning: '/etc/grafana/provisioning',
                 // plugins: '/var/lib/grafana/plugins',
               },
               enterprise: {
                 license_text: importstr '../../secrets/grafana.jwt',
               },
             },
           })
           + grafana.withEnterpriseLicenseText(importstr '../../secrets/grafana.jwt')
           + grafana.addDatasource('prometheus', $.prometheus_datasource)
           // + grafana.addPlugin('grafana-enterprise-logs-app')
           + {
             local container = k.core.v1.container,
             grafana_deployment+:
               k.apps.v1.deployment.hostVolumeMount(
                 name='enterprise-logs-app',
                 hostPath='/var/lib/grafana/plugins/grafana-enterprise-logs-app/dist',
                 path='/grafana-enterprise-logs-app',
                 volumeMixin=k.core.v1.volume.hostPath.withType('Directory')
               )
               + k.apps.v1.deployment.emptyVolumeMount('grafana-var', '/var/lib/grafana')
               + k.apps.v1.deployment.emptyVolumeMount('grafana-plugins', '/etc/grafana/provisioning/plugins')
               + k.apps.v1.deployment.spec.template.spec.withInitContainersMixin([
                 container.new('startup', 'alpine:latest') +
                 container.withCommand([
                   '/bin/sh',
                   '-euc',
                   |||
                     mkdir -p /var/lib/grafana/plugins
                     cp -r /grafana-enterprise-logs-app /var/lib/grafana/plugins/grafana-enterprise-logs-app
                     chown -R 472:472 /var/lib/grafana/plugins

                     ls -l /var/lib/grafana/plugins

                     cat > /etc/grafana/provisioning/plugins/enterprise-logs.yaml <<EOF
                     apiVersion: 1
                     apps:
                       - type: grafana-enterprise-logs-app
                         jsonData:
                           backendUrl: http://enterprise-logs:3100
                     EOF
                   |||,
                 ]) +
                 container.withVolumeMounts([
                   k.core.v1.volumeMount.new('enterprise-logs-app', '/grafana-enterprise-logs-app', false),
                   k.core.v1.volumeMount.new('grafana-var', '/var/lib/grafana', false),
                   k.core.v1.volumeMount.new('grafana-plugins', '/etc/grafana/provisioning/plugins', false),
                 ]) +
                 container.withImagePullPolicy('IfNotPresent') +
                 container.mixin.securityContext.withPrivileged(true) +
                 container.mixin.securityContext.withRunAsUser(0),
               ]) + k.apps.v1.deployment.mapContainers(
                 function(c) c {
                   env+: [
                     envVar.new('GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS', 'grafana-enterprise-logs-app'),
                   ],
                 }
               ),
           },

}
