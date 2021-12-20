local gem = import 'github.com/grafana/jsonnet-libs/enterprise-metrics/main.libsonnet';
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet',
      container = k.core.v1.container,
      job = k.batch.v1.job,
      persistentVolumeClaim = k.core.v1.persistentVolumeClaim,
      policyRule = k.rbac.v1.policyRule,
      subject = k.rbac.v1.subject,
      role = k.rbac.v1.role,
      roleBinding = k.rbac.v1.roleBinding,
      serviceAccount = k.core.v1.serviceAccount,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount;

{
  local name = 'provisioner',

  _config+:: {
    adminToken: 'gem-admin-token',
    adminApiUrl: error 'adminApiUrl must be provided as $._config.adminApiUrl',
    provisioningTokensSecretName: error 'provisioning tokens secret name must be provided as $._config.provisioningTokenSecretName',
    volumeMounts: [
      volumeMount.new('shared', '/shared'),
      volumeMount.new('bootstrap', '/bootstrap', readOnly=true),
    ],
  },

  _images:: {},

  command:: [
    '/usr/bin/enterprise-metrics-provisioner',

    '-token-file=/bootstrap/token',
    '-bootstrap-path=/shared',
    '-cortex-url=' + $._config.adminApiUrl,

    '-instance=team-a',
    '-instance=team-b',

    '-access-policy=alertmanager-a:team-a:alerts:read,alerts:write',
    '-access-policy=alertmanager-b:team-b:alerts:read,alerts:write',
    '-access-policy=grafana-a:team-a:metrics:read',
    '-access-policy=grafana-b:team-b:metrics:read',
    '-access-policy=grafana-ab:team-a,team-b:metrics:read',
    '-access-policy=prometheus-a:team-a:metrics:write',
    '-access-policy=prometheus-b:team-b:metrics:write',
    '-access-policy=ruler-a:team-a:metrics:read,metrics:write',
    '-access-policy=ruler-b:team-b:metrics:read,metrics:write',

    '-token=alertmanager-a',
    '-token=alertmanager-b',
    '-token=grafana-a',
    '-token=grafana-b',
    '-token=grafana-ab',
    '-token=prometheus-a',
    '-token=prometheus-b',
    '-token=ruler-a',
    '-token=ruler-b',
  ],

  initContainer::
    container.new(name, $._images.provisioner)
    + container.withCommand(self.command)
    + container.withVolumeMounts(self._config.volumeMounts),

  container::
    container.new(name + '-create-secret', gem._images.kubectl)
    + container.withCommand([
      'bash',
      '-c',
      'kubectl delete secret generic ' +
      $._config.provisioningTokensSecretName + ' --ignore-not-found=true ' +
      ' && ' +
      'kubectl create secret generic ' +
      $._config.provisioningTokensSecretName + ' ' +
      '--from-literal=token-alertmanager-a="$(cat /shared/token-alertmanager-a)" ' +
      '--from-literal=token-alertmanager-b="$(cat /shared/token-alertmanager-b)" ' +
      '--from-literal=token-grafana-a="$(cat /shared/token-grafana-a)" ' +
      '--from-literal=token-grafana-b="$(cat /shared/token-grafana-b)" ' +
      '--from-literal=token-grafana-ab="$(cat /shared/token-grafana-ab)" ' +
      '--from-literal=token-prometheus-a="$(cat /shared/token-prometheus-a)" ' +
      '--from-literal=token-prometheus-b="$(cat /shared/token-prometheus-b)" ' +
      '--from-literal=token-ruler-a="$(cat /shared/token-ruler-a)" ' +
      '--from-literal=token-ruler-b="$(cat /shared/token-ruler-b)" ',
    ])
    + container.withVolumeMounts(self._config.volumeMounts),

  job:
    job.new(name)
    + job.spec.withCompletions(1)
    + job.spec.withParallelism(1)
    + job.spec.template.spec.withInitContainers([self.initContainer])
    + job.spec.template.spec.withContainers([self.container])
    + job.spec.template.spec.withRestartPolicy('OnFailure')
    + job.spec.template.spec.withServiceAccount(name)
    + job.spec.template.spec.withServiceAccountName(name)
    + job.spec.template.spec.withVolumes([
      volume.fromPersistentVolumeClaim('shared', 'provisioner-pv-shared'),
      volume.fromSecret('bootstrap', $._config.adminToken),
    ]),

  persistentVolumeClaim: persistentVolumeClaim.new('provisioner-pv-shared')
                         + persistentVolumeClaim.spec.resources.withRequests({ storage: '100Mi' })
                         + persistentVolumeClaim.spec.withAccessModes(['ReadWriteOnce']),

  serviceAccount:
    serviceAccount.new(name),

  role:
    role.new(name)
    + role.withRules([
      policyRule.withApiGroups([''])
      + policyRule.withResources(['secrets'])
      + policyRule.withVerbs(['create', 'delete']),
    ]),

  roleBinding:
    roleBinding.new()
    + roleBinding.metadata.withName(name)
    + roleBinding.roleRef.withApiGroup('rbac.authorization.k8s.io')
    + roleBinding.roleRef.withKind('Role')
    + roleBinding.roleRef.withName(name)
    + roleBinding.withSubjects([
      subject.new()
      + subject.withName(name)
      + subject.withKind('ServiceAccount'),
    ]),

}
