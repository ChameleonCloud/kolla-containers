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

# Stage deterministic source archives (reproducible sdists / canonical tars)
# and generate the local-source overrides config. Set PREBUILD_SOURCES=false to
# skip (e.g. to fall back to kolla's built-in git source handling).
if [ "${PREBUILD_SOURCES:-true}" = "true" ]; then
    ./tools/prebuild-sources.sh
fi

# handle env vars from CI
CMD=".venv/bin/kolla-build \
    --config-file kolla-build.conf \
    --template-override kolla-template-overrides.j2"

# Listed after kolla-build.conf so its `type = local` source overrides win
# (oslo.config is last-file-wins per option).
if [ -f sources.generated.conf ]; then
    CMD="$CMD --config-file sources.generated.conf"
fi

if [ "$PUSH" = "true" ]; then CMD="$CMD --push"; fi
if [ ! -z "$BUILD_PROFILE" ]; then CMD="$CMD --profile $BUILD_PROFILE"; fi
if [ -n "$BUILD_TAG" ]; then CMD="$CMD --tag $BUILD_TAG"; fi
if [ -n "$BUILD_PATTERN" ]; then CMD="$CMD $BUILD_PATTERN"; fi

echo "Invoking $CMD $@"
$CMD "$@"
