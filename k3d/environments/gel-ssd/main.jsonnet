local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local job = k.batch.v1.job;
local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;
local subject = k.rbac.v1.subject;
local clusterRole = k.rbac.v1.clusterRole;
local policyRule = k.rbac.v1.policyRule;
local serviceAccount = k.core.v1.serviceAccount;
local pvc = k.core.v1.persistentVolumeClaim;
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile) {
  template(name, chart, conf={})::
    std.native('helmTemplate')(name, chart, conf { calledFrom: std.thisFile }),
};

local util = (import 'github.com/grafana/jsonnet-libs/ksonnet-util/util.libsonnet').withK(k) {
  withNonRootSecurityContext(uid, fsGroup=null)::
    { spec+: { template+: { spec+: { securityContext: {
      fsGroup: if fsGroup == null then uid else fsGroup,
      runAsNonRoot: true,
      runAsUser: uid,
    } } } } },
};

local spec = (import './spec.json').spec;
local provisioner = import 'provisioner/provisioner.libsonnet';
local jaeger = import 'jaeger/jaeger.libsonnet';

local lokiSSD = import 'github.com/grafana/loki/production/ksonnet/loki-simple-scalable/loki.libsonnet';
local gel = import 'github.com/grafana/loki/production/ksonnet/enterprise-logs/main.libsonnet';
local grafana = import 'grafana-gel/grafana.libsonnet';
local prometheus = import 'prometheus/prometheus.libsonnet';
local promtail = import 'promtail/promtail.libsonnet';

