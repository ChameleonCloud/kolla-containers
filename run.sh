#!/usr/bin/env bash
# Copyright 2021 University of Chicago
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" >/dev/null 2>&1)" && pwd)"
VIRTUALENV="$(realpath ${VIRTUALENV:-"${DIR}"/venv})"
FORCE_UPDATES="${FORCE_UPDATES:-no}"
CHECK_UPDATES=yes

if [[ ! -f "${VIRTUALENV}"/bin/activate ]]; then
  echo "Creating virtualenv at ${VIRTUALENV} ..."
  python3 -m venv "${VIRTUALENV}" --system-site-packages
  "${VIRTUALENV}"/bin/pip install --upgrade pip
  FORCE_UPDATES=yes
fi

source "${VIRTUALENV}"/bin/activate
env_file="${DIR}"/.env
if [[ -f "${env_file}" ]]; then
  echo "Automatically sourcing .env file:"
  cat "${env_file}"
  set -a; source "${env_file}"; set +a
fi

# Set these _after_ sourcing a possible .env file, so it can be defaulted there.
KOLLA_BRANCH="${KOLLA_BRANCH:-chameleoncloud/xena}"

# by default, tag containers with the git sha for kolla-containers repo
GIT_REF="$(git rev-parse --short HEAD)"
if [[ -n $(git status --porcelain) ]]; then
  GIT_REF="${GIT_REF}-dirty"
fi

export DOCKER_TAG="${GIT_REF}"

# Automatically update dependencies
if [[ "${CHECK_UPDATES}" == "yes" || "${FORCE_UPDATES}" == "yes" ]]; then
  pip_requirements="${DIR}"/requirements.txt
  pip_requirements_chksum="${VIRTUALENV}"/requirements.txt.sha256
  if [[ "${FORCE_UPDATES}" == "yes" || ! -f "${pip_requirements_chksum}" ]] || \
        ! sha256sum --quiet --check "${pip_requirements_chksum}"; then
    pip install --upgrade --force-reinstall -r "${pip_requirements}"
    sha256sum "${pip_requirements}" >"${pip_requirements_chksum}"
  fi

  if [ -z ${KOLLA_LOCAL_CHECKOUT+x} ]; then
    kolla_remote=https://github.com/chameleoncloud/kolla.git
    kolla_checkout="${KOLLA_BRANCH}"
    kolla_gitref="${VIRTUALENV}"/kolla.gitref
    kolla_egglink="${VIRTUALENV}"/src/kolla
    if [[ "${FORCE_UPDATES}" == "yes" || ! -f "${kolla_gitref}" || ! -d "${kolla_egglink}" ]] || \
          ! diff -q >/dev/null \
            "${kolla_gitref}" \
            <(cd "${kolla_egglink}"; git fetch; git show-ref -s -d origin/"${kolla_checkout}"); then
      pushd "${VIRTUALENV}" || ( echo "pushd error!" && exit 1 )
      pip install -e git+"${kolla_remote}"@"${kolla_checkout}"#egg=kolla
      popd || ( echo "popd error!" && exit 1 )
      (cd "${kolla_egglink}"; git rev-parse HEAD >"${kolla_gitref}")
    fi
  else
    pip install -e ${KOLLA_LOCAL_CHECKOUT}
  fi
fi

exec "$@"
