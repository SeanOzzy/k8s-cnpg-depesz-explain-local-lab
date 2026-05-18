#!/usr/bin/env bash
set -euo pipefail

# These come from the Kubernetes Secret (injected as env vars in deployment.yaml)
: "${PG_HOST:?PG_HOST is required}"
: "${PG_PORT:=5432}"
: "${PG_DATABASE:?PG_DATABASE is required}"
: "${PG_USER:?PG_USER is required}"
: "${PG_PASSWORD:?PG_PASSWORD is required}"
: "${APP_SECRET:?APP_SECRET is required}"

# update the explain.json config file with the database connection info from env vars
echo "Writing /app/explain.json..."
cat > /app/explain.json <<EOF
{
    "title" : "explain.depesz.com",

    "secret" : "${APP_SECRET}",

    "database" : {
        "dsn"      : "dbi:Pg:database=${PG_DATABASE};host=${PG_HOST};port=${PG_PORT}",
        "username" : "${PG_USER}",
        "password" : "${PG_PASSWORD}",
        "options"  : {
            "auto_commit" : 1,
            "pg_server_prepare" : 0,
            "RaiseError" : 1,
            "PrintError" : 0
        }
    }
}
EOF

echo "Waiting for PostgreSQL at host ${PG_HOST} port ${PG_PORT} for user ${PG_USER}..."
until pg_isready -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" >/dev/null 2>&1; do
    sleep 2
done
echo "PostgreSQL ready."

export PGPASSWORD="${PG_PASSWORD}"

# Has the database already been created?
INITIALIZED=$(psql --host="${PG_HOST}" --port="${PG_PORT}" --username="${PG_USER}" \
    --dbname="${PG_DATABASE}" -tAc \
    "SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'plans'
    )")

# Create the database objects, not sure if this is the best way to do it but it works for now. For prod schema deployments Flyway or similar would be used.
if [ "${INITIALIZED}" = "f" ]; then
    echo "Initializing database schema..."
    for sql_file in /app/sql/create.sql /app/sql/patch-*.sql; do
        echo "  Applying $(basename "${sql_file}")..."
        psql --host="${PG_HOST}" --port="${PG_PORT}" --username="${PG_USER}" \
            --dbname="${PG_DATABASE}" -f "${sql_file}"
    done
    echo "Schema initialization complete."
else
    echo "Database schema already initialized, skipping."
fi

exec "$@"