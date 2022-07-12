#!/bin/sh
# Files are ordered in proper order with needed wait for the dependent custom resource definitions to get initialized.
# Usage: bash deploy.sh

print_usage() {
  echo "App Deployment Strategies"
  echo " "
  echo "Deployment [options] application [arguments]"
  echo " "
  echo "options:"
  echo "-h                show brief help"
  echo "-d                deploy docker using docker-compose"
  echo "-k                deploy kubernetes using helm"
  echo "-i                enable istio for kubernetes deployment"
  echo "-r                remove app"
  echo "-u                update app(only kubernetes support)"
  exit 0
}

alias vault="kubectl -n demo exec -i  vault-0 -- vault"
remove=""
upgrade=""
istio=""
docker=""
k8s=""
while getopts 'hdkiru' flag; do
    case "${flag}" in
        h) print_usage
           exit 1 ;;
        d) docker='true' ;;
        k) k8s='true' ;;
        i) istio='true' ;;
        r) remove='true' ;;
        u) upgrade='true' ;;
        *) print_usage
           exit 1 ;;
    esac
done

if [ $# -eq 0 ]
  then
    print_usage
    exit 1
fi

suffix=helm
name=myapp
namespace=demo
args=""
helmVersion=$(helm version --client | grep -E "v3\\.[0-9]{1,3}\\.[0-9]{1,3}" | wc -l)

if [ -n "$remove" ]; then
   if [ -n "$docker" ]; then
         docker-compose -f ./deploy/docker/docker-compose.yaml down -v
         rm -f deploy/docker/.env
         rm -f deploy/docker/vault/config/vault-config.json
   elif [ -n "$k8s" ]; then
        helm uninstall consul -n ${namespace}
        helm uninstall vault -n ${namespace}
        helm uninstall ${name} -n ${namespace}
        kubectl -n ${namespace} delete sa internal-app
        kubectl delete pvc --selector="chart=consul-helm" -n ${namespace}
        kubectl -n ${namespace} get secrets --field-selector="type=Opaque" | grep consul | awk '{print $1}' | xargs kubectl -n ${namespace} delete secret
        kubectl -n ${namespace} delete serviceaccount consul-tls-init
        rm -f deploy/${suffix}/cluster-keys.json
          if [ -n "$istio" ]; then
             kubectl remove -f ./deploy/istio-k8s
             kubectl label namespace ${namespace} istio-injection-
          fi
   fi
elif [ -n "$upgrade" ]; then
  if [ -n "$k8s" ]; then
     helm upgrade --install ${name} ./deploy/${suffix} --namespace ${namespace}
  fi
else
   if [ -n "$docker" ]; then
       docker-compose -f ./deploy/docker/docker-compose.yaml up -d consul
       sudo chmod +x ./deploy/docker/consul/consul-init.sh
       ./deploy/docker/consul/consul-init.sh
       docker-compose -f ./deploy/docker/docker-compose.yaml up -d vault
       sudo chmod +x ./deploy/docker/vault/vault-init.sh
       ./deploy/docker/vault/vault-init.sh
       docker-compose -f ./deploy/docker/docker-compose.yaml up -d app
   elif [ -n "$k8s" ]; then
     if [ $helmVersion -eq 1 ]; then
       helm uninstall ${name} 2>/dev/null
     else
       helm remove --purge ${name} 2>/dev/null
     fi
      kubectl create namespace ${namespace}
      helm repo add hashicorp https://helm.releases.hashicorp.com
      helm repo update
      helm install consul hashicorp/consul --values ./deploy/${suffix}/helm-consul-values.yml -n ${namespace}
      kubectl rollout status statefulset consul-server -n ${namespace}
      kubectl rollout status daemonset consul-client -n ${namespace}
      helm install vault hashicorp/vault --values ./deploy/${suffix}/helm-vault-values.yml -n ${namespace}
      kubectl rollout status deployment vault-agent-injector -n ${namespace}
      kubectl -n ${namespace} exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > ./deploy/${suffix}/cluster-keys.json
      VAULT_UNSEAL_KEY=$(cat ./deploy/${suffix}/cluster-keys.json | jq -r ".unseal_keys_b64[]")
      INITIAL_ROOT_TOKEN=$(cat ./deploy/${suffix}/cluster-keys.json | jq -r ".root_token")

      echo $INITIAL_ROOT_TOKEN
      for i in 0 1 2
      do
        kubectl -n ${namespace} exec vault-$i -- vault operator unseal $VAULT_UNSEAL_KEY
      done

      vault login $INITIAL_ROOT_TOKEN
      vault secrets enable -path=secret kv-v2
      vault kv put secret/myapp/test PORT=8084
      vault kv put secret/myapp/prod PORT=8085

      vault auth enable kubernetes

      kubectl -n ${namespace} exec vault-0 -- /bin/sh -c 'vault write auth/kubernetes/config \
                                                        kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
                                                        token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
                                                        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
                                                        issuer="https://kubernetes.default.svc.cluster.local"'

      vault policy write internal-app - <<EOF
      path "secret/data/myapp*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }

      path "secret/data/application*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }
EOF

      kubectl -n ${namespace} create sa internal-app
      vault write auth/kubernetes/role/internal-app \
          bound_service_account_names=internal-app \
          bound_service_account_namespaces=${namespace} \
          policies=internal-app \
          ttl=24h

      helm dep up ./deploy/${suffix}
       if [ -n "$istio" ]; then
           kubectl label namespace ${namespace} istio-injection=enabled --overwrite=true
           kubectl apply -f ./deploy/istio-k8s
           args="--set istio.enabled=true"
       fi
       if [ $helmVersion -eq 1 ]; then
         helm install ${name} ./deploy/${suffix} --replace --namespace ${namespace} ${args}
       else
         helm install --name ${name} ./deploy/${suffix} --replace --namespace ${namespace} ${args}
       fi
   fi
fi