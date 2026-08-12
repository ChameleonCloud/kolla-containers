#!/bin/bash

# Apply additional tags to images kolla built, and push them.
#
# kolla-build takes a single --tag, so builds are tagged by git SHA (run.sh's
# default) and the release tag is applied here. Two reasons this is a separate
# step rather than run.sh --push:
#
#   - kolla pushes each image from inside the same try/except as the build
#     (src/kolla/kolla/image/tasks.py), so a transient registry error marks a
#     successfully-built image as failed and takes the run with it.
#   - the release tag then moves only once the whole build has succeeded, rather
#     than being mutated image by image as kolla goes.
#
# PUSH is read the same way run.sh reads it; unset means tag locally only.
# Depends on the images being present in the local docker context.
#
#     PUSH=true ./retag.sh "$(git rev-parse --short HEAD)-ubuntu-jammy" 2023.1-ubuntu-jammy

set -euo pipefail

BUILT_TAG="$1"
shift
EXTRA_TAGS=("$@")

PUSH=${PUSH:-}

# read from the config rather than hardcoding, so this can't drift from the build
registry=$(awk -F' *= *' '/^registry *=/{print $2}' kolla-build.conf)
namespace=$(awk -F' *= *' '/^namespace *=/{print $2}' kolla-build.conf)
prefix="${registry}/${namespace}"

mapfile -t repos < <(
    docker images --filter "reference=${prefix}/*:${BUILT_TAG}" \
        --format '{{.Repository}}' | sort -u
)

# without this, a build that produced nothing looks like a successful push
if [ "${#repos[@]}" -eq 0 ]; then
    echo "no local images match ${prefix}/*:${BUILT_TAG}" >&2
    exit 1
fi

maybe_push() {
    if [ "$PUSH" = "true" ]; then
        docker push "$1"
    else
        echo "PUSH is not 'true', skipping push of $1"
    fi
}

echo "Pushing ${#repos[@]} images at ${BUILT_TAG}"
for repo in "${repos[@]}"; do
    maybe_push "${repo}:${BUILT_TAG}"
done

# second pass, so a failure part-way leaves the release tag on none of the
# images rather than on an arbitrary subset
for tag in "${EXTRA_TAGS[@]}"; do
    echo "Applying ${tag} to ${#repos[@]} images"
    for repo in "${repos[@]}"; do
        docker tag "${repo}:${BUILT_TAG}" "${repo}:${tag}"
        maybe_push "${repo}:${tag}"
    done
done
