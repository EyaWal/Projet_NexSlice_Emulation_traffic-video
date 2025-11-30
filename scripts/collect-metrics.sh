#!/bin/bash

# Script de collecte de métriques pour le rapport NexSlice
# Usage: ./scripts/collect-metrics.sh

set -e

# --- Config --------------------------------------------

# Nom du pod UE (à adapter si besoin)
UE_POD="ueransim-ue1-ueransim-ues-64d67cf8bd-2zbls"
NAMESPACE="nexslice"
VIDEO_URL="http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4"
RESULTS_FILE="./metrics_results.txt"

# Commande kubectl (k3s dans ton cas)
KUBECTL="sudo k3s kubectl"

# -------------------------------------------------------

echo "Collecte des métriques NexSlice"
echo "Pod UE      : $UE_POD"
echo "Namespace   : $NAMESPACE"
echo "Fichier log : $RESULTS_FILE"
echo

# Fichier de résultats
{
  echo "============================================================"
  echo "RÉSULTATS DES MESURES - PROJET NEXSLICE"
  echo "============================================================"
  echo "Date    : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Pod UE  : $UE_POD"
  echo "============================================================"
  echo
} > "$RESULTS_FILE"

# 1. CONFIGURATION DU SLICE
echo "[1/6] Configuration du slice..."
{
  echo "1. CONFIGURATION DU SLICE"
  echo "------------------------------------------------------------"
  $KUBECTL logs -n "$NAMESPACE" "$UE_POD" 2>/dev/null \
    | grep -i "s-nssai\|sst\|sd" \
    | head -5
  echo
} >> "$RESULTS_FILE"

# 2. INTERFACE RÉSEAU
echo "[2/6] Interface réseau (uesimtun0)..."
{
  echo "2. INTERFACE RÉSEAU (uesimtun0)"
  echo "------------------------------------------------------------"
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    ip addr show uesimtun0 2>/dev/null | grep "inet "
  echo
} >> "$RESULTS_FILE"

# 3. TEST DE LATENCE (PING)
echo "[3/6] Latence (ping 100 paquets)..."
{
  echo "3. LATENCE (PING - 100 paquets)"
  echo "------------------------------------------------------------"
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    ping -I uesimtun0 -c 100 ffmpeg-server.nexslice.svc.cluster.local 2>/dev/null \
    | tail -2
  echo
} >> "$RESULTS_FILE"

# 4. DÉBIT (3 téléchargements)
echo "[4/6] Débit (3 téléchargements vidéo)..."
{
  echo "4. DÉBIT (TÉLÉCHARGEMENT VIDÉO - 3 essais)"
  echo "------------------------------------------------------------"
} >> "$RESULTS_FILE"

for i in 1 2 3; do
  echo "  Essai $i/3..."
  {
    echo "Essai $i :"
    $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- bash -c "
      rm -f /tmp/video_test.mp4
      START_TIME=\$(date +%s.%N)
      curl --interface uesimtun0 \
           -o /tmp/video_test.mp4 \
           --silent \
           $VIDEO_URL
      END_TIME=\$(date +%s.%N)

      DURATION=\$(echo \"\$END_TIME - \$START_TIME\" | bc)
      SIZE=\$(stat -f%z /tmp/video_test.mp4 2>/dev/null || stat -c%s /tmp/video_test.mp4)
      SIZE_MB=\$(echo \"scale=2; \$SIZE / 1048576\" | bc)
      THROUGHPUT=\$(echo \"scale=2; (\$SIZE * 8) / (\$DURATION * 1000000)\" | bc)

      echo \"  Durée : \${DURATION}s\"
      echo \"  Taille : \${SIZE_MB} MB\"
      echo \"  Débit : \${THROUGHPUT} Mbps\"
    " 2>/dev/null
    echo
  } >> "$RESULTS_FILE"
  sleep 2
done

# 5. STATISTIQUES RÉSEAU
echo "[5/6] Statistiques réseau (uesimtun0)..."
{
  echo "5. STATISTIQUES RÉSEAU (uesimtun0)"
  echo "------------------------------------------------------------"
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    cat /sys/class/net/uesimtun0/statistics/rx_bytes 2>/dev/null \
    | awk '{printf "Octets reçus   : %.2f MB\n", $1/1048576}'
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    cat /sys/class/net/uesimtun0/statistics/tx_bytes 2>/dev/null \
    | awk '{printf "Octets envoyés : %.2f MB\n", $1/1048576}'
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    cat /sys/class/net/uesimtun0/statistics/rx_packets 2>/dev/null \
    | awk '{print "Paquets reçus   :", $1}'
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    cat /sys/class/net/uesimtun0/statistics/tx_packets 2>/dev/null \
    | awk '{print "Paquets envoyés :", $1}'
  echo
} >> "$RESULTS_FILE"

# 6. INFORMATIONS SUR LA VIDÉO
echo "[6/6] Information fichier vidéo..."
{
  echo "6. FICHIER VIDÉO TÉLÉCHARGÉ"
  echo "------------------------------------------------------------"
  $KUBECTL exec -n "$NAMESPACE" "$UE_POD" -- \
    ls -lh /tmp/video_test.mp4 2>/dev/null || echo "Fichier non trouvé"
  echo
  echo "============================================================"
  echo "FIN DES MESURES"
  echo "============================================================"
  echo
} >> "$RESULTS_FILE"

echo
echo "✅ Collecte terminée."
echo "Fichier généré : $RESULTS_FILE"
echo
# Afficher un aperçu
sed -n '1,80p' "$RESULTS_FILE"
echo "..."
