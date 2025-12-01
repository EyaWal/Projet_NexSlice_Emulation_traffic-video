#!/bin/bash

# Test de streaming vidéo - Mode standalone (macOS)
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
VIDEO_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
OUTPUT_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

echo "================================================"
echo "  Test Streaming Vidéo (standalone macOS)"
echo "================================================"
echo ""

# 1. Vérification interface
echo "[1/3] Vérification interface réseau..."
if ! ifconfig "$UE_INTERFACE" >/dev/null 2>&1; then
    echo -e "${RED}✗ Interface $UE_INTERFACE non trouvée${NC}"
    echo "  Vérifiez avec: ifconfig"
    exit 1
fi
echo -e "${GREEN}✓ Interface $UE_INTERFACE détectée${NC}"

UE_IP=$(ifconfig "$UE_INTERFACE" | grep "inet " | awk '{print $2}')
if [ -n "$UE_IP" ]; then
    echo "  IP utilisée: $UE_IP"
else
    echo -e "${YELLOW}⚠ Impossible de récupérer l'IP sur $UE_INTERFACE${NC}"
fi
echo ""

# 2. Téléchargement vidéo
echo "[2/3] Téléchargement vidéo..."
OUTPUT_FILE="$OUTPUT_DIR/video_${TIMESTAMP}.mp4"
CURL_LOG="$OUTPUT_DIR/curl_metrics_${TIMESTAMP}.txt"

START_TIME=$(date +%s)

# On exécute curl et on récupère son code de retour via PIPESTATUS
curl --interface "$UE_INTERFACE" \
     --output "$OUTPUT_FILE" \
     --write-out "\nTemps total: %{time_total}s\nVitesse: %{speed_download} bytes/s\nCode HTTP: %{http_code}\n" \
     "$VIDEO_URL" 2>&1 | tee "$CURL_LOG"

CURL_EXIT=${PIPESTATUS[0]}  # code de retour de curl

if [ $CURL_EXIT -eq 0 ]; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))

    # du sur macOS fonctionne aussi
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    
    echo -e "${GREEN}✓ Téléchargement réussi${NC}"
    echo "  Temps: ${ELAPSED}s"
    echo "  Taille: $FILE_SIZE"
else
    echo -e "${RED}✗ Échec du téléchargement (code curl = $CURL_EXIT)${NC}"
    echo "  Voir les détails dans: $CURL_LOG"
    exit 1
fi
echo ""

# 3. Vérification / résumé
echo "[3/3] Vérification..."
echo "  Interface utilisée : $UE_INTERFACE"
[ -n "$UE_IP" ] && echo "  IP source (locale) : $UE_IP"
echo "  Fichier vidéo : $OUTPUT_FILE"
echo "  Log curl      : $CURL_LOG"
echo -e "${GREEN}✓ Test terminé${NC}"
echo ""

echo "Résultats dans: $OUTPUT_DIR/"
echo ""

exit 0
