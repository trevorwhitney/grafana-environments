{
  auth_enabled: false,
  common: {
    path_prefix: '/var/loki',
    storage: {
      filesystem: {
        chunks_directory: '/var/loki/chunks',
        rules_directory: '/var/loki/rules',
      },
    },
  },
  server: {
    http_listen_port: 3100,
  },
  distributor: {
    ring: {
      kvstore: {
        store: 'memberlist',
      },
    },
  },
  ingester: {
    lifecycler: {
      ring: {
        kvstore: {
          store: 'memberlist',
        },
        replication_factor: 1,
      },
      final_sleep: '0s',
    },
    chunk_target_size: 2097152,
    max_chunk_age: '8h',
    chunk_idle_period: '1h',
    wal: {
      enabled: true,
      dir: '/var/loki/wal',
      replay_memory_ceiling: '512MB',
    },
  },
  memberlist: {
    join_members: [
      '{{ include "loki.fullname" . }}-memberlist',
    ],
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
  compactor: {
    shared_store: 'filesystem',
    compaction_interval: '5m',
    retention_enabled: true,
  },
  frontend: {
    log_queries_longer_than: '5s',
    compress_responses: true,
  },
  frontend_worker: {
    frontend_address: '{{ include "loki.queryFrontendFullname" . }}:9095',
    grpc_client_config: {
      max_send_msg_size: 104857600,
    },
    parallelism: 6,
    match_max_concurrent: true,
  },
  querier: {
    max_concurrent: 6,
  },
}
