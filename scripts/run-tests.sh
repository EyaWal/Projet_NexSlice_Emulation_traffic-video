#!/bin/bash
UE_POD="${1:-ueransim-ue1-ueransim-ues-64d67cf8bd-2zbls}"

echo "=== Tests NexSlice ==="
./scripts/test-connectivity.sh $UE_POD
./scripts/collect-metrics.sh
