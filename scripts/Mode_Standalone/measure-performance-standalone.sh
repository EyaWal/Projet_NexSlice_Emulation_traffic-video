#!/bin/bash

# Mesure de performance réseau - Mode standalone (macOS)
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration (adapter si besoin)
UE_INTERFACE="en0"
TARGET_HOST="8.8.8.8"        # Cible de test (latence Internet)
OUTPUT_DIR="./results/performance"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PING_COUNT=50

mkdir -p "$OUTPUT_DIR"

echo "================================================"
echo "  Mesures de Performance - Mode standalone macOS"
echo "================================================"
echo ""

# Vérification interface
echo "[0/2] Vérification interface réseau..."
if ! ifconfig "$UE_INTERFACE" >/dev/null 2>&1; then
    echo -e "${RED}✗ Interface $UE_INTERFACE non trouvée${NC}"
    echo "  Vérifiez avec: ifconfig"
    exit 1
fi

UE_IP=$(ifconfig "$UE_INTERFACE" | grep "inet " | awk '{print $2}')
echo -e "${GREEN}✓ Interface $UE_INTERFACE active (IP: $UE_IP)${NC}"
echo ""

# 1. Test Latence / Jitter / Perte
echo "[1/2] Mesure Latence et Jitter vers $TARGET_HOST..."
PING_OUTPUT="$OUTPUT_DIR/ping_${TIMESTAMP}.txt"

# ping macOS : pas de -I ici, on reste simple
ping -c "$PING_COUNT" "$TARGET_HOST" > "$PING_OUTPUT" 2>&1 || true

# Extraction packet loss
# Exemple macOS:
# 50 packets transmitted, 50 packets received, 0.0% packet loss
PACKET_LOSS_LINE=$(grep "packet loss" "$PING_OUTPUT" || true)
if [ -n "$PACKET_LOSS_LINE" ]; then
    PACKET_LOSS=$(echo "$PACKET_LOSS_LINE" | awk '{print $7}' | tr -d '%')
else
    PACKET_LOSS="N/A"
fi

# Extraction round-trip
# Exemple macOS:
# round-trip min/avg/max/stddev = 10.123/20.234/30.345/5.678 ms
RTT_LINE=$(grep "round-trip" "$PING_OUTPUT" || true)
RTT_AVG="N/A"
RTT_JITTER="N/A"

if [ -n "$RTT_LINE" ]; then
    RTT_AVG=$(echo "$RTT_LINE"   | awk -F'=' '{print $2}' | awk -F'/' '{print $2}')
    RTT_JITTER=$(echo "$RTT_LINE" | awk -F'=' '{print $2}' | awk -F'/' '{print $4}' | awk '{print $1}')
fi

echo -e "${GREEN}Résultats:${NC}"
echo "  - Cible testée      : $TARGET_HOST"
echo "  - Latence moyenne   : ${RTT_AVG} ms"
echo "  - Jitter (stddev)   : ${RTT_JITTER} ms"
echo "  - Perte de paquets  : ${PACKET_LOSS}%"
echo ""
echo "  Fichier brut ping : $PING_OUTPUT"
echo ""

# 2. Statistiques interface
echo "[2/2] Statistiques Interface..."
STATS_OUTPUT="$OUTPUT_DIR/interface_stats_${TIMESTAMP}.txt"

{
    echo "===== ifconfig $UE_INTERFACE ====="
    ifconfig "$UE_INTERFACE"
    echo ""
    echo "===== netstat -ibn (filtré sur $UE_INTERFACE) ====="
    netstat -ibn | grep "^$UE_INTERFACE"
} > "$STATS_OUTPUT"

echo -e "${GREEN}✓ Statistiques sauvegardées dans:${NC}"
echo "  - $STATS_OUTPUT"
echo ""

# Résumé
echo "================================================"
echo -e "${GREEN}✓ Mesures terminées${NC}"
echo "================================================"
echo ""
echo "Résultats dans: $OUTPUT_DIR/"
echo "  - Ping : $PING_OUTPUT"
echo "  - Stats: $STATS_OUTPUT"
echo ""

exit 0
