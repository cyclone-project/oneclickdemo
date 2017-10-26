#!/bin/sh
set -e

usage() {
	echo "usage: reset.sh [IP or Hostname]"
    echo "The IP or Hostname at which the demo should be reachable"
}

command_exists() {
    command -v "$@" > /dev/null 2>&1;
}

if [ -z "$1" ]; then
    usage
    exit 1
fi

DIR=$(dirname "$(readlink -f "$0")")
user="$(id -un 2>/dev/null || true)"
sh_c=''

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

$sh_c docker stack rm cyclonedemo
until $sh_c docker stack rm cyclonedemo > /dev/null; do
  echo "waiting for cyclonedemo to be deleted"
  sleep 3
done

exec $DIR/deploy.sh "$1"

