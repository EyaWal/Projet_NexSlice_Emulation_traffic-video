#!/bin/bash

# Nettoyage de la stack monitoring - NexSlice

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}Suppression de la stack de monitoring...${NC}"
echo ""

# Supprimer tous les déploiements
kubectl delete namespace monitoring --ignore-not-found

# Supprimer le dossier local
if [ -d "./monitoring" ]; then
    rm -rf ./monitoring
    echo -e "${GREEN}✓ Dossier monitoring/ supprimé${NC}"
fi

echo ""
echo -e "${GREEN}✓ Stack de monitoring supprimée${NC}"
echo ""

exit 0