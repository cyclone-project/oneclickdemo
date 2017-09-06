#!/bin/sh
set -e

command_exists() {
    command -v "$@" > /dev/null 2>&1;
}

usage() {
    echo "usage: deploy.sh [IP or Hostname]"
    echo "The IP or Hostname where it will be reachable"
}

if [ -z "$1" ]; then
    usage
    exit 1
fi

export FP_HOST=$1
export FP_BASEURL=http://$FP_HOST
DIR=$(dirname "$(readlink -f "$0")")
user="$(id -un 2>/dev/null || true)"
sh_c=''

command_exists jq || (echo "Error: Could not find jq." && exit 1)

if [ "$user" != "root" ]; then
    if command_exists sudo; then
        sh_c='sudo -E'
    elif command_exists su; then
        sh_c='su -c'
    else
        cat >&2 <<EOF
        Error: this script needs the ability to run commands as root.
        We are unable to find either "sudo" or "su" available to make this happen.
EOF
        exit 1
    fi
fi

echo "Preparing deployment configuration"
echo "$FP_BASEURL" > $DIR/url.txt
sed "s/%SSP_URL%/http:\/\/$FP_HOST\/samlbridge/g; s/%SSP_ALIAS%/DemoIDP/g" \
    $DIR/kcexport_template.json > $DIR/kcexport.json

cat > $DIR/openIdConf.json << EOF
{
 "gen_openid_con_client_id": "test",
 "gen_openid_con_ep_login": "$FP_BASEURL/auth/realms/master/protocol/openid-connect/auth",
 "gen_openid_con_ep_token": "$FP_BASEURL/auth/realms/master/protocol/openid-connect/token",
 "gen_openid_con_ep_userinfo": "$FP_BASEURL/auth/realms/master/protocol/openid-connect/userinfo",
 "gen_openid_con_identity_key": "sub",
 "gen_openid_con_no_sslverify": "1",
 "gen_openid_con_scope": "openid",
 "gen_openid_con_use_autologin": "1",
 "gen_openid_con_allowed_regex": "([A-Za-z0-9\\-\\_]+)"
}
EOF

# pull docker images for reference later
# otherwise we may not be able to retrieve the imgId
echo "Pulling docker images"
$sh_c docker-compose -f $DIR/docker-compose.yml pull

# deploy with docker swarm
if $sh_c docker node ls > /dev/null 2>&1; then
    echo "Docker is already in swarm mode"
else
    echo "Initializing swarm mode"
    $sh_c docker swarm init
fi
echo "Deploying with docker swarm and stack name cyclonedemo"
$sh_c docker stack deploy -c $DIR/docker-compose.yml cyclonedemo

# retrieve container id for keycloak
imgId=$($sh_c docker images cycloneproject/keycloak-postgres-ha-demo --format "{{.ID}}")
until [ -n $($sh_c docker ps -f "ancestor=$imgId" -l --format "{{.ID}}") ]; do
    # container has not started yet so wait a little
    sleep 3
done
kccontainer=$($sh_c docker ps -f "ancestor=$imgId" -l --format "{{.ID}}")
kcadmin="$sh_c docker exec -i $kccontainer keycloak/bin/kcadm.sh"

# log in with kcadm.sh, success means that keycloak is now reachable
until $($kcadmin config credentials --server http://localhost:8080/auth --realm master --user admin --password admin); do
    echo "Will try again in 5 seconds"
    sleep 5
done
echo "Success!"

# add schacHomeOrganization to admin user
# to better be able to demonstrate the logging dashboard
echo "Updating admin user"
adminId=$($kcadmin get users -q username=admin --fields 'id' | jq -r '.[0].id')
$kcadmin update users/$adminId \
         -s 'attributes={"schacHomeOrganization":"admin"}'

echo "Registering test client"
$kcadmin create clients \
         -s clientId=test \
         -s clientTemplate="Cyclone Template" \
         -s publicClient=true \
         -s redirectUris="[\"$FP_BASEURL/*\"]"

echo "Deployment complete"
echo "You can stop and remove the containers using docker stack rm cyclonedemo"
echo "Thank you for trying out Cyclone!"
exit 0
