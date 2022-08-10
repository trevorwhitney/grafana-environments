{
  auth_enabled: false,
  analytics: {
    reporting_enabled: false,
  },
  common: {
    path_prefix: '/var/loki',
    storage: {
      s3: {
        s3: 's3://loki:supersecret@minio:9000/loki-data',
        //Must require endpoint since minio doesn't follow s3 standards
        endpoint: 'minio:9000',
        s3forcepathstyle: true,
        insecure: true,
      },
    },
  },
  server: {
    http_listen_port: 3100,
  },
  ingester: {
    max_chunk_age: '2h',
  },
  querier: {
    query_ingesters_within: '2h',
  },
  memberlist: {
    join_members: [
      '{{ include "loki.fullname" . }}-memberlist',
    ],
  },
  ruler: {
    enable_sharding: true,
    storage: {
      s3: {
        bucketnames: 'loki-rules',
      },
    },
  },
  schema_config: {
    configs: [
      {
        from: '2020-05-15',
        store: 'boltdb-shipper',
        object_store: 'filesystem',
        schema: 'v11',
        index: {
          prefix: 'index_',
          period: '24h',
        },
      },
    ],
  },
  limits_config: {
    enforce_metric_name: false,
    reject_old_samples: true,
    reject_old_samples_max_age: '168h',
    retention_period: '24h',
  },
}
