#!/bin/sh
set -xe

DIR=$(dirname "$(readlink -f "$0")")

export FP_HOST=`ss-get hostname`
export FP_BASEURL=http://$FP_HOST
ss-set ss:url.service ${FP_BASEURL}

ss-set statecustom 'initialize swarm mode..'
docker swarm init
swarmtoken=$(docker swarm join-token worker -q)
ss-set swarm_join_token ${swarmtoken}

ss-set statecustom 'wait for swarmworkers to join..'
swarmworkers=`ss-get swarmworkers`
joinSwmWk=$(docker node ls -f "role=worker" -q | wc -l)
until [ $swarmworkers -eq $joinSwmWk ]; do
    printf '.'
    sleep 5
    joinSwmWk=$(docker node ls -f "role=worker" -q | wc -l)
done

ss-set statecustom 'deploy..'

$DIR/deploy.sh $FP_HOST

ss-set statecustom 'ready'
