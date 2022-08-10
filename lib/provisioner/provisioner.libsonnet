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
    adminToken: error 'please provide $._config.adminToken',
    adminApiUrl: error 'adminApiUrl must be provided as $._config.adminApiUrl',
    provisioningTokensSecretName: error 'provisioning tokens secret name must be provided as $._config.provisioningTokenSecretName',
    volumeMounts: [
      volumeMount.new('shared', '/shared'),
      volumeMount.new('bootstrap', '/bootstrap', readOnly=true),
    ],
    provisioner: {
      initCommand: [],
      containerCommand: [],
    },
  },

  _images+:: {},

  provisioner: {
    initContainer::
      container.new(name, $._images.provisioner)
      + container.withCommand($._config.provisioner.initCommand)
      + container.withVolumeMounts($._config.volumeMounts),

    container::
      container.new(name + '-create-secret', gem._images.kubectl)
      + container.withCommand($._config.provisioner.containerCommand)
      + container.withVolumeMounts($._config.volumeMounts),

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
  },
}
