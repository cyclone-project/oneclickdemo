#!/bin/sh
set -xe

DIR=$(dirname "$(readlink -f "$0")")

FP_HOST=`ss-get --timeout=10 FP_HOST` || true
if [ -z "$FP_HOST" ]; then
	FP_HOST=`ss-get hostname`
fi

export FP_HOST=$FP_HOST
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
