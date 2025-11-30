#!/bin/bash

# Test de streaming vidéo via tunnel 5G - NexSlice
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
UE_INTERFACE="uesimtun0"
VIDEO_URL="http://video-server.nexslice.svc.cluster.local/BigBuckBunny.mp4"
OUTPUT_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Créer le dossier de résultats
mkdir -p $OUTPUT_DIR

echo "================================================"
echo "  Test Streaming Vidéo via Slice 5G (SST=1)"
echo "================================================"
echo ""

# Fonction pour afficher le temps écoulé
show_elapsed_time() {
    START=$1
    END=$(date +%s)
    ELAPSED=$((END - START))
    echo -e "${BLUE}Temps écoulé: ${ELAPSED}s${NC}"
}

# 1. Vérification interface
echo "[1/4] Vérification interface 5G..."
if ! ip link show $UE_INTERFACE &> /dev/null; then
    echo -e "${RED}✗ Interface $UE_INTERFACE non trouvée${NC}"
    echo "Lancez d'abord: ./scripts/test-connectivity.sh"
    exit 1
fi
echo -e "${GREEN}✓ Interface $UE_INTERFACE active${NC}"

# Récupérer l'IP du UE
UE_IP=$(ip addr show $UE_INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
echo "  IP du UE: $UE_IP"
echo ""

# 2. Test de téléchargement avec métriques
echo "[2/4] Téléchargement vidéo via tunnel 5G..."
echo "  URL: $VIDEO_URL"
echo "  Interface: $UE_INTERFACE"
echo ""

OUTPUT_FILE="$OUTPUT_DIR/video_${TIMESTAMP}.mp4"
CURL_LOG="$OUTPUT_DIR/curl_metrics_${TIMESTAMP}.txt"

START_TIME=$(date +%s)

# Téléchargement avec métriques détaillées
curl --interface $UE_INTERFACE \
     --output "$OUTPUT_FILE" \
     --write-out "\n=== Métriques de Téléchargement ===\n\
Temps total: %{time_total}s\n\
Temps connexion: %{time_connect}s\n\
Temps démarrage transfert: %{time_starttransfer}s\n\
Vitesse download: %{speed_download} bytes/s\n\
Taille téléchargée: %{size_download} bytes\n\
Code HTTP: %{http_code}\n\
IP source: $UE_IP\n\
================================\n" \
     "$VIDEO_URL" 2>&1 | tee "$CURL_LOG"

DOWNLOAD_STATUS=${PIPESTATUS[0]}

if [ $DOWNLOAD_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓ Téléchargement réussi${NC}"
    show_elapsed_time $START_TIME
    
    # Taille du fichier
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "  Taille fichier: $FILE_SIZE"
    
    # Calcul du débit moyen
    TOTAL_TIME=$(grep "Temps total:" "$CURL_LOG" | awk '{print $3}' | sed 's/s//')
    TOTAL_BYTES=$(grep "Taille téléchargée:" "$CURL_LOG" | awk '{print $3}')
    
    if [ -n "$TOTAL_TIME" ] && [ -n "$TOTAL_BYTES" ]; then
        DEBIT_MBPS=$(echo "scale=2; ($TOTAL_BYTES * 8) / ($TOTAL_TIME * 1000000)" | bc)
        echo -e "${GREEN}  Débit moyen: ${DEBIT_MBPS} Mbps${NC}"
    fi
else
    echo -e "${RED}✗ Échec du téléchargement${NC}"
    exit 1
fi

echo ""

# 3. Capture réseau (optionnel - nécessite sudo)
echo "[3/4] Capture réseau (optionnel)..."
if [ "$EUID" -eq 0 ]; then
    echo "Lancement capture tcpdump pendant 10s..."
    CAPTURE_FILE="$OUTPUT_DIR/capture_${TIMESTAMP}.pcap"
    
    timeout 10 tcpdump -i $UE_INTERFACE -w "$CAPTURE_FILE" &> /dev/null &
    TCPDUMP_PID=$!
    
    # Test rapide de streaming
    curl --interface $UE_INTERFACE --max-time 8 -s -o /dev/null "$VIDEO_URL" || true
    
    wait $TCPDUMP_PID 2>/dev/null || true
    
    if [ -f "$CAPTURE_FILE" ]; then
        PACKETS=$(tcpdump -r "$CAPTURE_FILE" 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ Capture terminée: $PACKETS paquets${NC}"
        echo "  Fichier: $CAPTURE_FILE"
    fi
else
    echo -e "${YELLOW}⚠ Capture tcpdump nécessite les droits root${NC}"
    echo "  Relancez avec: sudo ./scripts/test-video-streaming.sh"
fi

echo ""

# 4. Vérification du routage
echo "[4/4] Vérification du routage via UPF..."

# Extraction de l'IP destination depuis les logs curl
DEST_IP=$(grep -oP '\d+\.\d+\.\d+\.\d+' "$CURL_LOG" | head -1 || echo "N/A")

echo "  IP source (UE): $UE_IP"
echo "  IP destination: $DEST_IP"
echo "  Gateway UPF: 12.1.1.1"

# Vérifier la route
ROUTE=$(ip route get $DEST_IP 2>/dev/null || echo "")
if echo "$ROUTE" | grep -q "$UE_INTERFACE"; then
    echo -e "${GREEN}✓ Trafic routé via le tunnel 5G${NC}"
else
    echo -e "${YELLOW}⚠ Route non confirmée via $UE_INTERFACE${NC}"
fi

# Résumé
echo ""
echo "================================================"
echo -e "${GREEN}✓ Test de streaming terminé avec succès${NC}"
echo "================================================"
echo ""
echo "Résultats sauvegardés dans: $OUTPUT_DIR/"
echo ""
echo "Fichiers générés:"
echo "  - Vidéo téléchargée: $OUTPUT_FILE"
echo "  - Métriques curl: $CURL_LOG"
[ -f "$CAPTURE_FILE" ] && echo "  - Capture réseau: $CAPTURE_FILE"
echo ""

# Recommandations d'analyse
echo "Pour analyser les résultats:"
echo "  1. Métriques réseau:"
echo "     cat $CURL_LOG"
echo ""
if [ -f "$CAPTURE_FILE" ]; then
    echo "  2. Analyse capture (nécessite Wireshark):"
    echo "     wireshark $CAPTURE_FILE"
    echo ""
    echo "  3. Statistiques paquets:"
    echo "     tcpdump -r $CAPTURE_FILE -nn | head -20"
    echo ""
fi

exit 0
