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

# fetch necessary sources to local dir
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

#create venv and install kolla
mkdir -p tools
clone_branch_to_dir chameleoncloud/2023.1 https://github.com/ChameleonCloud/kolla.git tools/kolla
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -e tools/kolla
