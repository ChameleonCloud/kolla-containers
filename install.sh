#!/bin/bash

set -euo pipefail

# ensure src/kolla is populated
git submodule update --init

# create venv for tool installation
python3 -m venv .venv
PIP_BUILD_CONSTRAINT=build-constraints.txt \
.venv/bin/pip install \
    -c https://releases.openstack.org/constraints/upper/2025.1 \
    -c build-constraints.txt \
    -e src/kolla \
    docker
