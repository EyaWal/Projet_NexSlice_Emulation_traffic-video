#!/bin/bash

# Vérification stack monitoring - NexSlice

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Vérification de la stack de monitoring..."
echo ""

# Check namespace
if kubectl get namespace monitoring &> /dev/null; then
    echo -e "${GREEN}✓ Namespace monitoring existe${NC}"
else
    echo -e "${RED}✗ Namespace monitoring manquant${NC}"
    exit 1
fi

# Check pods
for pod in prometheus pushgateway grafana; do
    if kubectl get pods -n monitoring | grep -q "$pod.*Running"; then
        echo -e "${GREEN}✓ $pod est actif${NC}"
    else
        echo -e "${RED}✗ $pod n'est pas actif${NC}"
    fi
done

echo ""
echo "URLs des services:"
echo "  Prometheus:  http://localhost:30090"
echo "  Pushgateway: http://localhost:30091"
echo "  Grafana:     http://localhost:30300"
echo ""

exit 0