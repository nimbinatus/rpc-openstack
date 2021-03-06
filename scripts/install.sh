#!/usr/bin/env bash
# Copyright 2014-2017, Rackspace US, Inc.
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

## Shell Opts ----------------------------------------------------------------
set -euv
set -o pipefail

## Vars ----------------------------------------------------------------------
export OSA_RELEASE="${OSA_RELEASE:-stable/pike}"
export SCRIPT_PATH="$(readlink -f $(dirname ${0}))"

## Functions -----------------------------------------------------------------

## Main ----------------------------------------------------------------------

# If /opt/openstack-ansible exists, delete it if it is not a git clone
if [[ -d "/opt/openstack-ansible" ]] && [[ ! -d "/opt/openstack-ansible/.git" ]]; then
  rm -rf /opt/openstack-ansible
fi

# Git clone the openstack-ansible repository
if [[ ! -d "/opt/openstack-ansible" ]]; then
  git clone https://git.openstack.org/openstack/openstack-ansible /opt/openstack-ansible
fi

pushd "/opt/openstack-ansible"
  # Check if the current SHA does not match the desired SHA
  if [[ "$(git rev-parse HEAD)" != "${OSA_RELEASE}" ]]; then

    # If the SHA we want does not exist in the git repo, update the repo
    if ! git cat-file -e ${OSA_RELEASE} 2> /dev/null; then
      git fetch --all
    fi

    # Now checkout the correct SHA
    git checkout "${OSA_RELEASE}"
  fi
popd

# Setup the basic OSA configuration structure.
if [[ ! -d "/etc/openstack_deploy" ]]; then
  cp -Rv /opt/openstack-ansible/etc/openstack_deploy /etc/openstack_deploy
fi

# Sync the RPC-OpenStack variables into place.
rsync -av \
      --exclude '*.bak' \
      "${SCRIPT_PATH}/../etc/openstack_deploy/" \
      /etc/openstack_deploy/

# Pre-boostrap ansible so that we have the option to run RPC-OpenStack playbooks
#  if we need during the pre-installation setup.
pushd /opt/openstack-ansible
  bash -c "scripts/bootstrap-ansible.sh"
popd

# Get RPC Ansible roles.
ansible-playbook /opt/openstack-ansible/tests/get-ansible-role-requirements.yml \
                 -i /opt/openstack-ansible/tests/test-inventory.ini \
                 -e role_file="${SCRIPT_PATH}/../ansible-role-requirements.yml" \
                 -vvv
