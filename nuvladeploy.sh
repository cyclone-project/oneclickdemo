#!/bin/bash -xe

# retrieve my url
hostname=`ss-get hostname`
link=http://${hostname}
ss-set ss:url.service ${link}

ss-set statecustom 'initialize swarm mode..'
docker swarm init
swarmtoken=$(docker swarm join-token worker -q)
ss-set swarm_join_token ${swarmtoken}

ss-set statecustom 'configure..'
export FP_BASEURL=$link
export FP_HOST=$hostname
sed "s/%SSP_URL%/http:\/\/$hostname\/samlbridge/g; s/%SSP_ALIAS%/DemoIDP/g" kcexport_template.json > kcexport.json
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

ss-set statecustom 'wait for swarmworkers to join..'
swarmworkers=`ss-get swarmworkers`
joinSwmWk=$(docker node ls -f "role=worker" -q | wc -l)
until [ $swarmworkers -eq $joinSwmWk ]; do
    printf '.'
    sleep 5
    joinSwmWk=$(docker node ls -f "role=worker" -q | wc -l)
done

ss-set statecustom 'deploy..'
sudo docker stack deploy -c docker-compose.yml cyclonedemo
until $(curl --output /dev/null --silent --head --fail $link/auth/); do
    printf '.'
    sleep 5
done

ss-set statecustom 'register test client'
kccontainer=$(docker ps -f "ancestor=cycloneproject/keycloak-postgres-ha-demo" -l --format "{{.ID}}")
docker exec -i $kccontainer keycloak/bin/kcadm.sh create clients --server http://localhost:8080/auth --realm master --user admin --password admin --client admin-cli -r master -f - << EOF
{
  "clientId": "test",
  "clientTemplate": "Cyclone Template",
  "publicClient": true,
  "redirectUris": ["$link/*"]
}
EOF

ss-set statecustom 'ready'
