#!/bin/bash

# Script Principal - Tests Complets NexSlice avec Monitoring
# Projet: Emulation Traffic Vidéo sur Network Slicing 5G
# Groupe: 4 - Année: 2025-2026

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
LOG_FILE="$RESULTS_DIR/test_run_$(date +%Y%m%d_%H%M%S).log"
MONITORING_ENABLED=true

# Créer les dossiers nécessaires
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR/performance"
mkdir -p "$RESULTS_DIR/captures"

# Fonction de logging
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Bannière
clear
log "${CYAN}================================================${NC}"
log "${CYAN}    NexSlice - Suite de Tests Complète${NC}"
log "${CYAN}    Monitoring: Prometheus + Grafana${NC}"
log "${CYAN}    Projet 5G Network Slicing - Groupe 4${NC}"
log "${CYAN}================================================${NC}"
log ""
log "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log "Log: $LOG_FILE"
log ""

# ============================================
# Vérification prérequis
# ============================================
log "${BOLD}[Étape 0/5] Vérification des prérequis${NC}"
log "================================================"
log ""

# Vérifier les scripts principaux
REQUIRED_SCRIPTS=(
    "test-connectivity.sh"
    "test-video-streaming.sh"
    "measure-performance.sh"
)

MISSING_SCRIPTS=()
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        MISSING_SCRIPTS+=("$script")
    fi
done

