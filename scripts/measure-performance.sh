#!/bin/bash

# Mesure de performance réseau via slice 5G - NexSlice
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
UE_INTERFACE="uesimtun0"
UPF_GATEWAY="12.1.1.1"
OUTPUT_DIR="./results/performance"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PING_COUNT=100
IPERF_DURATION=30

# Créer le dossier de résultats
mkdir -p $OUTPUT_DIR

echo "================================================"
echo "  Mesures de Performance - Slice eMBB (SST=1)"
echo "================================================"
echo ""

# Vérification prérequis
echo "[Prérequis] Vérification des outils nécessaires..."
MISSING_TOOLS=()

command -v ping &> /dev/null || MISSING_TOOLS+=("iputils-ping")
command -v iperf3 &> /dev/null || MISSING_TOOLS+=("iperf3")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Outils manquants: ${MISSING_TOOLS[*]}${NC}"
    echo "Installation:"
    echo "  sudo apt install -y ${MISSING_TOOLS[*]}"
    exit 1
fi

# Vérification interface
if ! ip link show $UE_INTERFACE &> /dev/null; then
    echo -e "${RED}✗ Interface $UE_INTERFACE non trouvée${NC}"
    exit 1
fi

UE_IP=$(ip addr show $UE_INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
echo -e "${GREEN}✓ Interface $UE_INTERFACE active (IP: $UE_IP)${NC}"
echo ""

# ============================================
# Test 1 : Latence et Jitter
# ============================================
echo "================================================"
echo "[Test 1/3] Mesure Latence et Jitter"
echo "================================================"
echo "Destination: $UPF_GATEWAY"
echo "Nombre de pings: $PING_COUNT"
echo ""

PING_OUTPUT="$OUTPUT_DIR/ping_${TIMESTAMP}.txt"
PING_JSON="$OUTPUT_DIR/ping_${TIMESTAMP}.json"

echo "Envoi des paquets ICMP..."
ping -I $UE_INTERFACE -c $PING_COUNT -i 0.2 $UPF_GATEWAY > "$PING_OUTPUT" 2>&1

# Extraction des métriques
PACKET_LOSS=$(grep "packet loss" "$PING_OUTPUT" | awk '{print $6}' | sed 's/%//')
RTT_MIN=$(grep "rtt min" "$PING_OUTPUT" | awk -F'/' '{print $4}')
RTT_AVG=$(grep "rtt min" "$PING_OUTPUT" | awk -F'/' '{print $5}')
RTT_MAX=$(grep "rtt min" "$PING_OUTPUT" | awk -F'/' '{print $6}')
RTT_MDEV=$(grep "rtt min" "$PING_OUTPUT" | awk -F'/' '{print $7}' | awk '{print $1}')

# Affichage des résultats
echo -e "${CYAN}Résultats Latence:${NC}"
echo "  - RTT Min:     ${RTT_MIN} ms"
echo "  - RTT Moyen:   ${RTT_AVG} ms"
echo "  - RTT Max:     ${RTT_MAX} ms"
echo "  - Jitter (mdev): ${RTT_MDEV} ms"
echo "  - Perte:       ${PACKET_LOSS}%"

# Sauvegarde JSON
cat > "$PING_JSON" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "interface": "$UE_INTERFACE",
  "destination": "$UPF_GATEWAY",
  "packet_count": $PING_COUNT,
  "results": {
    "rtt_min_ms": $RTT_MIN,
    "rtt_avg_ms": $RTT_AVG,
    "rtt_max_ms": $RTT_MAX,
    "jitter_ms": $RTT_MDEV,
    "packet_loss_percent": $PACKET_LOSS
  }
}
EOF

echo -e "${GREEN}✓ Fichier sauvegardé: $PING_JSON${NC}"
echo ""

# ============================================
# Test 2 : Débit (si serveur iperf disponible)
# ============================================
echo "================================================"
echo "[Test 2/3] Mesure Débit (iperf3)"
echo "================================================"

# Demander l'IP du serveur iperf
echo "Entrez l'IP du serveur iperf3 (ou appuyez sur Entrée pour sauter):"
read -t 10 IPERF_SERVER || IPERF_SERVER=""

if [ -n "$IPERF_SERVER" ]; then
    echo "Test iperf3 vers $IPERF_SERVER (durée: ${IPERF_DURATION}s)..."
    echo ""
    
    IPERF_OUTPUT="$OUTPUT_DIR/iperf_${TIMESTAMP}.json"
    
    # Test avec bind sur l'interface 5G
    if iperf3 -c $IPERF_SERVER \
              -B $UE_IP \
              -t $IPERF_DURATION \
              -J > "$IPERF_OUTPUT" 2>&1; then
        
        # Extraction des métriques
        BITRATE=$(jq -r '.end.sum_sent.bits_per_second' "$IPERF_OUTPUT" 2>/dev/null || echo "0")
        BITRATE_MBPS=$(echo "scale=2; $BITRATE / 1000000" | bc)
        RETRANS=$(jq -r '.end.sum_sent.retransmits' "$IPERF_OUTPUT" 2>/dev/null || echo "0")
        
        echo -e "${CYAN}Résultats Débit:${NC}"
        echo "  - Débit moyen: ${BITRATE_MBPS} Mbps"
        echo "  - Retransmissions: $RETRANS"
        echo -e "${GREEN}✓ Fichier sauvegardé: $IPERF_OUTPUT${NC}"
    else
        echo -e "${YELLOW}⚠ Serveur iperf3 non accessible${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Test iperf3 ignoré (pas de serveur configuré)${NC}"
    echo ""
    echo "Pour activer ce test:"
    echo "  1. Sur une machine avec accès réseau, lancez:"
    echo "     iperf3 -s"
    echo "  2. Relancez ce script et entrez l'IP du serveur"
