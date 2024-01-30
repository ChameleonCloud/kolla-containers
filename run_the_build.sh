#!/bin/bash

set -e -u -o pipefail

clone_branch_to_dir () {

    echo "checking ${2}"
    # if directory exists, ensure it's at the correct checkout
    if [ -d ${3} ]
    then
        ( cd ${3}; git checkout ${1} )
    else
        # otherwise, clone it to the correct branch
        git clone \
            --branch "${1}" \
            "${2}" \
            "${3}"
    fi
}

mkdir -p sources

clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/blazar.git sources/blazar
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/blazar.git sources/blazar
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/blazar-dashboard.git sources/blazar-dashboard
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/blazar-nova.git sources/blazar-nova
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/doni.git sources/doni
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/heat.git sources/heat
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/heat-dashboard.git sources/heat-dashboard
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/horizon.git sources/horizon
clone_branch_to_dir master https://github.com/ChameleonCloud/horizon-theme.git sources/horizon-theme
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/keystone.git sources/keystone
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/nova.git sources/nova

locals_base_directory="$(pwd)/sources"


# mkdir -p workdir
# --work-dir workdir \
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
