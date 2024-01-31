#!/bin/bash

set -e -u -o pipefail

source .venv/bin/activate

locals_base_directory="$(pwd)/sources"
# # mkdir -p workdir
# # --work-dir workdir \
kolla-build \
    --cache \
    --locals-base "${locals_base_directory}" \
    --config-file kolla-build.conf \
    --template-override kolla-template-overrides.j2 \
    --threads 1 \
    --profile horizon
    # --profile neutron \
    # --profile blazar \
    # --profile cinder \
    # --profile keystone \
    # --profile ironic \
    # --profile nova \
    # --profile placement
    # --profile doni
    # --profile infra \
    # --profile glance \
    # --profile heat \
    # --profile manila \
    # --profile prometheus
    # --profile tunelo \
    # --profile cyborg \
    # --profile zun \
    # --list-images
