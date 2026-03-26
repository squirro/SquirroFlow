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
# First deployment
./deploy.sh adcb-poc.squirro.cloud

# Then edit .env on the server:
ssh adcb-poc.squirro.cloud "vi /opt/squirroflow/.env"

# Re-deploy with the updated config
./deploy.sh adcb-poc.squirro.cloud

# Other commands
./deploy.sh adcb-poc.squirro.cloud restart
./deploy.sh adcb-poc.squirro.cloud stop
./deploy.sh adcb-poc.squirro.cloud status

# Custom worker counts
ORCH_WORKERS=3 SUB_WORKERS=15 ./deploy.sh adcb-poc.squirro.cloud
```

## Run locally on the server

```bash
cd /opt/squirroflow
cp .env.example .env
# Edit .env with your settings
./squirroflow.sh              # Deploy
./squirroflow.sh restart      # Restart
./squirroflow.sh stop         # Stop
./squirroflow.sh status       # Status
```

## Post-deploy configuration

Update the orchestrator chatflow's "Agent as Tool" nodes in the Flowise UI:
- Change Base URL from `http://squirroflow-main:3000` to `http://squirroflow-sub-main:3001`

## Monitoring

- Orchestrator BullMQ Dashboard: `http://<host>:3000/admin/queues`
- Sub-chatflow BullMQ Dashboard: `http://<host>:3001/admin/queues`
