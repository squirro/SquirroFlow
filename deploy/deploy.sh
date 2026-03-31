#!/bin/bash
# Deploy SquirroFlow to a remote server via SSH.
#
# This copies the deploy files to the remote host, ensures the source repo
# is cloned, builds Docker images from source, and starts the services.
#
# Usage:
#   ./deploy.sh <hostname>                    # Deploy (first time or update)
#   ./deploy.sh <hostname> restart            # Restart services
#   ./deploy.sh <hostname> stop               # Stop services
#   ./deploy.sh <hostname> status             # Show status
#   ./deploy.sh <hostname> build              # Build images only
#   ORCH_WORKERS=3 SUB_WORKERS=8 ./deploy.sh <hostname>

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <hostname> [build|deploy|restart|stop|status]"
    exit 1
fi

HOST_NAME="$1"
COMMAND="${2:-deploy}"
DEPLOY_DIR="${SQUIRROFLOW_DEPLOY_DIR:-/home/\$(whoami)/squirroflow}"
SRC_DIR="${SQUIRROFLOW_SRC_DIR:-/home/\$(whoami)/squirroflow-src}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve remote paths once
REMOTE_DEPLOY_DIR=$(ssh "$HOST_NAME" "eval echo ${DEPLOY_DIR}")
REMOTE_SRC_DIR=$(ssh "$HOST_NAME" "eval echo ${SRC_DIR}")

echo "Syncing deploy files to ${HOST_NAME}:${REMOTE_DEPLOY_DIR}..."
ssh "$HOST_NAME" "mkdir -p ${REMOTE_DEPLOY_DIR}"
scp "${SCRIPT_DIR}/docker-compose.yml" \
    "${SCRIPT_DIR}/squirroflow.sh" \
    "${SCRIPT_DIR}/.env.example" \
    "${SCRIPT_DIR}/Dockerfile" \
    "${HOST_NAME}:${REMOTE_DEPLOY_DIR}/"
ssh "$HOST_NAME" "chmod +x ${REMOTE_DEPLOY_DIR}/squirroflow.sh"
ssh "$HOST_NAME" "if [ ! -d ${REMOTE_SRC_DIR} ]; then echo 'Cloning SquirroFlow source...'; git clone https://github.com/squirro/SquirroFlow.git ${REMOTE_SRC_DIR}; else echo 'Updating SquirroFlow source...'; cd ${REMOTE_SRC_DIR} && git pull; fi"

# Pass worker counts and source dir through
EXTRA_ENV="SQUIRROFLOW_SRC=${REMOTE_SRC_DIR} "
if [ -n "${ORCH_WORKERS:-}" ]; then
    EXTRA_ENV="${EXTRA_ENV}ORCH_WORKERS=${ORCH_WORKERS} "
fi
if [ -n "${SUB_WORKERS:-}" ]; then
    EXTRA_ENV="${EXTRA_ENV}SUB_WORKERS=${SUB_WORKERS} "
fi

echo "Running: squirroflow.sh ${COMMAND}"
ssh -t "$HOST_NAME" "cd ${REMOTE_DEPLOY_DIR} && ${EXTRA_ENV}./squirroflow.sh ${COMMAND}"
