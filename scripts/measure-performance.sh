#!/bin/bash

# Mesure de performance réseau - NexSlice
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
UE_INTERFACE="uesimtun0"
UPF_GATEWAY="12.1.1.1"
OUTPUT_DIR="./results/performance"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PING_COUNT=100

mkdir -p $OUTPUT_DIR

echo "================================================"
echo "  Mesures de Performance - Slice eMBB"
echo "================================================"
echo ""

# Vérification
if ! ip link show $UE_INTERFACE &> /dev/null; then
    echo -e "${RED}✗ Interface $UE_INTERFACE non trouvée${NC}"
    exit 1
fi

UE_IP=$(ip addr show $UE_INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
echo -e "${GREEN}✓ Interface $UE_INTERFACE active (IP: $UE_IP)${NC}"
echo ""

# Test Latence
echo "[1/2] Mesure Latence et Jitter..."
PING_OUTPUT="$OUTPUT_DIR/ping_${TIMESTAMP}.txt"

ping -I $UE_INTERFACE -c $PING_COUNT $UPF_GATEWAY > "$PING_OUTPUT" 2>&1

# Extraction
PACKET_LOSS=$(grep "packet loss" "$PING_OUTPUT" | awk '{print $6}' | sed 's/%//')
RTT_AVG=$(grep "rtt min" "$PING_OUTPUT" | awk -F'/' '{print $5}')
RTT_MDEV=$(grep "rtt min" "$PING_OUTPUT" | awk -F'/' '{print $7}' | awk '{print $1}')

echo -e "${GREEN}Résultats:${NC}"
echo "  - Latence moyenne: ${RTT_AVG} ms"
echo "  - Jitter: ${RTT_MDEV} ms"
echo "  - Perte: ${PACKET_LOSS}%"
echo ""

# Statistiques interface
echo "[2/2] Statistiques Interface..."
STATS_OUTPUT="$OUTPUT_DIR/interface_stats_${TIMESTAMP}.txt"

ip -s link show $UE_INTERFACE > "$STATS_OUTPUT"
echo -e "${GREEN}✓ Statistiques sauvegardées${NC}"
echo ""

# Résumé
echo "================================================"
echo -e "${GREEN}✓ Mesures terminées${NC}"
echo "================================================"
echo ""
echo "Résultats dans: $OUTPUT_DIR/"
echo "  - Ping: $PING_OUTPUT"
echo "  - Stats: $STATS_OUTPUT"
echo ""

exit 0