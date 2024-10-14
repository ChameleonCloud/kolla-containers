#!/bin/bash

set -euo pipefail

SHORT_SHA="$(git rev-parse --short HEAD)"

# git index and files match HEAD
if $(git diff-index --quiet HEAD --); then
    DOCKER_TAG="${SHORT_SHA}"
else
    DOCKER_TAG="${SHORT_SHA}-dirty"
fi

echo "Tagging containers with ${DOCKER_TAG}"
.venv/bin/kolla-build \
    --config-file kolla-build.conf \
    --template-override kolla-template-overrides.j2 \
    --tag "${DOCKER_TAG}" \
    "$@"

