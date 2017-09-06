Cyclone Oneclickdemo
====================

The Cyclone Oneclickdemo is a preconfigured, easy-to-deploy and scalable demo deployment with the [cyclone-federation-provider](https://github.com/cyclone-project/cyclone-federation-provider), [cyclone-logging](https://github.com/cyclone-project/cyclone-logging), and [cyclone-demo-wp-docker](https://github.com/cyclone-project/cyclone-demo-wp-docker) plus a Demo Identity Provider, all configured to interact.

This repository contains scripts and configuration for the cyclone oneclickdemo deployment.

## How to use

__Dependencies:__ Docker, root and/or sudo/su, and jq.

Deploy with docker swarm using `deploy.sh`, e.g.

```shell
# provide hostname or ip where it will be reachable
./deploy.sh 10.0.2.15

# or if you are deploying on nuvla
./nuvladeploy.sh
```

Visit the Hostname/IP given to the script in your browser. The endpoints are:

| Component  | Endpoint    |
|------------|-------------|
| Wordpress  | /           |
| Keycloak   | /auth       |
| Samlbridge | /samlbridge |
| SamlIDP    | /samlidp    |
| Kibana     | /kibana     |

 The SamlIDP provides the following users:  

| | | | | |
|----------|------|-------|-------|-------|
| Username | user | user2 | user3 | user4 |
| Password | user | user  | user  | user  |
| displayName | user | user2 | user3 | user4 |
| eduPersonAffiliation | member,student | member,student | member,student | member,student |
| mail | user1@samlidp.com | user2@samlidp.com | user3@samlidp.com | user4@samlidp.com |
| schacHomeOrganization | admin | demo | demo | demo |
| eduPersonTargetedID | ✔ | ✔ | ✔ | ✘ |

To change Keycloak configuration log in with username `admin` and password `admin`. Same username and password applies to the Samlbridge and SamlIDP. You can log in to Wordpress and Kibana using any of the configured users. To view all logs in Kibana, log in as `admin` on Keycloak or `user` on the SamlIDP.
