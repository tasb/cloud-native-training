#!/bin/bash

while true; do
  curl -s http://training.metrics.local/api/items > /dev/null
  curl -s -X POST http://training.metrics.local/api/items \
    -H 'Content-Type: application/json' \
    -d '{"name":"Load test item","description":"generated"}' > /dev/null
  sleep 0.5
done