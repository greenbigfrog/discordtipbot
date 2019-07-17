#!/bin/sh
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c 'CREATE DATABASE tipbot'

if [ -f "/dump.sql" ]
then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname tipbot -f /dump.sql
else
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname tipbot -f /schema.sql
fi
