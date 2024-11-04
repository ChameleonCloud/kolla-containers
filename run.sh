#!/bin/bash

set -euo pipefail

SHORT_SHA="$(git rev-parse --short HEAD)"

# git index and files match HEAD
if $(git diff-index --quiet HEAD --); then
    DOCKER_TAG="${SHORT_SHA}"
else
    DOCKER_TAG="${SHORT_SHA}-dirty"
fi


BUILD_PROFILE=${BUILD_PROFILE:-}
BUILD_PATTERN=${BUILD_PATTERN:-}
BUILD_TAG=${BUILD_TAG:-$DOCKER_TAG}
PUSH=${PUSH:-}

# handle env vars from CI
CMD=".venv/bin/kolla-build \
    --config-file kolla-build.conf \
    --template-override kolla-template-overrides.j2"

if [ "$PUSH" = "true" ]; then CMD="$CMD --push"; fi
if [ ! -z "$BUILD_PROFILE" ]; then CMD="$CMD --profile $BUILD_PROFILE"; fi
if [ -n "$BUILD_TAG" ]; then CMD="$CMD --tag $BUILD_TAG"; fi
if [ -n "$BUILD_PATTERN" ]; then CMD="$CMD $BUILD_PATTERN"; fi

echo "Invoking $CMD $@"
$CMD "$@"
