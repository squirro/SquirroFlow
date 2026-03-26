#!/bin/bash
# Deploy SquirroFlow to a remote server via SSH.
#
# This copies the deploy directory to the remote host and runs the management
# script. Follows the same pattern as the GenAI service deploy.sh.
#
# Usage:
#   ./deploy.sh <hostname>                    # Deploy (first time or update)
#   ./deploy.sh <hostname> restart            # Restart services
#   ./deploy.sh <hostname> stop               # Stop services
#   ./deploy.sh <hostname> status             # Show status
#   ORCH_WORKERS=3 SUB_WORKERS=8 ./deploy.sh <hostname>

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <hostname> [deploy|restart|stop|status]"
    exit 1
fi

HOST_NAME="$1"
COMMAND="${2:-deploy}"
DEPLOY_DIR="/opt/squirroflow"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Syncing deploy files to ${HOST_NAME}:${DEPLOY_DIR}..."
ssh "$HOST_NAME" "sudo mkdir -p ${DEPLOY_DIR} && sudo chown \$(whoami) ${DEPLOY_DIR}"
scp "${SCRIPT_DIR}/docker-compose.yml" \
    "${SCRIPT_DIR}/squirroflow.sh" \
    "${SCRIPT_DIR}/.env.example" \
    "${HOST_NAME}:${DEPLOY_DIR}/"
ssh "$HOST_NAME" "chmod +x ${DEPLOY_DIR}/squirroflow.sh"

# Pass worker counts through if set
WORKER_ENV=""
if [ -n "${ORCH_WORKERS:-}" ]; then
    WORKER_ENV="ORCH_WORKERS=${ORCH_WORKERS} "
fi
if [ -n "${SUB_WORKERS:-}" ]; then
    WORKER_ENV="${WORKER_ENV}SUB_WORKERS=${SUB_WORKERS} "
fi

echo "Running: squirroflow.sh ${COMMAND}"
ssh -t "$HOST_NAME" "cd ${DEPLOY_DIR} && ${WORKER_ENV}./squirroflow.sh ${COMMAND}"
