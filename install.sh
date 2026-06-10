#!/bin/bash

set -euo pipefail

# ensure src/kolla is populated
git submodule update --init

# create venv for tool installation
python3 -m venv .venv
.venv/bin/pip install -e src/kolla

# Toolchain for building reproducible service sdists in
# tools/prebuild-sources.sh. Pinned so sdist bytes are byte-identical across
# build hosts (these produce the archive that keys Docker's ADD layer cache).
# Versions can be tuned once cross-host reproducibility is validated.
.venv/bin/pip install \
    "build==1.2.1" \
    "pbr==6.1.0" \
    "setuptools==70.0.0" \
    "wheel==0.43.0"
