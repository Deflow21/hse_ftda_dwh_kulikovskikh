#!/bin/bash
set -e
echo "Starting replica setup..."
pg_basebackup -h master -D ${PGDATA} -U postgres -vP -W --wal-method=stream
touch ${PGDATA}/standby.signal
echo "host replication all 0.0.0.0/0 md5" >> ${PGDATA}/pg_hba.conf
echo "primary_conninfo = 'host=postgres_master port=5432 user=replicator password=replicator_password application_name=postgres_slave'" >> ${PGDATA}/postgresql.conf