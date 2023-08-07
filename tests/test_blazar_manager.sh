#!/bin/bash

set -euo pipefail

# ensure that lease end script is present
docker run --rm -it \
    ghcr.io/chameleoncloud/kolla/ubuntu-source-blazar-manager:xena-dc5823b \
    stat /etc/blazar/blazar-manager/hooks/on_before_end.py

docker run --rm -it \
    ghcr.io/chameleoncloud/kolla/ubuntu-source-blazar-manager:xena-dc5823b \
    stat /usr/local/bin/blazar_before_end_action_email