local namespace = spec.namespace;
local minio = helm.template('minio', '../../charts/minio', {
  namespace: namespace,
  values: {
    enabled: true,
    accessKey: 'loki',
    secretKey: 'supersecret',
    buckets: [
      {
        name: 'gel-data',
        policy: 'none',
        purge: false,
      },
      {
        name: 'gel-admin',
        policy: 'none',
        purge: false,
      },
    ],
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
});

lokiSSD + grafana + prometheus + promtail + jaeger + provisioner + minio {
  local registry = 'k3d-grafana:45629',
  local clusterName = 'enterprise-logs-test-fixture',
  local normalizedClusterName = std.strReplace(clusterName, '-', '_'),
  local gatewayUrl = 'http://read',
  local jaegerQueryName = self.jaeger.query_service.metadata.name,
  local jaegerQueryUrl = 'http://%s' % jaegerQueryName,
  local jaegerAgentName = self.jaeger.agent_service.metadata.name,
  local jaegerAgentUrl = 'http://%s' % jaegerAgentName,
  local prometheusServerName = self.prometheus.service_prometheus_server.metadata.name,
  local prometheusUrl = 'http://%s' % prometheusServerName,
  local provisionerSecret = 'gel-provisioning-tokens',
  local prometheusAnnotations = { 'prometheus.io/scrape': 'true', 'prometheus.io/port': '3100' },
  local envVar = if std.objectHasAll(k.core.v1, 'envVar') then k.core.v1.envVar else k.core.v1.container.envType,
  local parseYaml = std.native('parseYaml'),
  local grpc_listen_port = 9095,

  _images+:: {
    loki: 'grafana/enterprise-logs:v1.3.0',
    provisioner: '%s/enterprise-metrics-provisioner' % registry,
    kubectl: 'bitnami/kubectl',
  },

  _config+:: {
    headless_service_name: 'loki',
    http_listen_port: 3100,
    gatewayHost: 'read',
    gelUrl: gatewayUrl,
    promtailLokiHost: 'write',
    adminApiUrl: gatewayUrl,
    jaegerAgentName: jaegerAgentName,
    jaegerAgentPort: 6831,
    namespace: namespace,
    provisionerSecret: provisionerSecret,
    adminToken: 'gel-admin-token',

    loki: {
      auth_enabled: true,
      auth: {
        type: 'enterprise',
      },
      server: {
        http_listen_port: $._config.http_listen_port,
        grpc_listen_port: grpc_listen_port,
        log_level: 'debug',
      },
      memberlist: {
        join_members: [
          '%s.%s.svc.cluster.local' % [$._config.headless_service_name, namespace],
        ],
      },
      common: {
        path_prefix: '/enterprise-logs',
        storage: {
          s3: {
            s3: 's3://loki:supersecret@minio/gel-data',
            endpoint: 'minio:9000',
            insecure: true,
            s3forcepathstyle: true,
          },
        },
      },
      admin_client: {
        storage: {
          //TODO: error if not specified despite common config
          type: 's3',
          s3: {
            bucket_name: 'gel-admin',
          }
        }
      },
      license: {
        path: '/enterprise-logs/license/license.jwt',
      },
      limits_config: {
        enforce_metric_name: false,
        reject_old_samples_max_age: '168h',  //1 week
        max_global_streams_per_user: 60000,
        ingestion_rate_mb: 75,
        ingestion_burst_size_mb: 100,
      },
      schema_config: {
        configs: [{
          from: '2021-09-12',
          store: 'boltdb-shipper',
          object_store: 's3',
          schema: 'v11',
          index: {
            prefix: '%s_index_' % namespace,
            period: '24h',
          },
        }],
      },
    },

    grafana: {
      datasources: [
        {
          name: 'Prometheus',
          type: 'prometheus',
          access: 'proxy',
          url: prometheusUrl,
        },
        {
          name: 'Jaeger',
          type: 'jaeger',
          access: 'proxy',
          url: jaegerQueryUrl,
          uid: 'jaeger_uid',
        },
        {
          name: 'GEL',
          type: 'loki',
          access: 'proxy',
          url: gatewayUrl,
          basicAuth: true,
          basicAuthUser: 'team-l',
          secureJsonData: {
            basicAuthPassword: '${PROVISIONING_TOKEN_GRAFANA_L}',
          },
          jsonData: {
            derivedFields: [
              {
                datasourceUid: 'jaeger_uid',
                matcherRegex: 'traceID=(\\w+)',
                name: 'TraceID',
                url: '$${__value.raw}',
              },
            ],
          },
        },
      ],
    },

    provisioner: {
      initCommand: [
        '/usr/bin/enterprise-metrics-provisioner',

        '-bootstrap-path=/shared',
        '-cluster-name=' + clusterName,
        '-cortex-url=' + gatewayUrl,
        '-token-file=/bootstrap/token',

        '-instance=team-l',

        '-access-policy=promtail-l:team-l:logs:write',
        '-access-policy=grafana-l:team-l:logs:read',

        '-token=promtail-l',
        '-token=grafana-l',
      ],
      containerCommand: [
        'bash',
        '-c',
        'kubectl create secret generic '
        + provisionerSecret
        + ' --from-literal=token-promtail-l="$(cat /shared/token-promtail-l)"'
        + ' --from-literal=token-grafana-l="$(cat /shared/token-grafana-l)" ',
      ],
    },
  },

  // minio: minio,

  local jaegerEnvVars = [
    envVar.new('JAEGER_AGENT_HOST', $._config.jaegerAgentName),
    envVar.new('JAEGER_AGENT_PORT', '6831'),
    envVar.new('JAEGER_SAMPLER_TYPE', 'const'),
    envVar.new('JAEGER_SAMPLER_PARAM', '1'),
    envVar.new('JAEGER_TAGS', 'app=gel'),
  ],

  licenseSecret: k.core.v1.secret.new('gel-license', {
    'license.jwt': std.base64(importstr '../../secrets/gel.jwt'),
  }),

  write_container+:: container.withEnv(jaegerEnvVars),
  read_container+:: container.withEnv(jaegerEnvVars),

  write_pvc+::
    pvc.mixin.spec.withStorageClassName('local-path'),
  read_pvc+::
    pvc.mixin.spec.withStorageClassName('local-path'),

  read_statefulset+: k.util.secretVolumeMount('gel-license', '/enterprise-logs/license/') +
                     k.apps.v1.statefulSet.spec.template.metadata.withAnnotations($._prometheusAnnotations),
  write_statefulset+: k.util.secretVolumeMount('gel-license', '/enterprise-logs/license/') +
                      k.apps.v1.statefulSet.spec.template.metadata.withAnnotations($._prometheusAnnotations),

  tokengen_args:: {
    target: 'tokengen',
    'cluster-name': clusterName,
    'tokengen.token-file': '/shared/admin-token',
    'config.file': '/etc/loki/config/config.yaml',
  },
  tokengen_container::
    container.new('tokengen', self._images.loki)
    + container.withPorts([
      containerPort.new(name='http-metrics', port=$._config.http_listen_port),
      containerPort.new(name='grpc', port=9095),
    ])
    + container.withArgs(k.util.mapToFlags(self.tokengen_args))
    + container.withVolumeMounts([
      { mountPath: '/etc/loki/config', name: 'config' },
      { mountPath: '/shared', name: 'shared' },
    ])
    + container.resources.withLimits({ memory: '4Gi' })
    + container.resources.withRequests({ cpu: '500m', memory: '500Mi' }),
  tokengen_create_secret_container::
    container.new('create-secret', self._images.kubectl)
    + container.withCommand([
      '/bin/bash',
      '-euc',
      'kubectl create secret generic gel-admin-token --from-file=token=/shared/admin-token --from-literal=grafana-token="$(base64 <(echo :$(cat /shared/admin-token)))"',
    ])
    + container.withVolumeMounts([{ mountPath: '/shared', name: 'shared' }]),

  tokengen_job:
    job.new('tokengen')
    + job.spec.withCompletions(1)
    + job.spec.withParallelism(1)
    + job.spec.withBackoffLimit(10)
    + job.spec.template.spec.withContainers([self.tokengen_create_secret_container])
    + job.spec.template.spec.withInitContainers([self.tokengen_container])
    + job.spec.template.spec.withRestartPolicy('OnFailure')
    + job.spec.template.spec.withServiceAccount('tokengen')
    + job.spec.template.spec.withServiceAccountName('tokengen')
    + job.spec.template.spec.withVolumes([
      { name: 'config', configMap: { name: 'loki' } },
      { name: 'shared', emptyDir: {} },
    ])
    + util.withNonRootSecurityContext(uid=10001),

  tokengen_service_account:
    serviceAccount.new('tokengen'),

  tokengen_cluster_role:
    clusterRole.new('tokengen')
    + clusterRole.withRules([
      policyRule.withApiGroups([''])
      + policyRule.withResources(['secrets'])
      + policyRule.withVerbs(['create']),
    ]),

  tokengen_cluster_role_binding:
    clusterRoleBinding.new()
    + clusterRoleBinding.metadata.withName('tokengen')
    + clusterRoleBinding.roleRef.withApiGroup('rbac.authorization.k8s.io')
    + clusterRoleBinding.roleRef.withKind('ClusterRole')
    + clusterRoleBinding.roleRef.withName('tokengen')
    + clusterRoleBinding.withSubjects([
      subject.new()
      + subject.withName('tokengen')
      + subject.withKind('ServiceAccount')
      + { namespace: $._config.namespace },
    ]),
}
