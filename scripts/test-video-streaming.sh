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
# URL du serveur vidéo FFmpeg déployé sur Kubernetes
VIDEO_URL="http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4"
OUTPUT_DIR="./results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Configuration Prometheus (optionnel)
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:30091}"
MONITORING_ENABLED=false

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

# Fonction pour exporter vers Prometheus
export_to_prometheus() {
    if [ "$MONITORING_ENABLED" = true ]; then
        local metric_name=$1
        local metric_value=$2
        local ue_ip=$3
        
        curl --silent --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/nexslice_streaming/ue_ip/${ue_ip}/slice_type/embb" <<EOF
# TYPE ${metric_name} gauge
${metric_name} ${metric_value}
EOF
    fi
}

# Vérifier si Pushgateway est accessible
if curl -s "${PUSHGATEWAY_URL}/metrics" > /dev/null 2>&1; then
    MONITORING_ENABLED=true
    echo -e "${GREEN}✓ Stack de monitoring détectée${NC}"
else
    echo -e "${YELLOW}⚠ Stack de monitoring non disponible (métriques non exportées)${NC}"
fi
echo ""

# 1. Vérification interface
echo "[1/5] Vérification interface 5G..."
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
echo "[2/5] Téléchargement vidéo via tunnel 5G..."
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
    echo ""
    echo "Vérifications à effectuer:"
    echo "  1. Le serveur vidéo est-il déployé ?"
    echo "     kubectl get pods -n nexslice | grep ffmpeg-server"
    echo ""
    echo "  2. La vidéo est-elle accessible ?"
    echo "     kubectl exec -n nexslice ffmpeg-server -- ls -lh /var/www/html/videos/"
    echo ""
    echo "  3. Le service est-il actif ?"
    echo "     kubectl get svc -n nexslice | grep ffmpeg-server"
    echo ""
    exit 1
fi

echo ""

# 3. Export vers Prometheus (si monitoring actif)
echo "[3/5] Export des métriques vers Prometheus..."
if [ "$MONITORING_ENABLED" = true ]; then
    # Export du temps de téléchargement
    if [ -n "$TOTAL_TIME" ]; then
        export_to_prometheus "nexslice_download_time_seconds" "$TOTAL_TIME" "$UE_IP"
    fi
    
    # Export du débit
    if [ -n "$DEBIT_MBPS" ]; then
        export_to_prometheus "nexslice_throughput_mbps" "$DEBIT_MBPS" "$UE_IP"
    fi
    
    # Export de la taille téléchargée
    if [ -n "$TOTAL_BYTES" ]; then
        SIZE_MB=$(echo "scale=2; $TOTAL_BYTES / 1048576" | bc)
        export_to_prometheus "nexslice_download_size_mb" "$SIZE_MB" "$UE_IP"
    fi
    
    echo -e "${GREEN}✓ Métriques exportées vers Prometheus${NC}"
    echo "  Endpoint: ${PUSHGATEWAY_URL}/metrics"
else
    echo -e "${YELLOW}⚠ Export ignoré (monitoring non disponible)${NC}"
fi

echo ""

# 4. Capture réseau (optionnel - nécessite sudo)
echo "[4/5] Capture réseau (optionnel)..."
if [ "$EUID" -eq 0 ]; then
    echo "Lancement capture tcpdump pendant 10s..."
    CAPTURE_FILE="$OUTPUT_DIR/captures/capture_${TIMESTAMP}.pcap"
    mkdir -p "$OUTPUT_DIR/captures"
    
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
    echo -e "${YELLOW}⚠ Capture tcpdump nécessite les droits root (ignoré)${NC}"
    echo "  Note: Avec le monitoring Prometheus/Grafana, la capture tcpdump est optionnelle"
fi

echo ""

# 5. Vérification du routage
echo "[5/5] Vérification du routage via UPF..."

# Extraction de l'IP destination
DEST_IP=$(kubectl get svc -n nexslice ffmpeg-server -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "N/A")

echo "  IP source (UE): $UE_IP"
echo "  IP destination (service): $DEST_IP"
echo "  Gateway UPF: 12.1.1.1"

# Vérifier la route
if [ "$DEST_IP" != "N/A" ]; then
    ROUTE=$(ip route get $DEST_IP 2>/dev/null || echo "")
    if echo "$ROUTE" | grep -q "$UE_INTERFACE"; then
        echo -e "${GREEN}✓ Trafic routé via le tunnel 5G${NC}"
    else
        echo -e "${YELLOW}⚠ Route non confirmée via $UE_INTERFACE${NC}"
    fi
else
    echo -e "${YELLOW}⚠ IP destination non récupérable${NC}"
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
if [ "$MONITORING_ENABLED" = true ]; then
    echo "Consultation des métriques:"
    echo "  • Grafana: http://localhost:30300"
    echo "  • Prometheus: http://localhost:30090"
    echo ""
fi

echo "Analyse locale des résultats:"
echo "  1. Métriques réseau:"
echo "     cat $CURL_LOG"
echo ""
if [ -f "$CAPTURE_FILE" ]; then
    echo "  2. Analyse capture (optionnel):"
    echo "     tcpdump -r $CAPTURE_FILE -nn | head -20"
    echo ""
fi

exit 0