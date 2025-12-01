#!/bin/bash

# Test de connectivité (mode standalone / macOS)
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration (adapter si besoin)
UE_INTERFACE="en0"
UPF_GATEWAY="10.42.21.17"
PING_COUNT=10

echo "================================================"
echo "  Test de Connectivité 5G - NexSlice (standalone macOS)"
echo "================================================"
echo ""

# 1. Vérification de l'interface
echo "[1/4] Vérification interface $UE_INTERFACE..."

if ! ifconfig "$UE_INTERFACE" >/dev/null 2>&1; then
    echo -e "${RED}✗ Interface $UE_INTERFACE introuvable${NC}"
    echo "  Vérifiez avec: ifconfig"
    exit 1
fi

echo -e "${GREEN}✓ Interface $UE_INTERFACE détectée${NC}"
echo -e "${YELLOW}Détails interface:${NC}"
ifconfig "$UE_INTERFACE" | grep -E "inet |ether"
echo ""

# 2. IP locale
echo "[2/4] IP du UE (interface locale)..."
UE_IP=$(ifconfig "$UE_INTERFACE" | grep "inet " | awk '{print $2}')
if [ -n "$UE_IP" ]; then
    echo -e "${GREEN}✓ IP du UE: ${UE_IP}${NC}"
else
    echo -e "${YELLOW}⚠ Impossible de récupérer l'IP sur $UE_INTERFACE${NC}"
fi
echo ""

# 3. Ping vers la gateway (équivalent UPF en mode local)
echo "[3/4] Test ping vers la gateway ($UPF_GATEWAY)..."
echo "    → Envoi de $PING_COUNT paquets ICMP..."

# On n'utilise pas -I sur macOS en mode standalone
PING_OUTPUT=$(ping -c "$PING_COUNT" "$UPF_GATEWAY" 2>&1 || true)

echo "$PING_OUTPUT"
echo ""

if echo "$PING_OUTPUT" | grep -q "packet loss"; then
    # Exemple macOS :
    # 10 packets transmitted, 10 packets received, 0.0% packet loss
    PACKET_LOSS=$(echo "$PING_OUTPUT" | grep "packet loss" | awk '{print $7}')

    # Exemple macOS :
    # round-trip min/avg/max/stddev = 10.123/20.234/30.345/5.678 ms
    RTT_LINE=$(echo "$PING_OUTPUT" | grep "round-trip" || true)

    echo -e "${GREEN}  Résumé ping:${NC}"
    echo "    - Perte de paquets : $PACKET_LOSS"
    if [ -n "$RTT_LINE" ]; then
        RTT_AVG=$(echo "$RTT_LINE" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}' | awk '{print $1}')
        echo "    - Latence moyenne : ${RTT_AVG} ms"
    fi

    if echo "$PACKET_LOSS" | grep -q "100%"; then
        echo -e "${YELLOW}⚠ 100% de pertes vers la gateway${NC}"
        echo "  → En mode standalone, on continue quand même."
    else
        echo -e "${GREEN}✓ Connectivité vers la gateway OK (au moins partielle)${NC}"
    fi
else
    echo -e "${RED}✗ Ping vers la gateway impossible${NC}"
    echo "  Sortie ping brute ci-dessus."
    echo "  → Vérifiez que la gateway $UPF_GATEWAY est joignable."
fi
echo ""

# 4. Test IP externe (simple)
echo "[4/4] Test de connectivité IP externe (8.8.8.8)..."
if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Accès IP externe OK${NC}"
else
    echo -e "${YELLOW}⚠ Pas d'accès IP externe (peut dépendre de votre réseau)${NC}"
fi

# Résumé
echo ""
echo "================================================"
echo -e "${GREEN}✓ Script de connectivité terminé${NC}"
echo "================================================"
echo ""
echo "Prochaine étape : tester le streaming vidéo :"
echo "  ./scripts/test-video-streaming.sh"
echo ""

exit 0
