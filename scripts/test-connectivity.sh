#!/bin/bash

# Test de connectivité via le tunnel 5G - NexSlice
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
UE_INTERFACE="uesimtun0"
UPF_GATEWAY="12.1.1.1"
UE_IP="12.1.1.2"
PING_COUNT=10

echo "================================================"
echo "  Test de Connectivité 5G - NexSlice"
echo "================================================"
echo ""

# Fonction de vérification
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        return 0
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}

# 1. Vérification de l'interface tunnel
echo "[1/5] Vérification interface $UE_INTERFACE..."
if ip link show $UE_INTERFACE &> /dev/null; then
    check_status "Interface $UE_INTERFACE existe"
    
    # Afficher les détails
    echo -e "${YELLOW}Détails interface:${NC}"
    ip addr show $UE_INTERFACE | grep -E "inet |link"
else
    check_status "Interface $UE_INTERFACE existe"
    echo -e "${RED}❌ L'interface $UE_INTERFACE n'existe pas${NC}"
    echo "Vérifiez que UERANSIM UE est bien lancé:"
    echo "  kubectl logs -n nexslice <ue-pod-name>"
    exit 1
fi

# 2. Vérification de l'IP du UE
echo ""
echo "[2/5] Vérification IP du UE..."
ACTUAL_IP=$(ip addr show $UE_INTERFACE | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
if [ "$ACTUAL_IP" == "$UE_IP" ]; then
    check_status "IP UE correcte: $UE_IP"
else
    echo -e "${YELLOW}⚠ IP différente: $ACTUAL_IP (attendue: $UE_IP)${NC}"
fi

# 3. Vérification de la route par défaut
echo ""
echo "[3/5] Vérification routing via UPF..."
if ip route | grep -q $UE_INTERFACE; then
    check_status "Route configurée via $UE_INTERFACE"
    echo -e "${YELLOW}Routes actives:${NC}"
    ip route | grep $UE_INTERFACE
else
    echo -e "${YELLOW}⚠ Pas de route par défaut via $UE_INTERFACE${NC}"
fi

# 4. Test ping vers UPF Gateway
echo ""
echo "[4/5] Test ping vers UPF Gateway ($UPF_GATEWAY)..."
echo "Envoi de $PING_COUNT paquets ICMP..."

PING_OUTPUT=$(ping -I $UE_INTERFACE -c $PING_COUNT -W 2 $UPF_GATEWAY 2>&1)
PING_STATUS=$?

if [ $PING_STATUS -eq 0 ]; then
    check_status "Connectivité 5G vers UPF"
    
    # Extraction des statistiques
    RTT_AVG=$(echo "$PING_OUTPUT" | grep "rtt min" | awk -F'/' '{print $5}')
    PACKET_LOSS=$(echo "$PING_OUTPUT" | grep "packet loss" | awk '{print $6}')
    
    echo -e "${GREEN}Statistiques:${NC}"
    echo "  - Latence moyenne: ${RTT_AVG} ms"
    echo "  - Perte de paquets: ${PACKET_LOSS}"
else
    check_status "Connectivité 5G vers UPF"
    echo -e "${RED}Échec du ping. Vérifiez:${NC}"
    echo "  1. Le Core 5G OAI est actif (kubectl get pods -n nexslice)"
    echo "  2. L'UPF est déployé et opérationnel"
    echo "  3. Le gNB UERANSIM est connecté au Core"
    exit 1
fi

# 5. Test DNS (optionnel si configuré)
echo ""
echo "[5/5] Test résolution DNS..."
if ping -I $UE_INTERFACE -c 2 -W 2 8.8.8.8 &> /dev/null; then
    check_status "Accès Internet via tunnel 5G"
else
    echo -e "${YELLOW}⚠ Pas d'accès Internet (normal si NAT non configuré)${NC}"
fi

# Résumé
echo ""
echo "================================================"
echo -e "${GREEN}✓ Tests de connectivité terminés avec succès${NC}"
echo "================================================"
echo ""
echo "Prochaine étape: Tester le streaming vidéo"
echo "  ./scripts/test-video-streaming.sh"
echo ""

exit 0