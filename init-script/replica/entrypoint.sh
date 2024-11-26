#!/bin/bash
set -e

echo "Waiting for master to be ready..."
until gosu postgres pg_isready -h postgres_master -p 5432 -U replicator -d postgres; do
  sleep 1
done

echo "Cloning master data..."
rm -rf ${PGDATA:?}/*
gosu postgres pg_basebackup -h postgres_master -D ${PGDATA} -U replicator -vP --wal-method=stream

echo "Adjusting permissions on data directory..."
gosu postgres chmod 700 ${PGDATA}

echo "Copying configuration files..."
gosu postgres cp /etc/postgresql/postgresql.conf ${PGDATA}/postgresql.conf
gosu postgres cp /etc/postgresql/pg_hba.conf ${PGDATA}/pg_hba.conf

echo "Creating standby signal file..."
gosu postgres touch ${PGDATA}/standby.signal

echo "Starting slave..."
exec gosu postgres postgres