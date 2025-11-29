#!/bin/bash

# Vérification de la stack de monitoring
# NexSlice Project

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Vérification de la stack de monitoring..."
echo ""

# Vérifier le namespace
if ! kubectl get namespace monitoring &> /dev/null; then
    echo -e "${RED}✗ Namespace monitoring introuvable${NC}"
    echo "Lancez: ./scripts/monitoring/setup-monitoring.sh"
    exit 1
fi

echo -e "${GREEN}✓ Namespace monitoring existe${NC}"

# Vérifier les pods
PODS=("prometheus" "pushgateway" "grafana")
ALL_READY=true

for pod in "${PODS[@]}"; do
    if kubectl get pods -n monitoring -l app=$pod | grep -q "Running"; then
        echo -e "${GREEN}✓ $pod est actif${NC}"
    else
        echo -e "${RED}✗ $pod n'est pas prêt${NC}"
        ALL_READY=false
    fi
done

if [ "$ALL_READY" = false ]; then
    echo ""
    echo -e "${YELLOW}Certains pods ne sont pas prêts. Vérifiez avec:${NC}"
    echo "kubectl get pods -n monitoring"
    exit 1
fi

echo ""
echo "🌐 URLs des services:"
echo -e "  • Prometheus:  ${GREEN}http://localhost:30090${NC}"
echo -e "  • Pushgateway: ${GREEN}http://localhost:30091${NC}"
echo -e "  • Grafana:     ${GREEN}http://localhost:30300${NC}"
echo ""

# Tester la connectivité
echo "🔌 Test de connectivité..."

if curl -s http://localhost:30090/-/healthy > /dev/null; then
    echo -e "${GREEN}✓ Prometheus accessible${NC}"
else
    echo -e "${RED}✗ Prometheus non accessible${NC}"
fi

if curl -s http://localhost:30091/metrics > /dev/null; then
    echo -e "${GREEN}✓ Pushgateway accessible${NC}"
else
    echo -e "${RED}✗ Pushgateway non accessible${NC}"
fi

if curl -s http://localhost:30300/api/health > /dev/null; then
    echo -e "${GREEN}✓ Grafana accessible${NC}"
else
    echo -e "${RED}✗ Grafana non accessible${NC}"
fi

echo ""
echo -e "${GREEN}✓ Stack de monitoring opérationnelle${NC}"

exit 0