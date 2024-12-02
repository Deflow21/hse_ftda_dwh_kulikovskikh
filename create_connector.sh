#!/bin/bash
# create_connector.sh

set -e

MAX_RETRIES=10
RETRY_DELAY=5

# Функция для создания коннектора
create_connector() {
  curl -s -X POST -H "Content-Type: application/json" --data @/connectors/postgres-connector.json http://debezium:8083/connectors
}

# Функция для удаления коннектора
delete_connector() {
  curl -s -X DELETE http://debezium:8083/connectors/postgres-connector
}

# Ожидание доступности Debezium Connect
for i in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $i: Checking if Debezium Connect is available..."
  if curl -s http://debezium:8083/ > /dev/null; then
    echo "Debezium Connect is available. Attempting to create connector..."
    RESPONSE=$(create_connector)
    if echo "$RESPONSE" | grep -q '"name": "postgres-connector"'; then
      echo "Connector created successfully."
      exit 0
    elif echo "$RESPONSE" | grep -q '"error_code":409'; then
      echo "Connector postgres-connector already exists. Deleting it..."
      delete_connector
      echo "Connector deleted successfully."
      echo "Attempting to create connector again..."
      RESPONSE=$(create_connector)
      if echo "$RESPONSE" | grep -q '"name": "postgres-connector"'; then
        echo "Connector created successfully."
        exit 0
      else
        echo "Failed to create connector after deletion. Response:"
        echo "$RESPONSE"
      fi
    else
      echo "Failed to create connector. Response:"
      echo "$RESPONSE"
    fi
  else
    echo "Debezium Connect is not ready yet. Waiting..."
  fi
  sleep $RETRY_DELAY
done

echo "Failed to create connector after $MAX_RETRIES attempts."
exit 1