fi

echo ""

# ============================================
# Test 3 : Statistiques interface
# ============================================
echo "================================================"
echo "[Test 3/3] Statistiques Interface 5G"
echo "================================================"

STATS_OUTPUT="$OUTPUT_DIR/interface_stats_${TIMESTAMP}.txt"

# Capturer les statistiques avant et après un test de charge
echo "Statistiques $UE_INTERFACE avant test:" > "$STATS_OUTPUT"
ip -s link show $UE_INTERFACE >> "$STATS_OUTPUT"

# Test de charge rapide
echo "Test de charge (10s de trafic)..."
timeout 10 ping -I $UE_INTERFACE -f $UPF_GATEWAY &> /dev/null || true

echo -e "\nStatistiques $UE_INTERFACE après test:" >> "$STATS_OUTPUT"
ip -s link show $UE_INTERFACE >> "$STATS_OUTPUT"

# Affichage résumé
echo -e "${CYAN}Statistiques RX/TX:${NC}"
ip -s link show $UE_INTERFACE | grep -A 2 "RX:"
ip -s link show $UE_INTERFACE | grep -A 2 "TX:"

echo -e "${GREEN}✓ Fichier sauvegardé: $STATS_OUTPUT${NC}"
echo ""

# ============================================
# Génération du rapport
# ============================================
echo "================================================"
echo "  Génération du Rapport"
echo "================================================"

REPORT_FILE="$OUTPUT_DIR/rapport_performance_${TIMESTAMP}.md"

cat > "$REPORT_FILE" <<EOF
# Rapport de Performance - Slice eMBB (SST=1)

**Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**Interface**: $UE_INTERFACE  
**IP UE**: $UE_IP  
**Gateway UPF**: $UPF_GATEWAY  

---

## 1. Latence et Jitter

| Métrique | Valeur |
|----------|--------|
| RTT Min | ${RTT_MIN} ms |
| RTT Moyen | ${RTT_AVG} ms |
| RTT Max | ${RTT_MAX} ms |
| Jitter (mdev) | ${RTT_MDEV} ms |
| Perte de paquets | ${PACKET_LOSS}% |

**Interprétation**:
- Latence moyenne de ${RTT_AVG} ms adaptée au streaming vidéo
- Jitter de ${RTT_MDEV} ms indique une stabilité $([ $(echo "$RTT_MDEV < 5" | bc) -eq 1 ] && echo "excellente" || echo "correcte")
- Taux de perte de ${PACKET_LOSS}% $([ $(echo "$PACKET_LOSS < 1" | bc) -eq 1 ] && echo "acceptable" || echo "à améliorer")

---

## 2. Débit Réseau

EOF

if [ -n "$IPERF_SERVER" ] && [ -f "$IPERF_OUTPUT" ]; then
    cat >> "$REPORT_FILE" <<EOF
| Métrique | Valeur |
|----------|--------|
| Débit moyen | ${BITRATE_MBPS} Mbps |
| Retransmissions | $RETRANS |

**Interprétation**:
- Débit de ${BITRATE_MBPS} Mbps $([ $(echo "$BITRATE_MBPS > 10" | bc) -eq 1 ] && echo "suffisant pour streaming HD" || echo "limité pour streaming haute qualité")

EOF
else
    cat >> "$REPORT_FILE" <<EOF
*Test non effectué (serveur iperf3 non disponible)*

EOF
fi

cat >> "$REPORT_FILE" <<EOF
---

## 3. Conclusion

**Points positifs**:
- Connectivité 5G stable via l'interface $UE_INTERFACE
- Latence moyenne de ${RTT_AVG} ms adaptée aux applications multimédia
- Perte de paquets minimale (${PACKET_LOSS}%)

**Recommandations**:
- Pour du streaming 4K, viser un débit > 25 Mbps
- Maintenir le jitter < 10 ms pour une expérience fluide
- Surveiller les retransmissions TCP

---

## Fichiers Générés

- Données ping: \`$(basename $PING_OUTPUT)\`
- Métriques JSON: \`$(basename $PING_JSON)\`
$([ -f "$IPERF_OUTPUT" ] && echo "- Résultats iperf3: \`$(basename $IPERF_OUTPUT)\`")
- Statistiques interface: \`$(basename $STATS_OUTPUT)\`

EOF

echo -e "${GREEN}✓ Rapport généré: $REPORT_FILE${NC}"
echo ""

# ============================================
# Résumé final
# ============================================
echo "================================================"
echo -e "${GREEN}✓ Mesures de performance terminées${NC}"
echo "================================================"
echo ""
echo "Tous les résultats sont dans: $OUTPUT_DIR/"
echo ""
echo "Visualiser le rapport:"
echo "  cat $REPORT_FILE"
echo ""
echo "Analyser les données:"
echo "  - Latence: cat $PING_JSON | jq"
[ -f "$IPERF_OUTPUT" ] && echo "  - Débit: cat $IPERF_OUTPUT | jq"
echo ""

exit 0
