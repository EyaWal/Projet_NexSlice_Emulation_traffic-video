#!/bin/bash

# Test de connectivité via le tunnel 5G - NexSlice
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
UE_INTERFACE="uesimtun0"
UPF_GATEWAY="12.1.1.1"
PING_COUNT=10

echo "================================================"
echo "  Test de Connectivité 5G - NexSlice"
echo "================================================"
echo ""

# 1. Vérification de l'interface tunnel
echo "[1/4] Vérification interface $UE_INTERFACE..."

if ! ip link show "$UE_INTERFACE" &> /dev/null; then
    echo -e "${RED}✗ Interface $UE_INTERFACE introuvable${NC}"
    echo "  Vérifiez que l'UE UERANSIM est bien lancé."
    exit 1
fi

echo -e "${GREEN}✓ Interface $UE_INTERFACE détectée${NC}"
echo -e "${YELLOW}Détails interface:${NC}"
ip addr show "$UE_INTERFACE" | grep -E "inet |link"
echo ""

# 2. Affichage de l'IP du UE
echo "[2/4] IP du UE..."
UE_IP=$(ip addr show "$UE_INTERFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
if [ -n "$UE_IP" ]; then
    echo -e "${GREEN}✓ IP du UE: ${UE_IP}${NC}"
else
    echo -e "${YELLOW}⚠ Impossible de récupérer l'IP sur $UE_INTERFACE${NC}"
fi
echo ""

# 3. Test ping vers l'UPF
echo "[3/4] Test ping vers l'UPF ($UPF_GATEWAY)..."
echo "    → Envoi de $PING_COUNT paquets ICMP via $UE_INTERFACE..."

PING_OUTPUT=$(ping -I "$UE_INTERFACE" -c "$PING_COUNT" -W 2 "$UPF_GATEWAY" 2>&1) || true

if echo "$PING_OUTPUT" | grep -q "packet loss"; then
    PACKET_LOSS=$(echo "$PING_OUTPUT" | grep "packet loss" | awk '{print $6}')
    RTT_LINE=$(echo "$PING_OUTPUT" | grep "rtt min" || true)

    echo -e "${GREEN}✓ Ping exécuté${NC}"
    echo -e "${GREEN}  Résumé:${NC}"
    echo "    - Perte de paquets : $PACKET_LOSS"
    if [ -n "$RTT_LINE" ]; then
        RTT_AVG=$(echo "$RTT_LINE" | awk -F'/' '{print $5}')
        echo "    - Latence moyenne : ${RTT_AVG} ms"
    fi

    # Considérer échec si 100% de perte
    if echo "$PACKET_LOSS" | grep -q "100%"; then
        echo -e "${RED}✗ Aucune réponse de l'UPF (100% de pertes)${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Échec du ping vers l'UPF${NC}"
    echo "$PING_OUTPUT"
    exit 1
fi
echo ""

# 4. Test de connectivité IP externe (optionnel)
echo "[4/4] Test de connectivité IP externe (8.8.8.8)..."
if ping -I "$UE_INTERFACE" -c 2 -W 2 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✓ Accès IP externe via le tunnel 5G${NC}"
else
    echo -e "${YELLOW}⚠ Pas d'accès IP externe (peut être normal si NAT non configuré)${NC}"
fi

# Résumé
echo ""
echo "================================================"
echo -e "${GREEN}✓ Tests de connectivité terminés${NC}"
echo "================================================"
echo ""
echo "Prochaine étape : tester le streaming vidéo :"
echo "  ./scripts/test-video-streaming.sh"
echo ""

exit 0
