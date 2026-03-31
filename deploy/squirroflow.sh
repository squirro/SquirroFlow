#!/bin/bash
# Manage the SquirroFlow two-stack queue mode deployment.
#
# Orchestrator stack: handles orchestrator chatflows (port 3000)
# Sub-chatflow stack: handles leaf sub-chatflows (port 3001)
#
# Usage:
#   ./squirroflow.sh                                  # Deploy with default workers
#   ./squirroflow.sh restart                          # Restart existing services
#   ./squirroflow.sh stop                             # Stop all services
#   ./squirroflow.sh status                           # Show service status
#   ORCH_WORKERS=3 SUB_WORKERS=8 ./squirroflow.sh    # Custom worker counts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

COMMAND="${1:-deploy}"
ORCH_WORKERS="${ORCH_WORKERS:-5}"
SUB_WORKERS="${SUB_WORKERS:-10}"
SRC_DIR="${SQUIRROFLOW_SRC:-${SCRIPT_DIR}/../squirroflow-src}"

# --- Helper functions ---

ensure_compose() {
    if docker compose version &>/dev/null; then
        return
    fi
    echo "Docker compose plugin not found. Installing..."
    mkdir -p ~/.docker/cli-plugins
    ARCH=$(uname -m)
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
        -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    echo "Installed docker compose $(docker compose version --short)"
}

ensure_env() {
    if [ ! -f .env ]; then
        echo "No .env file found. Copying from .env.example..."
        cp .env.example .env
        echo "Created .env — review it and re-run."
        exit 1
    fi
}

ensure_volume() {
    if ! docker volume inspect squirroflow_data &>/dev/null; then
        echo "Creating squirroflow_data volume..."
        docker volume create squirroflow_data
    fi
}

health_check() {
    echo ""
    echo "Waiting for services to start..."
    sleep 15

    echo ""
    docker compose ps

    echo ""
    echo "Health checks:"
    ORCH_PORT=$(grep -E '^ORCH_PORT=' .env 2>/dev/null | cut -d= -f2 || echo '3000')
    SUB_PORT=$(grep -E '^SUB_PORT=' .env 2>/dev/null | cut -d= -f2 || echo '3001')

    curl -sf "http://localhost:${ORCH_PORT:-3000}/api/v1/ping" && echo " <- Orchestrator stack OK" || echo " <- Orchestrator stack not ready"
    curl -sf "http://localhost:${SUB_PORT:-3001}/api/v1/ping" && echo " <- Sub-chatflow stack OK" || echo " <- Sub-chatflow stack not ready"

    echo ""
    echo "Orchestrator UI:          http://localhost:${ORCH_PORT:-3000}"
    echo "Orchestrator BullMQ:      http://localhost:${ORCH_PORT:-3000}/admin/queues"
    echo "Sub-chatflow UI:          http://localhost:${SUB_PORT:-3001}"
    echo "Sub-chatflow BullMQ:      http://localhost:${SUB_PORT:-3001}/admin/queues"
    echo ""
    echo "Orchestrator workers:     ${ORCH_WORKERS}"
    echo "Sub-chatflow workers:     ${SUB_WORKERS}"
    echo ""
    echo "IMPORTANT: Update 'Agent as Tool' Base URLs in the orchestrator chatflow"
    echo "           from http://squirroflow-main:3000 to http://squirroflow-sub-main:${SUB_PORT:-3001}"
}

# --- Commands ---

case "$COMMAND" in
    deploy)
        ensure_compose
        ensure_env
        ensure_volume

        # Build images if source is available
        if [ -d "$SRC_DIR" ]; then
            echo "Building images from source..."
            cp "${SCRIPT_DIR}/Dockerfile" "${SRC_DIR}/deploy-Dockerfile"
            cd "$SRC_DIR"
            docker build --target main -t squirroflow:latest -f deploy-Dockerfile .
            docker build --target worker -t squirroflow-worker:latest -f deploy-Dockerfile .
            cd "$SCRIPT_DIR"
        fi

        echo "Deploying SquirroFlow two-stack: ${ORCH_WORKERS} orchestrator + ${SUB_WORKERS} sub-chatflow workers..."
        docker compose up -d \
            --scale squirroflow-orch-worker="${ORCH_WORKERS}" \
            --scale squirroflow-sub-worker="${SUB_WORKERS}"
        health_check
        ;;

    restart)
        ensure_env
        echo "Restarting SquirroFlow services..."
        docker compose up -d \
            --scale squirroflow-orch-worker="${ORCH_WORKERS}" \
            --scale squirroflow-sub-worker="${SUB_WORKERS}"
        health_check
        ;;

    stop)
        echo "Stopping all SquirroFlow services..."
        docker compose down
        echo "Stopped."
        ;;

    status)
        docker compose ps
        echo ""
        echo "=== Orchestrator worker activity ==="
        for i in $(docker ps --format '{{.Names}}' | grep squirroflow-orch-worker | sort); do
            echo "--- $i ---"
            docker logs "$i" --tail 3 2>&1 | grep -E 'Processing|Completed|Error|Worker created' || true
        done
        echo ""
        echo "=== Sub-chatflow worker activity ==="
        for i in $(docker ps --format '{{.Names}}' | grep squirroflow-sub-worker | sort); do
            echo "--- $i ---"
            docker logs "$i" --tail 3 2>&1 | grep -E 'Processing|Completed|Error|Worker created' || true
        done
        ;;

    build)
        if [ ! -d "$SRC_DIR" ]; then
            echo "Source directory not found: $SRC_DIR"
            echo "Clone the repo first: git clone https://github.com/squirro/SquirroFlow.git $SRC_DIR"
            exit 1
        fi

        echo "Building SquirroFlow images from $SRC_DIR..."
        cp "${SCRIPT_DIR}/Dockerfile" "${SRC_DIR}/deploy-Dockerfile"
        cd "$SRC_DIR"
        docker build --target main -t squirroflow:latest -f deploy-Dockerfile .
        docker build --target worker -t squirroflow-worker:latest -f deploy-Dockerfile .
        echo "Built squirroflow:latest and squirroflow-worker:latest"
        ;;

    *)
        echo "Usage: $0 [build|deploy|restart|stop|status]"
        echo ""
        echo "Commands:"
        echo "  build    Build Docker images from source"
        echo "  deploy   Build images (if source available) and start services"
        echo "  restart  Restart existing services"
        echo "  stop     Stop all services"
        echo "  status   Show service status"
        echo ""
        echo "Environment variables:"
        echo "  ORCH_WORKERS       Orchestrator worker count (default: 5)"
        echo "  SUB_WORKERS        Sub-chatflow worker count (default: 10)"
        echo "  SQUIRROFLOW_SRC    Path to SquirroFlow source (default: ../squirroflow-src)"
        exit 1
        ;;
esac
