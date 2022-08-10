{
  new(name, url, type, default=false, uid=null):: {
    name: name,
    type: type,
    uid: uid,
    access: 'proxy',
    url: url,
    isDefault: default,
    version: 1,
    editable: false,
  },
  withJsonData(data):: {
    jsonData+: data,
  },
  withSecureJsonData(data):: {
    secureJsonData+: data,
  },
}
