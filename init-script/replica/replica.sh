#!/bin/bash
set -e
echo "Starting replica setup..."
pg_basebackup -h master -D ${PGDATA} -U postgres -vP -W --wal-method=stream
touch ${PGDATA}/standby.signal
echo "host replication all 0.0.0.0/0 md5" >> ${PGDATA}/pg_hba.conf
echo "primary_conninfo = 'host=master port=5432 user=postgres password=your_password'" >> ${PGDATA}/postgresql.conf