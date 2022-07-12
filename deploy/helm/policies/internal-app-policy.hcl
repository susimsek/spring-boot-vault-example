path "secret/data/myapp*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/application*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}