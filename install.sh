#!/bin/bash

set -euo pipefail

# ensure src/kolla is populated
git submodule update --init

# create venv for tool installation
python3 -m venv .venv
.venv/bin/pip install -e src/kolla

