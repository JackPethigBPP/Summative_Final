# Summative_Final

# Cafe DevOps Demo (Python, Flask, PostgreSQL)

A simple multi-tab web application for a cafe with **Cashier** and **Barista** views.
Orders are stored in **PostgreSQL**. Includes a small JSON API for CI integration tests
and a Docker Compose setup for local development.

## Features
- Cashier tab: create orders (name, drink, size, notes)
- Barista tab: view queue and update status (NEW → IN_PROGRESS → DONE)
- PostgreSQL persistence using SQLAlchemy
- JSON API: create/list/update orders
- Docker Compose for local development
- Environment-driven configuration (`DATABASE_URL`)

## Quick Start (Local without Docker)
1. Ensure PostgreSQL is running locally and create a database (e.g., `cafe_dev`).
2. Copy `.env.example` to `.env` and set `DATABASE_URL` accordingly, e.g.
   ```env
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/cafe_dev
   FLASK_ENV=development
   FLASK_DEBUG=1
   ```
3. Create and activate a Python virtual environment.
4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
5. Initialize the database tables (auto-created on first run)
6. Run the app:
   ```bash
   python run.py
   ```
7. Visit `http://localhost:5000/cashier` and `http://localhost:5000/barista`.

## Quick Start (Docker Compose)
1. Copy `.env.example` to `.env`. The compose file expects variables for the DB container.
2. Start services:
   ```bash
   docker compose up --build
   ```
3. App is available at `http://localhost:5000`.

## API Endpoints
- `POST /api/orders` → `{ customer_name, drink, size, notes }`
- `GET /api/orders?status=NEW|IN_PROGRESS|DONE`
- `PATCH /api/orders/<id>` → `{ status }`

## Testing
```bash
pip install -r requirements.txt
pytest -q
```

## Next Steps (for your DevOps assessment)
- Add CI (tests, lint, SAST) and CD (Terraform + cloud deploy) pipelines.
- Replace Docker Compose DB with a managed service (e.g., AWS RDS Postgres) via IaC.
- Add observability (structured logs, metrics, dashboards).
- Implement secrets management and stricter IAM if deploying to cloud.