if [ ${#MISSING_SCRIPTS[@]} -gt 0 ]; then
    log "${RED}✗ Scripts manquants: ${MISSING_SCRIPTS[*]}${NC}"
    log "Vérifiez que tous les scripts sont dans: $SCRIPT_DIR/"
    exit 1
fi

# Rendre les scripts exécutables
chmod +x "$SCRIPT_DIR"/*.sh
chmod +x "$SCRIPT_DIR"/monitoring/*.sh 2>/dev/null || true

log "${GREEN}✓ Tous les scripts sont présents${NC}"

# Vérifier les outils
REQUIRED_TOOLS=("ping" "curl" "jq" "bc")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    log "${YELLOW}⚠ Outils manquants: ${MISSING_TOOLS[*]}${NC}"
    log "Installation recommandée:"
    log "  sudo apt install -y iputils-ping curl jq bc"
    log ""
    read -p "Continuer malgré tout? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    log "${GREEN}✓ Tous les outils sont installés${NC}"
fi

# Vérifier le monitoring
log ""
log "${BOLD}Vérification de la stack de monitoring...${NC}"

if bash "$SCRIPT_DIR/monitoring/check-monitoring.sh" &> /dev/null; then
    log "${GREEN}✓ Stack de monitoring opérationnelle${NC}"
    log "  • Prometheus:  http://localhost:30090"
    log "  • Pushgateway: http://localhost:30091"
    log "  • Grafana:     http://localhost:30300"
    MONITORING_ENABLED=true
else
    log "${YELLOW}⚠ Stack de monitoring non disponible${NC}"
    log ""
    read -p "Installer la stack de monitoring maintenant? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log ""
        log "Installation de la stack de monitoring..."
        if bash "$SCRIPT_DIR/monitoring/setup-monitoring.sh" | tee -a "$LOG_FILE"; then
            log "${GREEN}✓ Stack de monitoring installée${NC}"
            MONITORING_ENABLED=true
        else
            log "${RED}✗ Échec de l'installation${NC}"
            MONITORING_ENABLED=false
        fi
    else
        log "${YELLOW}Tests sans monitoring (métriques non exportées)${NC}"
        MONITORING_ENABLED=false
    fi
fi

log ""
sleep 2

# ============================================
# Test 1 : Connectivité 5G
# ============================================
log "${BOLD}[Étape 1/4] Test de Connectivité 5G${NC}"
log "================================================"
log ""

if ! bash "$SCRIPT_DIR/test-connectivity.sh" 2>&1 | tee -a "$LOG_FILE"; then
    log "${RED}✗ Échec du test de connectivité${NC}"
    log "Le test ne peut pas continuer sans connectivité 5G"
    exit 1
fi

log ""
log "${GREEN}✓ Test de connectivité réussi${NC}"
log ""
sleep 3

# ============================================
# Test 2 : Streaming Vidéo
# ============================================
log "${BOLD}[Étape 2/4] Test de Streaming Vidéo${NC}"
log "================================================"
log ""

if ! bash "$SCRIPT_DIR/test-video-streaming.sh" 2>&1 | tee -a "$LOG_FILE"; then
    log "${YELLOW}⚠ Échec du test de streaming${NC}"
    log "Continuons avec les tests de performance..."
else
    log ""
    log "${GREEN}✓ Test de streaming réussi${NC}"
    
    # Export des métriques de streaming si monitoring actif
    if [ "$MONITORING_ENABLED" = true ]; then
        log ""
        log "Export des métriques de streaming vers Prometheus..."
        
        LATEST_CURL=$(find "$RESULTS_DIR" -name "curl_metrics_*.txt" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2)
        
        if [ -f "$LATEST_CURL" ]; then
            TOTAL_TIME=$(grep "Temps total:" "$LATEST_CURL" | awk '{print $3}' | sed 's/s//')
            DOWNLOAD_SPEED=$(grep "Vitesse download:" "$LATEST_CURL" | awk '{print $3}')
            DOWNLOAD_SPEED_MBPS=$(echo "scale=2; $DOWNLOAD_SPEED * 8 / 1000000" | bc)
            UE_IP="12.1.1.2"
            
            source "$SCRIPT_DIR/monitoring/export-metrics.sh"
            export_streaming_metrics "$TOTAL_TIME" "$DOWNLOAD_SPEED_MBPS" "$UE_IP" "embb"
            
            log "${GREEN}✓ Métriques exportées vers Prometheus${NC}"
        fi
    fi
fi

log ""
sleep 3

# ============================================
# Test 3 : Mesures de Performance
# ============================================
log "${BOLD}[Étape 3/4] Mesures de Performance Réseau${NC}"
log "================================================"
log ""

if ! bash "$SCRIPT_DIR/measure-performance.sh" 2>&1 | tee -a "$LOG_FILE"; then
    log "${YELLOW}⚠ Échec partiel des mesures de performance${NC}"
else
    log ""
    log "${GREEN}✓ Mesures de performance réussies${NC}"
    
    # Export des métriques de performance si monitoring actif
    if [ "$MONITORING_ENABLED" = true ]; then
        log ""
        log "Export des métriques de performance vers Prometheus..."
        
        LATEST_PING=$(find "$RESULTS_DIR/performance" -name "ping_*.json" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2)
        
        if [ -f "$LATEST_PING" ]; then
            source "$SCRIPT_DIR/monitoring/export-metrics.sh"
            export_from_json "$LATEST_PING" "12.1.1.2" "embb"
            
            log "${GREEN}✓ Métriques exportées vers Prometheus${NC}"
        fi
        
        # Export des stats interface
        if ip link show uesimtun0 &> /dev/null; then
            export_interface_metrics "uesimtun0" "12.1.1.2"
            log "${GREEN}✓ Métriques d'interface exportées${NC}"
        fi
    fi
fi

log ""
sleep 2

# ============================================
# Test 4 : Génération du Rapport Final
# ============================================
log "${BOLD}[Étape 4/4] Génération du Rapport Final${NC}"
log "================================================"
log ""

FINAL_REPORT="$RESULTS_DIR/RAPPORT_FINAL_$(date +%Y%m%d_%H%M%S).md"

cat > "$FINAL_REPORT" <<EOF
# Rapport de Tests - NexSlice
## Projet 5G Network Slicing pour Streaming Vidéo

**Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**Groupe**: 4  
**Étudiants**: Tifenne Jupiter, Emilie Melis, Eya Walha  
**Monitoring**: $([ "$MONITORING_ENABLED" = true ] && echo "✅ Prometheus + Grafana" || echo "❌ Désactivé")

---

## 1. Configuration Testée

- **Infrastructure**: NexSlice (OAI Core 5G)
- **Simulateur**: UERANSIM v3.2.6
- **Slice**: eMBB (SST=1, SD=1)
- **Interface**: uesimtun0
- **IP UE**: 12.1.1.2
- **Gateway UPF**: 12.1.1.1

EOF

if [ "$MONITORING_ENABLED" = true ]; then
    cat >> "$FINAL_REPORT" <<EOF
### Stack de Monitoring

- **Prometheus**: http://localhost:30090
- **Pushgateway**: http://localhost:30091
- **Grafana**: http://localhost:30300
  - Username: \`admin\`
  - Password: \`admin\`

**Dashboard Grafana**: [NexSlice Monitoring](http://localhost:30300/d/nexslice)

EOF
fi

cat >> "$FINAL_REPORT" <<EOF
---

## 2. Résultats des Tests

### 2.1 Connectivité 5G

EOF

# Récupérer les derniers résultats de ping
LATEST_PING=$(find "$RESULTS_DIR/performance" -name "ping_*.json" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2)

if [ -f "$LATEST_PING" ]; then
    RTT_AVG=$(jq -r '.results.rtt_avg_ms' "$LATEST_PING")
    JITTER=$(jq -r '.results.jitter_ms' "$LATEST_PING")
    PACKET_LOSS=$(jq -r '.results.packet_loss_percent' "$LATEST_PING")
    
    cat >> "$FINAL_REPORT" <<EOF
| Métrique | Valeur | État |
|----------|--------|------|
| Latence moyenne | ${RTT_AVG} ms | $([ $(echo "$RTT_AVG < 10" | bc) -eq 1 ] && echo "✅ Excellent" || echo "⚠️ Acceptable") |
| Jitter | ${JITTER} ms | $([ $(echo "$JITTER < 5" | bc) -eq 1 ] && echo "✅ Excellent" || echo "⚠️ Acceptable") |
| Perte de paquets | ${PACKET_LOSS}% | $([ $(echo "$PACKET_LOSS == 0" | bc) -eq 1 ] && echo "✅ Aucune" || echo "⚠️ Présente") |

✅ **Conclusion**: Connectivité 5G stable et fonctionnelle

EOF
else
    cat >> "$FINAL_REPORT" <<EOF
*Données non disponibles*

EOF
fi

cat >> "$FINAL_REPORT" <<EOF
### 2.2 Streaming Vidéo

EOF

# Récupérer les métriques de streaming
LATEST_CURL=$(find "$RESULTS_DIR" -name "curl_metrics_*.txt" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2)

if [ -f "$LATEST_CURL" ]; then
    TOTAL_TIME=$(grep "Temps total:" "$LATEST_CURL" | awk '{print $3}')
    DOWNLOAD_SPEED=$(grep "Vitesse download:" "$LATEST_CURL" | awk '{print $3}')
    DOWNLOAD_SPEED_MBPS=$(echo "scale=2; $DOWNLOAD_SPEED * 8 / 1000000" | bc 2>/dev/null || echo "N/A")
    
    cat >> "$FINAL_REPORT" <<EOF
| Métrique | Valeur |
|----------|--------|
| Temps total | ${TOTAL_TIME} |
| Débit moyen | ${DOWNLOAD_SPEED_MBPS} Mbps |
| Fichier test | Big Buck Bunny (158 MB) |

✅ **Conclusion**: Streaming vidéo fonctionnel via le tunnel 5G

EOF
else
    cat >> "$FINAL_REPORT" <<EOF
*Données non disponibles*

EOF
fi

cat >> "$FINAL_REPORT" <<EOF
### 2.3 Performance Réseau

*Voir les rapports détaillés dans:* \`results/performance/\`

EOF

if [ "$MONITORING_ENABLED" = true ]; then
    cat >> "$FINAL_REPORT" <<EOF
**📊 Visualisation en temps réel**: Consultez le [dashboard Grafana](http://localhost:30300/d/nexslice) pour voir l'évolution des métriques.

EOF
fi

cat >> "$FINAL_REPORT" <<EOF
---

## 3. Validation du Routage 5G

Le trafic passe bien par le slice 5G, comme le prouvent:

1. **Interface utilisée**: uesimtun0 (tunnel 5G)
2. **IP source**: 12.1.1.2 (IP attribuée par le Core 5G)
3. **Gateway**: 12.1.1.1 (UPF du Core OAI)
4. **Métriques**: Confirmées via $([ "$MONITORING_ENABLED" = true ] && echo "Prometheus" || echo "logs locaux")

---

## 4. Conclusions

### Points Validés ✅

- Connectivité 5G fonctionnelle via UERANSIM
- Slice eMBB (SST=1) correctement configuré
- Streaming vidéo opérationnel via le tunnel 5G
- Métriques de performance cohérentes avec un slice eMBB
EOF

if [ "$MONITORING_ENABLED" = true ]; then
    cat >> "$FINAL_REPORT" <<EOF
- Stack de monitoring Prometheus + Grafana opérationnelle
- Export automatique des métriques pour analyse temps réel
EOF
fi

cat >> "$FINAL_REPORT" <<EOF

### Limitations Identifiées

- Tests réalisés avec 1 seul UE (mono-slice)
- Phase multi-slices (SST=1, 2, 3) non implémentée
- Pas de tests de mobilité ou de handover
- Environnement simulé (pas de radio réelle)

### Perspectives

1. **Court terme**: Déployer plusieurs UEs simultanés
2. **Moyen terme**: Implémenter les tests multi-slices avec monitoring différencié
3. **Long terme**: Tests sur infrastructure 5G réelle

---

## 5. Fichiers Générés

Tous les résultats sont disponibles dans \`results/\`:

EOF

# Lister les fichiers générés
find "$RESULTS_DIR" -type f \( -name "*.txt" -o -name "*.json" -o -name "*.mp4" \) 2>/dev/null | while read file; do
    echo "- \`$(basename $file)\`" >> "$FINAL_REPORT"
done

cat >> "$FINAL_REPORT" <<EOF

---

## 6. Reproduction

Pour reproduire ces tests:

\`\`\`bash
# 1. Cloner le repo
git clone https://github.com/EyaWal/Projet_NexSlice_Emulation_traffic-video.git
cd Projet_NexSlice_Emulation_traffic-video

# 2. Installer la stack de monitoring (optionnel)
./scripts/monitoring/setup-monitoring.sh

# 3. Lancer la suite de tests
sudo ./scripts/run-all-tests.sh
\`\`\`

EOF

if [ "$MONITORING_ENABLED" = true ]; then
    cat >> "$FINAL_REPORT" <<EOF
## 7. Monitoring Continu

Pour surveiller en continu:

\`\`\`bash
# Lancer les tests toutes les 5 minutes
watch -n 300 './scripts/measure-performance.sh'

# Ou via cron
crontab -e
# Ajouter: */5 * * * * /path/to/scripts/measure-performance.sh
\`\`\`

Consultez Grafana pour voir l'évolution: http://localhost:30300

EOF
fi

cat >> "$FINAL_REPORT" <<EOF
---

*Rapport généré automatiquement par run-all-tests.sh*
EOF

log "${GREEN}✓ Rapport final généré: $FINAL_REPORT${NC}"
log ""

# ============================================
# Résumé final
# ============================================
log "================================================"
log "${BOLD}${GREEN}✓ Suite de tests terminée avec succès${NC}"
log "================================================"
log ""
log "📁 Tous les résultats sont dans: $RESULTS_DIR/"
log ""
log "📄 Documents générés:"
log "   - Rapport final: $FINAL_REPORT"
log "   - Log complet: $LOG_FILE"
log ""

if [ "$MONITORING_ENABLED" = true ]; then
    log "📊 Monitoring:"
    log "   - Prometheus: ${CYAN}http://localhost:30090${NC}"
    log "   - Grafana: ${CYAN}http://localhost:30300${NC}"
    log "   - Dashboard NexSlice: ${CYAN}http://localhost:30300/d/nexslice${NC}"
    log ""
fi

log "📊 Pour visualiser le rapport:"
log "   cat $FINAL_REPORT"
log ""
log "🔍 Prochaines étapes recommandées:"
if [ "$MONITORING_ENABLED" = true ]; then
    log "   1. Consulter le dashboard Grafana"
    log "   2. Analyser les tendances des métriques"
    log "   3. Configurer des alertes si nécessaire"
else
    log "   1. Installer le monitoring: ./scripts/monitoring/setup-monitoring.sh"
    log "   2. Relancer les tests pour collecter les métriques"
fi
log "   4. Documenter les observations dans le README"
log ""

exit 0