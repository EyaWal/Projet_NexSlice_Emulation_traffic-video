#!/bin/bash

# Test de streaming vidéo via tunnel 5G - NexSlice
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
UE_INTERFACE="uesimtun0"
VIDEO_URL="http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4"
OUTPUT_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $OUTPUT_DIR

echo "================================================"
echo "  Test Streaming Vidéo via Slice 5G (SST=1)"
echo "================================================"
echo ""

# 1. Vérification interface
echo "[1/3] Vérification interface 5G..."
if ! ip link show $UE_INTERFACE &> /dev/null; then
    echo -e "${RED}✗ Interface $UE_INTERFACE non trouvée${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Interface $UE_INTERFACE active${NC}"

UE_IP=$(ip addr show $UE_INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
echo "  IP du UE: $UE_IP"
echo ""

# 2. Téléchargement vidéo
echo "[2/3] Téléchargement vidéo..."
OUTPUT_FILE="$OUTPUT_DIR/video_${TIMESTAMP}.mp4"
CURL_LOG="$OUTPUT_DIR/curl_metrics_${TIMESTAMP}.txt"

START_TIME=$(date +%s)

curl --interface $UE_INTERFACE \
     --output "$OUTPUT_FILE" \
     --write-out "\nTemps total: %{time_total}s\nVitesse: %{speed_download} bytes/s\nCode HTTP: %{http_code}\n" \
     "$VIDEO_URL" 2>&1 | tee "$CURL_LOG"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    
    echo -e "${GREEN}✓ Téléchargement réussi${NC}"
    echo "  Temps: ${ELAPSED}s"
    echo "  Taille: $FILE_SIZE"
else
    echo -e "${RED}✗ Échec du téléchargement${NC}"
    exit 1
fi
echo ""

# 3. Vérification
echo "[3/3] Vérification..."
echo "  IP source: $UE_IP"
echo "  Fichier: $OUTPUT_FILE"
echo -e "${GREEN}✓ Test terminé${NC}"
echo ""

echo "Résultats dans: $OUTPUT_DIR/"
echo ""

exit 0