#!/bin/bash

# Nettoyage de la stack de monitoring
# NexSlice Project

# Couleurs
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  Suppression de la stack de monitoring...${NC}"
echo ""

read -p "Êtes-vous sûr de vouloir supprimer Prometheus, Grafana et Pushgateway? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

echo "Suppression en cours..."

kubectl delete namespace monitoring --ignore-not-found=true

echo ""
echo -e "${RED}✓ Stack de monitoring supprimée${NC}"

exit 0