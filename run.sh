#!/bin/bash

set -euo pipefail

SHORT_SHA="$(git rev-parse --short HEAD)"

# git index and files match HEAD
if $(git diff-index --quiet HEAD --); then
    DOCKER_TAG="${SHORT_SHA}"
else
    DOCKER_TAG="${SHORT_SHA}-dirty"
fi


WORK_DIR_BASE="${TMPDIR:-/tmp}"
# CI runners keep scratch space off the small root partition.
if [ -n "${RUNNER_TEMP:-}" ]; then
    WORK_DIR_BASE="$RUNNER_TEMP"
fi

# Must be unique per run: BuildKit caches the build context by path.
WORK_DIR="$(mktemp -d -p "$WORK_DIR_BASE" kolla-build-XXXXXXXX)"

KEEP_WORK_DIR=${KEEP_WORK_DIR:-}
# --template-only writes the Dockerfiles here and builds nothing.
case " $* " in
    *" --template-only "*) KEEP_WORK_DIR=1 ;;
esac

cleanup() {
    if [ -n "$KEEP_WORK_DIR" ]; then
        echo "Work dir kept at $WORK_DIR"
    else
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

BUILD_PROFILE=${BUILD_PROFILE:-}
BUILD_PATTERN=${BUILD_PATTERN:-}
BUILD_TAG=${BUILD_TAG:-$DOCKER_TAG}
# unset falls through to base_tag in kolla-build.conf
BASE_TAG=${BASE_TAG:-}
PUSH=${PUSH:-}

# handle env vars from CI
CMD=".venv/bin/kolla-build \
    --config-file kolla-build.conf \
    --template-override kolla-template-overrides.j2 \
    --work-dir $WORK_DIR"

if [ "$PUSH" = "true" ]; then CMD="$CMD --push"; fi
if [ ! -z "$BUILD_PROFILE" ]; then CMD="$CMD --profile $BUILD_PROFILE"; fi
if [ -n "$BUILD_TAG" ]; then CMD="$CMD --tag $BUILD_TAG"; fi
if [ -n "$BASE_TAG" ]; then CMD="$CMD --base-tag $BASE_TAG"; fi
if [ -n "$BUILD_PATTERN" ]; then CMD="$CMD $BUILD_PATTERN"; fi

echo "Invoking $CMD $@"
$CMD "$@"
