#!/bin/bash

## Shell Opts ----------------------------------------------------------------

set -euv
set -o pipefail

## Vars ----------------------------------------------------------------------

# These vars are set by the CI environment, but are given defaults
# here to cater for situations where someone is executing the test
# outside of the CI environment.
export RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"

## Functions -----------------------------------------------------------------
source ../../scripts/functions.sh

## Main ----------------------------------------------------------------------

# Copy the tempest results to the job results folder
mkdir -p ${RE_HOOK_RESULT_DIR}

# Copy the job artifacts to the job artifacts folder
export RSYNC_CMD="rsync --archive --safe-links --ignore-errors --quiet --no-perms --no-owner --no-group"
export RSYNC_ETC_CMD="${RSYNC_CMD} --no-links --exclude selinux/"

echo "#### BEGIN LOG COLLECTION ###"
mkdir -vp \
    "${RE_HOOK_ARTIFACT_DIR}/logs/host" \
    "${RE_HOOK_ARTIFACT_DIR}/logs/openstack" \
    "${RE_HOOK_ARTIFACT_DIR}/etc/host" \
    "${RE_HOOK_ARTIFACT_DIR}/etc/openstack" \
    "${RE_HOOK_ARTIFACT_DIR}/kibana"

# Copy the host and container log files
${RSYNC_CMD} /var/log/ "${RE_HOOK_ARTIFACT_DIR}/logs/host" || true
if [ -d "/openstack/log" ]; then
  ${RSYNC_CMD} /openstack/log/ "${RE_HOOK_ARTIFACT_DIR}/logs/openstack" || true
fi

# Copy the host /etc directory
${RSYNC_ETC_CMD} /etc/ "${RE_HOOK_ARTIFACT_DIR}/etc/host/" || true

# Loop over each container and archive its /etc directory
if which lxc-ls &> /dev/null; then
  for CONTAINER_NAME in `lxc-ls -1`; do
    CONTAINER_PID=$(lxc-info -p -n ${CONTAINER_NAME} | awk '{print $2}')
    CONTAINER_ROOT_DIR="/proc/${CONTAINER_PID}/root/"
    CONTAINER_ETC_DIR="${CONTAINER_ROOT_DIR}/etc/"
    if echo ${CONTAINER_NAME} | grep "utility"; then
      find "${CONTAINER_ROOT_DIR}" -type f -name 'tempest_results.xml' -exec cp {} ${RE_HOOK_RESULT_DIR}/ \;
    fi
    ${RSYNC_ETC_CMD} ${CONTAINER_ETC_DIR} "${RE_HOOK_ARTIFACT_DIR}/etc/openstack/${CONTAINER_NAME}/" || true
  done
fi
echo "#### END LOG COLLECTION ###"
