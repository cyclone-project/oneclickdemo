#!/bin/sh
set -e

echo "Initializing Cyclone Oneclickdemo"

command_exists() {
    command -v "$@" > /dev/null 2>&1;
}

not404() {
    httpcode=$(curl --output /dev/null --silent -w "%{http_code}" "$@")
    if [ "$httpcode" == "404" ]; then
        return 1
    else
        return 0
    fi
}

user="$(id -un 2>/dev/null || true)"
sh_c='sh -c'
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

echo "How will you access the components?"
read -p "IP or hostname: " demohost
# docker-compose is WIP
#read -p "Deploy with (1) Docker Compose or (2) Docker Swarm Mode? " dockermode
dockermode=2

export FP_HOST=$demohost
export FP_BASEURL=http://$FP_HOST

sed "s/%SSP_URL%/http:\/\/$FP_HOST\/samlbridge/g; s/%SSP_ALIAS%/DemoIDP/g" kcexport_template.json > kcexport.json
echo "$FP_BASEURL" > url.txt

cat > openIdConf.json << EOF
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

# deploy with docker-compose
if [ "$dockermode" -eq "1" ]; then
    echo "Deploying with docker-compose"
    $sh_c docker-compose up -d
fi

# deploy with docker swarm
if [ "$dockermode" -eq "2" ]; then
    if $sh_c docker node ls > /dev/null 2>&1; then
        echo "Docker is already in swarm mode"
    else
        echo "Initializing swarm mode"
        $sh_c docker swarm init
    fi
    echo "Deploying with docker swarm and stack name cyclonedemo"
    $sh_c docker stack deploy -c docker-compose.yml cyclonedemo
fi

echo "Waiting for Keycloak."
until $(curl --output /dev/null --silent --head --fail $FP_BASEURL/auth/ \
             && not404 "$FP_BASEURL/auth/"); do
    printf '.'
    sleep 5
done
echo ""

echo "Registering test client"
kccontainer=$($sh_c docker ps -f "ancestor=cycloneproject/keycloak-postgres-ha-demo" -l --format "{{.ID}}")
$sh_c docker exec -i $kccontainer keycloak/bin/kcadm.sh create clients --server http://localhost:8080/auth --realm master --user admin --password admin --client admin-cli -f - << EOF
{
  "clientId": "test",
  "clientTemplate": "Cyclone Template",
  "publicClient": true,
  "redirectUris": ["$FP_BASEURL/*"]
}
EOF

echo "Deployment complete"
echo "You can stop the components using docker stack rm cyclonedemo"
echo "Thank you for trying out Cyclone!"
#echo "You can stop the components using either"
#echo "(1) docker-compose down or"
#echo "(2) docker stack rm cyclonedemo"
exit 0
