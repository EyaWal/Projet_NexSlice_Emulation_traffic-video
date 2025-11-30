#!/bin/bash

# Suite complète de tests - NexSlice
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "    NexSlice - Suite de Tests Complète"
echo "================================================"
echo ""

# Vérifier que les scripts existent
if [ ! -f "./scripts/test-connectivity.sh" ]; then
    echo -e "${RED}✗ Scripts manquants dans ./scripts/${NC}"
    exit 1
fi

# Test 1 : Connectivité
echo -e "${YELLOW}[1/3] Test de connectivité 5G...${NC}"
./scripts/test-connectivity.sh
echo ""

# Test 2 : Streaming vidéo
echo -e "${YELLOW}[2/3] Test de streaming vidéo...${NC}"
sudo ./scripts/test-video-streaming.sh
echo ""

# Test 3 : Performance
echo -e "${YELLOW}[3/3] Mesures de performance...${NC}"
./scripts/measure-performance.sh
echo ""

# Résumé
echo "================================================"
echo -e "${GREEN}✓ Tous les tests terminés${NC}"
echo "================================================"
echo ""
echo "Résultats dans: ./results/"
echo ""

exit 0