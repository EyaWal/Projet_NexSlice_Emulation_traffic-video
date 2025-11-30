#!/bin/bash

# Setup Monitoring Stack - Prometheus + Grafana + Pushgateway
# NexSlice Project - Groupe 4
# VERSION SIMPLIFIÉE (sans système d'alertes)

set -e

# Couleurs (optionnel, mais ça rend la sortie plus lisible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Installation Stack Monitoring - NexSlice${NC}"
echo -e "${CYAN}  Prometheus + Grafana + Pushgateway${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

# Dossier des manifestes (à la racine du repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../../monitoring"

if [ ! -d "$MANIFESTS_DIR" ]; then
    echo -e "${RED}✗ Dossier monitoring/ introuvable (${MANIFESTS_DIR})${NC}"
    echo "  → Vérifiez que les fichiers YAML sont bien dans ./monitoring"
    exit 1
fi

# ============================================
# 1. Créer (ou garder) le namespace monitoring
# ============================================
echo -e "${BOLD}[1/3] Création du namespace monitoring...${NC}"

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1

echo -e "${GREEN}✓ Namespace monitoring OK${NC}"
echo ""

# ============================================
# 2. Appliquer les manifestes Prometheus / Pushgateway / Grafana
# ============================================
echo -e "${BOLD}[2/3] Déploiement des composants de monitoring...${NC}"

# Prometheus
if [ -f "$MANIFESTS_DIR/prometheus-config.yaml" ] && [ -f "$MANIFESTS_DIR/prometheus-deployment.yaml" ]; then
    kubectl apply -f "$MANIFESTS_DIR/prometheus-config.yaml"
    kubectl apply -f "$MANIFESTS_DIR/prometheus-deployment.yaml"
    echo -e "${GREEN}✓ Prometheus déployé${NC}"
else
    echo -e "${YELLOW}⚠ Fichiers Prometheus manquants dans monitoring/${NC}"
fi

# Pushgateway
if [ -f "$MANIFESTS_DIR/pushgateway-deployment.yaml" ]; then
    kubectl apply -f "$MANIFESTS_DIR/pushgateway-deployment.yaml"
    echo -e "${GREEN}✓ Pushgateway déployé${NC}"
else
    echo -e "${YELLOW}⚠ Fichier pushgateway-deployment.yaml manquant${NC}"
fi

# Grafana
if [ -f "$MANIFESTS_DIR/grafana-datasource.yaml" ]; then
    kubectl apply -f "$MANIFESTS_DIR/grafana-datasource.yaml"
fi

if [ -f "$MANIFESTS_DIR/grafana-deployment.yaml" ]; then
    kubectl apply -f "$MANIFESTS_DIR/grafana-deployment.yaml"
    echo -e "${GREEN}✓ Grafana déployé${NC}"
else
    echo -e "${YELLOW}⚠ Fichier grafana-deployment.yaml manquant${NC}"
fi

echo ""

# ============================================
# 3. Attendre que les pods soient prêts
# ============================================
echo -e "${BOLD}[3/3] Attente du démarrage des pods...${NC}"

# On attend seulement si les ressources existent
if kubectl get pods -n monitoring 2>/dev/null | grep -q prometheus; then
    echo -n "  Prometheus:  "
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s || true
    echo ""
fi

if kubectl get pods -n monitoring 2>/dev/null | grep -q pushgateway; then
    echo -n "  Pushgateway: "
    kubectl wait --for=condition=ready pod -l app=pushgateway -n monitoring --timeout=120s || true
    echo ""
fi

if kubectl get pods -n monitoring 2>/dev/null | grep -q grafana; then
    echo -n "  Grafana:     "
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=120s || true
    echo ""
fi

echo ""
echo -e "${GREEN}✓ Stack de monitoring déployée (sans alerting)${NC}"
echo ""

echo -e "${BOLD}Accès aux interfaces:${NC}"
echo -e "  • Prometheus:  ${CYAN}http://localhost:30090${NC}"
echo -e "  • Pushgateway: ${CYAN}http://localhost:30091${NC}"
echo -e "  • Grafana:     ${CYAN}http://localhost:30300${NC}"
echo ""
echo -e "${BOLD}Identifiants Grafana (par défaut):${NC}"
echo -e "  user: ${YELLOW}admin${NC}"
echo -e "  pass: ${YELLOW}admin${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} pas de système d'alertes, surveiller manuellement les métriques dans Grafana."
echo ""

exit 0
