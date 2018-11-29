#!/bin/sh
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c 'CREATE USER docker'
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c 'CREATE DATABASE dogecoin'
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c 'GRANT ALL PRIVILEGES ON DATABASE dogecoin TO docker'
if [ -f "/dump.sql" ]
then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname dogecoin -f /dump.sql
else
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname dogecoin -f /schema.sql
fi

# Copy and modify above to initialize more databases for the various coins
