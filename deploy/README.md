# SquirroFlow Deployment

Two-stack queue mode deployment for SquirroFlow (Flowise) to prevent queue deadlock.

## Architecture

- **Orchestrator stack** (port 3000): Handles orchestrator chatflows that spawn sub-chatflows
- **Sub-chatflow stack** (port 3001): Handles leaf sub-chatflows only
- **PostgreSQL**: Shared database (replaces SQLite for concurrent access)
- **Redis x2**: Isolated queues per stack

With a single queue, orchestrator jobs hold worker slots while waiting for sub-chatflow
results, causing deadlock if all workers are occupied. Two stacks make deadlock impossible.

## Deploy to a remote server

```bash
# First deployment — clones source, builds images, starts services
./deploy.sh adcb-poc.squirro.cloud

# Then edit .env on the server:
ssh adcb-poc.squirro.cloud "vi ~/squirroflow/.env"

# Re-deploy (pulls latest source, rebuilds, restarts)
./deploy.sh adcb-poc.squirro.cloud

# Other commands
./deploy.sh adcb-poc.squirro.cloud restart    # Restart without rebuilding
./deploy.sh adcb-poc.squirro.cloud build      # Build images only
./deploy.sh adcb-poc.squirro.cloud stop       # Stop all services
./deploy.sh adcb-poc.squirro.cloud status     # Show service status

# Custom worker counts
ORCH_WORKERS=3 SUB_WORKERS=15 ./deploy.sh adcb-poc.squirro.cloud
```

## Run locally on the server

```bash
cd ~/squirroflow
cp .env.example .env
# Edit .env with your settings

./squirroflow.sh build        # Build images from source
./squirroflow.sh deploy       # Build + start (builds if source is available)
./squirroflow.sh restart      # Restart without rebuilding
./squirroflow.sh stop         # Stop
./squirroflow.sh status       # Status
```

## Building images

Images are built from SquirroFlow source using `deploy/Dockerfile` with multi-stage targets:

```bash
# From the SquirroFlow source directory:
docker build --target main -t squirroflow:latest -f deploy-Dockerfile .
docker build --target worker -t squirroflow-worker:latest -f deploy-Dockerfile .
```

The `squirroflow.sh build` and `squirroflow.sh deploy` commands handle this automatically.
Source is expected at `../squirroflow-src` relative to the deploy directory, or set
`SQUIRROFLOW_SRC` to override.

## Post-deploy configuration

Update the orchestrator chatflow's "Agent as Tool" nodes in the Flowise UI:
- Change Base URL from `http://squirroflow-main:3000` to `http://squirroflow-sub-main:3001`

## Monitoring

- Orchestrator BullMQ Dashboard: `http://<host>:3000/admin/queues`
- Sub-chatflow BullMQ Dashboard: `http://<host>:3001/admin/queues`
