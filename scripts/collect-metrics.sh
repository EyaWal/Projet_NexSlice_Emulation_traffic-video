#!/bin/bash

# Script de collecte de métriques pour le rapport
# Usage: ./collect-metrics.sh

echo "═══════════════════════════════════════════════════════════════"
echo "     Collecte des Métriques - Projet NexSlice"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Variables
UE_POD="ueransim-ue1-ueransim-ues-64d67cf8bd-2zbls"
NAMESPACE="nexslice"
VIDEO_URL="http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4"
RESULTS_FILE="metrics_results.txt"

echo "Pod UE utilisé : $UE_POD"
echo "Résultats seront sauvegardés dans : $RESULTS_FILE"
echo ""

# Créer le fichier de résultats
cat > $RESULTS_FILE << EOF
═══════════════════════════════════════════════════════════════
RÉSULTATS DES MESURES - PROJET NEXSLICE
═══════════════════════════════════════════════════════════════
Date : $(date '+%Y-%m-%d %H:%M:%S')
Pod UE : $UE_POD
═══════════════════════════════════════════════════════════════

EOF

# 1. CONFIGURATION DU SLICE
echo "1️⃣  Collecte de la configuration du slice..."
echo "" >> $RESULTS_FILE
echo "1. CONFIGURATION DU SLICE" >> $RESULTS_FILE
echo "─────────────────────────────────────────────────────────────" >> $RESULTS_FILE
sudo k3s kubectl logs -n $NAMESPACE $UE_POD 2>/dev/null | grep -i "s-nssai\|sst\|sd" | head -5 >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# 2. INTERFACE RÉSEAU
echo "2️⃣  Collecte des informations d'interface..."
echo "2. INTERFACE RÉSEAU (uesimtun0)" >> $RESULTS_FILE
echo "─────────────────────────────────────────────────────────────" >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- ip addr show uesimtun0 2>/dev/null | grep "inet " >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# 3. TEST DE LATENCE (PING)
echo "3️⃣  Mesure de la latence (ping)..."
echo "3. LATENCE (PING - 100 paquets)" >> $RESULTS_FILE
echo "─────────────────────────────────────────────────────────────" >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- \
  ping -I uesimtun0 -c 100 ffmpeg-server.nexslice.svc.cluster.local 2>/dev/null | \
  tail -2 >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# 4. TÉLÉCHARGEMENT AVEC MESURE DU TEMPS (3 essais)
echo "4️⃣  Mesure du débit (3 téléchargements)..."
echo "4. DÉBIT (TÉLÉCHARGEMENT VIDÉO - 3 essais)" >> $RESULTS_FILE
echo "─────────────────────────────────────────────────────────────" >> $RESULTS_FILE

for i in 1 2 3; do
    echo "   Essai $i/3..."
    echo "Essai $i :" >> $RESULTS_FILE
    
    sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- bash -c "
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
        
        echo \"  Durée: \${DURATION}s\"
        echo \"  Taille: \${SIZE_MB} MB\"
        echo \"  Débit: \${THROUGHPUT} Mbps\"
    " 2>/dev/null >> $RESULTS_FILE
    
    echo "" >> $RESULTS_FILE
    sleep 2
done

# 5. STATISTIQUES RÉSEAU
echo "5️⃣  Collecte des statistiques réseau..."
echo "5. STATISTIQUES RÉSEAU (uesimtun0)" >> $RESULTS_FILE
echo "─────────────────────────────────────────────────────────────" >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- \
  cat /sys/class/net/uesimtun0/statistics/rx_bytes 2>/dev/null | \
  awk '{printf "Octets reçus: %.2f MB\n", $1/1048576}' >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- \
  cat /sys/class/net/uesimtun0/statistics/tx_bytes 2>/dev/null | \
  awk '{printf "Octets envoyés: %.2f MB\n", $1/1048576}' >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- \
  cat /sys/class/net/uesimtun0/statistics/rx_packets 2>/dev/null | \
  awk '{print "Paquets reçus:", $1}' >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- \
  cat /sys/class/net/uesimtun0/statistics/tx_packets 2>/dev/null | \
  awk '{print "Paquets envoyés:", $1}' >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# 6. INFORMATIONS SUR LA VIDÉO
echo "6️⃣  Informations sur le fichier vidéo..."
echo "6. FICHIER VIDÉO TÉLÉCHARGÉ" >> $RESULTS_FILE
echo "─────────────────────────────────────────────────────────────" >> $RESULTS_FILE
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- \
  ls -lh /tmp/video_test.mp4 2>/dev/null >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Fin
cat >> $RESULTS_FILE << EOF
═══════════════════════════════════════════════════════════════
FIN DES MESURES
═══════════════════════════════════════════════════════════════

COMMENT UTILISER CES RÉSULTATS :

1. Latence Moyenne : Extraire de la ligne "rtt min/avg/max/mdev"
   → Utilisez la valeur "avg" pour votre tableau

2. Débit Moyen : Faire la moyenne des 3 essais
   → Reportez dans votre README_ACADEMIQUE.md

3. Configuration Slice : Notez le SST et SD
   → Documentez dans la section Architecture

PROCHAINES ÉTAPES :
- Générer les graphiques avec ces données
- Compléter le README_ACADEMIQUE.md
- Ajouter ces résultats dans vos tableaux
EOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Collecte terminée !"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Résultats sauvegardés dans : $RESULTS_FILE"
echo ""
echo "Affichage du fichier :"
echo "─────────────────────────────────────────────────────────────"
cat $RESULTS_FILE
echo ""
echo "💡 Utilisez ces données pour compléter votre README académique !"
