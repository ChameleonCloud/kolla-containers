#!/bin/bash

set -euo pipefail

# ensure patch 0001 is present
docker run --rm -it \
    ghcr.io/chameleoncloud/kolla/ubuntu-source-neutron-server:xena \
    grep "startup-config\""  /var/lib/kolla/venv/lib/python3.8/site-packages/netmiko/dell/dell_force10_ssh.py

docker run --rm -it \
    ghcr.io/chameleoncloud/kolla/ubuntu-source-neutron-server:xena \
    grep '"dell_fnioa": DellForce10SSH'  /var/lib/kolla/venv/lib/python3.8/site-packages/netmiko/ssh_dispatcher.py

docker run --rm -it \
    ghcr.io/chameleoncloud/kolla/ubuntu-source-neutron-server:xena \
    pip show etcd3gw
