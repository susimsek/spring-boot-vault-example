#!/bin/sh

alias vault="docker exec -i $(docker ps|awk '/vault:latest/ {print $1}') vault"

while ! nc -z localhost 8200;
do
  echo sleeping;
  sleep 1;
done;
echo "Vault Connected"

sleep 20

vault operator init |awk -F: '/:/ {
    if ($1 ~ /Unseal Key 1/) print "UNSEAL_KEY_1="$2
    if ($1 ~ /Unseal Key 2/) print "UNSEAL_KEY_2="$2
    if ($1 ~ /Unseal Key 3/) print "UNSEAL_KEY_3="$2
    if ($1 ~ /Unseal Key 4/) print "UNSEAL_KEY_4="$2
    if ($1 ~ /Unseal Key 5/) print "UNSEAL_KEY_5="$2
    if ($1 ~ /Initial Root Token/) print "INITIAL_ROOT_TOKEN="$2
}' \
| sed 's/ //g' \
| tee -a deploy/docker/.env

source deploy/docker/.env

# unseal the vault using 3 of the keys
vault operator unseal $UNSEAL_KEY_1
vault operator unseal $UNSEAL_KEY_2
vault operator unseal $UNSEAL_KEY_3

echo $INITIAL_ROOT_TOKEN|vault login -

vault auth enable approle
vault secrets enable -path=secret/ kv

# enable file audit to the mounted logs volume
vault audit enable file file_path=/vault/logs/audit.log
vault audit list

# create the app-specific policy
vault policy write app /policies/myapp-policy.json
vault policy read app

# create the app token
vault token create -policy=app | awk '/token/ {
if ($1 == "token") print "MYAPP_TOKEN="$2
else if ($1 == "token_accessor") print "MYAPP_TOKEN_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

vault write auth/approle/role/myapp \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=app

vault read auth/approle/role/myapp/role-id | awk '/role_id/ {
print "MYAPP_APP_ROLE_ROLE_ID="$2
}' \
| tee -a deploy/docker/.env

vault write -f auth/approle/role/myapp/secret-id | awk '/secret_id/ {
if ($1 == "secret_id") print "MYAPP_APP_ROLE_SECRET_ID="$2
else if ($1 == "secret_id_accessor") print "MYAPP_APP_ROLE_SECRET_ID_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

# source the env file to get the new key vars
source deploy/docker/.env

# login using the app token
echo $MYAPP_TOKEN|vault login -

# create initial secrets
vault kv put secret/myapp/test PORT=8084
vault kv put secret/myapp/prod PORT=8085