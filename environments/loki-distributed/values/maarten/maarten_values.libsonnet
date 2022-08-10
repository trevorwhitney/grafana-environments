{
  lokiValues: function(configStr) {
    loki: {
      config: configStr,
    },
    ingester: {
      replicas: 1,
      persistence: {
        enabled: true,
      },
      podAnnotations: {
        'prometheus.io/scrape': 'true',
        'prometheus.io/path': '/metrics',
        'prometheus.io/port': '3100',
      },
    },
    distributor: {
      replicas: 1,
    },
    querier: {
      replicas: 6,
      persistence: {
        enabled: true,
      },
      affinity: ""
    },
    queryFrontend: {
      replicas: 4,
      affinity: ""
    },
    gateway: {
      replicas: 1,
    },
    compactor: {
      enabled: true,
      persistence: {
        enabled: true,
      },
      podAnnotations: {
        'prometheus.io/scrape': 'true',
        'prometheus.io/path': '/metrics',
        'prometheus.io/port': '3100',
      },
    },
  },
}
