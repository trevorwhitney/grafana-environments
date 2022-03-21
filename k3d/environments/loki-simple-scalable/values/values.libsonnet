{
  lokiValues: function(configStr) {
    loki: {
      config: configStr,
    },
    write: {
      replicas: 3,
    },
    read: {
      replicas: 3,
    },
  },
}
