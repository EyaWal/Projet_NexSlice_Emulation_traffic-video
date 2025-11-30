# Guide d'Utilisation des Scripts - NexSlice

## Vue d'Ensemble

Ce guide vous explique comment utiliser les scripts de test fournis pour valider votre infrastructure 5G et collecter des métriques de performance avec monitoring en temps réel via Prometheus et Grafana.

---

## Scripts Disponibles

| Script | Rôle | Durée | Privilèges |
|--------|------|-------|------------|
| `test-connectivity.sh` | Test connectivité 5G de base | ~30s | Utilisateur |
| `test-video-streaming.sh` | Test streaming vidéo complet | ~2-5 min | **sudo** |
| `measure-performance.sh` | Mesures réseau détaillées | ~2 min | Utilisateur |
| `run-all-tests.sh` | Orchestration complète | ~5-10 min | **sudo** |

### Scripts de Monitoring

| Script | Rôle | Privilèges |
|--------|------|------------|
| `monitoring/setup-monitoring.sh` | Installation Prometheus + Grafana | Utilisateur |
| `monitoring/export-metrics.sh` | Export métriques vers Prometheus | Utilisateur |
| `monitoring/check-monitoring.sh` | Vérification stack monitoring | Utilisateur |
| `monitoring/cleanup-monitoring.sh` | Nettoyage monitoring | Utilisateur |

---

## Utilisation

### Prérequis

Avant de lancer les scripts, assurez-vous que:

1. **L'infrastructure NexSlice est déployée**:
```bash
# Vérifier que tous les pods du Core 5G sont Running
kubectl get pods -n nexslice

# Vous devriez voir:
# - AMF, SMF, UPF, NRF, AUSF, UDM, etc. en "Running"
# - gNB UERANSIM en "Running"
# - UE UERANSIM en "Running"
```

2. **L'interface tunnel est créée**:
```bash
# Vérifier que uesimtun0 existe
ip link show uesimtun0

# Devrait afficher quelque chose comme:
# 5: uesimtun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN mode DEFAULT group default qlen 500
```

3. **Les outils nécessaires sont installés**:
```bash
# Installation des dépendances
sudo apt update
sudo apt install -y iputils-ping curl jq bc
```

4. **La stack de monitoring est déployée** (voir section [Installation du Monitoring](#installation-du-monitoring))

---

## Installation du Monitoring

### Étape 1: Installer la Stack Prometheus + Grafana
```bash
# Depuis la racine du projet
./scripts/monitoring/setup-monitoring.sh
```

Le script effectue automatiquement:
- Création du namespace `monitoring`
- Déploiement de Prometheus (port 30090)
- Déploiement de Pushgateway (port 30091)
- Déploiement de Grafana (port 30300)
- Configuration des sources de données
- Création des dashboards de base
- Configuration des alertes

**Résultat attendu**:
```
================================================
  Installation Stack Monitoring - NexSlice
================================================

[1/6] Création du namespace monitoring...
Namespace monitoring créé

[2/6] Déploiement de Prometheus...
Prometheus déployé

[3/6] Déploiement de Pushgateway...
Pushgateway déployé

[4/6] Déploiement de Grafana...
Grafana déployé

[5/6] Attente du démarrage des pods...
Prometheus: pod/prometheus-xxxxx condition met
Pushgateway: pod/pushgateway-xxxxx condition met
Grafana: pod/grafana-xxxxx condition met
Tous les pods sont prêts

[6/6] Configuration du dashboard Grafana...
Dashboard Grafana configuré

================================================
Stack de monitoring installée avec succès
================================================

Accès aux interfaces:
  Prometheus:  http://localhost:30090
  Pushgateway: http://localhost:30091
  Grafana:     http://localhost:30300

Identifiants Grafana:
  Username: admin
  Password: admin

Prochaines étapes:
  1. Ouvrir Grafana: http://localhost:30300
  2. Importer le dashboard: monitoring/grafana-dashboard-nexslice.json
  3. Lancer les tests: ./scripts/run-all-tests.sh
```

### Étape 2: Vérifier l'Installation
```bash
./scripts/monitoring/check-monitoring.sh
```

**Résultat attendu**:
```
Vérification de la stack de monitoring...

Namespace monitoring existe
prometheus est actif
pushgateway est actif
grafana est actif

URLs des services:
  Prometheus:  http://localhost:30090
  Pushgateway: http://localhost:30091
  Grafana:     http://localhost:30300

Test de connectivité...
Prometheus accessible
Pushgateway accessible
Grafana accessible

Stack de monitoring opérationnelle
```

### Étape 3: Accéder à Grafana

1. Ouvrir http://localhost:30300
2. **Login**: `admin` / **Password**: `admin`
3. Aller dans **Dashboards** → Importer le dashboard JSON
4. Uploader le fichier `monitoring/grafana-dashboard-nexslice.json`

---

## Script 1: test-connectivity.sh

### Description
Vérifie la connectivité 5G de base vers l'UPF.

### Utilisation
```bash
cd scripts/
./test-connectivity.sh
```

### Ce qu'il fait
1. Vérifie l'existence de l'interface `uesimtun0`
2. Vérifie l'IP du UE (12.1.1.2)
3. Vérifie le routage vers l'UPF
4. Envoie 10 pings vers l'UPF (12.1.1.1)
5. Teste l'accès Internet (optionnel)

### Résultat Attendu
```
================================================
  Test de Connectivité 5G - NexSlice
================================================

[1/5] Vérification interface uesimtun0...
Interface uesimtun0 existe
Détails interface:
    inet 12.1.1.2/32 scope global uesimtun0

[2/5] Vérification IP du UE...
IP UE correcte: 12.1.1.2

[3/5] Vérification routing via UPF...
Route configurée via uesimtun0

[4/5] Test ping vers UPF Gateway (12.1.1.1)...
Envoi de 10 paquets ICMP...
Connectivité 5G vers UPF
Statistiques:
  - Latence moyenne: 2.456 ms
  - Perte de paquets: 0%

[5/5] Test résolution DNS...
Accès Internet via tunnel 5G

================================================
Tests de connectivité terminés avec succès
================================================
```

### Dépannage

**Problème**: Interface uesimtun0 n'existe pas
```bash
# Vérifier les logs du UE UERANSIM
kubectl logs -n nexslice <ue-pod-name>

# Rechercher: "Connection setup for PDU session[1] is successful"
```

**Problème**: Ping vers UPF échoue
```bash
# Vérifier que l'UPF est actif
kubectl get pods -n nexslice | grep upf

# Vérifier les logs UPF
kubectl logs -n nexslice <upf-pod-name>
```

---

## Script 2: test-video-streaming.sh

### Description
Teste le streaming vidéo via le tunnel 5G avec métriques détaillées et export vers Prometheus.

### Utilisation
```bash
cd scripts/
sudo ./test-video-streaming.sh
```

**Note**: Nécessite sudo pour certaines opérations optionnelles (capture tcpdump désactivée par défaut avec monitoring).

### Ce qu'il fait
1. Vérifie l'interface 5G
2. Télécharge une vidéo (Big Buck Bunny, ~158 MB) via le tunnel
3. Mesure le débit, temps de téléchargement
4. Exporte les métriques vers Prometheus (si monitoring actif)
5. Vérifie le routage via UPF

### Résultat Attendu
```
================================================
  Test Streaming Vidéo via Slice 5G (SST=1)
================================================

[1/4] Vérification interface 5G...
Interface uesimtun0 active
  IP du UE: 12.1.1.2

[2/4] Téléchargement vidéo via tunnel 5G...
  URL: http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4
  Interface: uesimtun0

=== Métriques de Téléchargement ===
Temps total: 45.234s
Temps connexion: 0.123s
Temps démarrage transfert: 0.456s
Vitesse download: 3456789 bytes/s
Taille téléchargée: 158000000 bytes
Code HTTP: 200
IP source: 12.1.1.2
================================

Téléchargement réussi
Temps écoulé: 45s
  Taille fichier: 151M
  Débit moyen: 27.96 Mbps

[3/4] Export des métriques vers Prometheus...
Métriques exportées
  Endpoint: http://localhost:30091/metrics/job/nexslice_test

[4/4] Vérification du routage via UPF...
  IP source (UE): 12.1.1.2
  Gateway UPF: 12.1.1.1
Trafic routé via le tunnel 5G

================================================
Test de streaming terminé avec succès
Consultez Grafana: http://localhost:30300
================================================
```

### Fichiers Générés
```
results/
├── video_20251130_123456.mp4           # Vidéo téléchargée
└── curl_metrics_20251130_123456.txt    # Métriques curl
```

---

## Script 3: measure-performance.sh

### Description
Mesure détaillée de performance réseau (latence, jitter, débit) avec export automatique vers Prometheus.

### Utilisation
```bash
cd scripts/
./measure-performance.sh
```

### Ce qu'il fait
1. **Test 1**: Latence et jitter (100 pings)
2. **Test 2**: Débit avec iperf3 (optionnel si serveur disponible)
3. **Test 3**: Statistiques interface réseau
4. **Exporte toutes les métriques vers Prometheus** (si monitoring actif)
5. Génère un rapport Markdown

### Résultat Attendu
```
================================================
  Mesures de Performance - Slice eMBB (SST=1)
================================================

[Prérequis] Vérification des outils nécessaires...
Interface uesimtun0 active (IP: 12.1.1.2)

================================================
[Test 1/3] Mesure Latence et Jitter
================================================
Destination: 12.1.1.1
Nombre de pings: 100

Envoi des paquets ICMP...
Résultats Latence:
  - RTT Min:     1.234 ms
  - RTT Moyen:   2.456 ms
  - RTT Max:     5.678 ms
  - Jitter (mdev): 0.789 ms
  - Perte:       0%
Fichier sauvegardé: results/performance/ping_20251130_123456.json
Métriques exportées vers Prometheus

================================================
[Test 2/3] Mesure Débit (iperf3)
================================================
Test iperf3 ignoré (pas de serveur configuré)

Pour activer ce test:
  1. Sur une machine avec accès réseau, lancez:
     iperf3 -s
  2. Relancez ce script et entrez l'IP du serveur

================================================
[Test 3/3] Statistiques Interface 5G
================================================
Test de charge (10s de trafic)...
Statistiques RX/TX:
    RX: bytes  packets  errors  dropped  overrun  mcast
    1234567    8901     0       0        0        0
    TX: bytes  packets  errors  dropped  carrier  collsns
    9876543    7890     0       0        0        0
Fichier sauvegardé: results/performance/interface_stats_20251130_123456.txt
Métriques exportées vers Prometheus

================================================
  Génération du Rapport
================================================
Rapport généré: results/performance/rapport_performance_20251130_123456.md
Dashboard Grafana mis à jour: http://localhost:30300
```

### Fichiers Générés
```
results/performance/
├── ping_20251130_123456.json          # Métriques latence (JSON)
├── ping_20251130_123456.txt           # Sortie brute ping
├── interface_stats_20251130_123456.txt # Stats interface
└── rapport_performance_20251130_123456.md # Rapport complet
```

### Interpréter les Résultats

**Latence**:
- Excellent: < 10 ms
- Bon: 10-50 ms (adapté au streaming)
- Acceptable: 50-100 ms
- Problématique: > 100 ms

**Jitter**:
- Excellent: < 5 ms
- Bon: 5-10 ms
- À surveiller: > 10 ms

**Perte de paquets**:
- Excellent: 0%
- Acceptable: < 1%
- Problématique: 1-5%
- Critique: > 5%

---

## Script 4: run-all-tests.sh (MASTER)

### Description
Orchestre l'exécution de tous les tests de manière séquentielle avec export automatique vers Prometheus et génération d'un rapport final.

### Utilisation
```bash
cd scripts/
sudo ./run-all-tests.sh
```

### Ce qu'il fait
```
[Étape 0/5] Vérification des prérequis
  ├── Vérifier présence des scripts
  ├── Vérifier outils (ping, curl, jq, bc)
  ├── Vérifier permissions
  └── Vérifier stack de monitoring

[Étape 1/4] Test de Connectivité 5G
  └── Exécute test-connectivity.sh

[Étape 2/4] Test de Streaming Vidéo
  └── Exécute test-video-streaming.sh

[Étape 3/4] Mesures de Performance Réseau
  └── Exécute measure-performance.sh

[Étape 4/4] Génération du Rapport Final
  ├── Compile tous les résultats
  ├── Export final des métriques vers Prometheus
  ├── Génère RAPPORT_FINAL.md
  └── Résumé des fichiers créés
```

### Résultat Attendu
```
================================================
    NexSlice - Suite de Tests Complète
    Monitoring: Prometheus + Grafana
================================================

Date: 2025-11-30 12:34:56
Log: results/test_run_20251130_123456.log

[Étape 0/5] Vérification des prérequis
================================================
Tous les scripts sont présents
Tous les outils sont installés

Vérification de la stack de monitoring...
Stack de monitoring opérationnelle
  Prometheus:  http://localhost:30090
  Pushgateway: http://localhost:30091
  Grafana:     http://localhost:30300

[...exécution des tests...]

================================================
Suite de tests terminée avec succès
================================================

Tous les résultats sont dans: results/

Monitoring:
   - Prometheus: http://localhost:30090
   - Grafana: http://localhost:30300
   - Dashboard NexSlice: http://localhost:30300/d/nexslice

Documents générés:
   - Rapport final: results/RAPPORT_FINAL_20251130_123456.md
   - Log complet: results/test_run_20251130_123456.log

Prochaines étapes recommandées:
   1. Consulter le dashboard Grafana
   2. Vérifier les alertes Prometheus
   3. Comparer les métriques avec les objectifs du projet
```

### Fichiers Générés

Le script génère une structure complète de résultats:
```
results/
├── RAPPORT_FINAL_20251130_123456.md      # Rapport final complet
├── test_run_20251130_123456.log          # Log de toute l'exécution
├── performance/
│   ├── ping_20251130_123456.json         # Métriques latence (JSON)
│   ├── ping_20251130_123456.txt          # Sortie brute ping
│   ├── interface_stats_20251130_123456.txt
│   └── rapport_performance_20251130_123456.md
├── video_20251130_123456.mp4             # Vidéo téléchargée
└── curl_metrics_20251130_123456.txt      # Métriques HTTP
```

---

## Monitoring avec Prometheus et Grafana

### Accès aux Interfaces

| Service | URL | Login |
|---------|-----|-------|
| **Prometheus** | http://localhost:30090 | - |
| **Pushgateway** | http://localhost:30091 | - |
| **Grafana** | http://localhost:30300 | admin / admin |

### Dashboard Grafana

**Accès au Dashboard**:
1. Ouvrir http://localhost:30300
2. Login: `admin` / `admin`
3. Aller dans **Dashboards** → **NexSlice - Monitoring 5G**

**Panels disponibles**:
- Latence Moyenne (RTT): Évolution sur les 15 dernières minutes
- Débit (Throughput): Mbps en temps réel
- Perte de Paquets: Pourcentage sur période
- Jitter: Variation de latence
- Statistiques d'interface réseau

### Métriques Prometheus Exportées

Les scripts exportent automatiquement les métriques suivantes:
```promql
# Latence
nexslice_rtt_min_ms{ue_ip="12.1.1.2", slice_type="embb"}
nexslice_rtt_avg_ms{ue_ip="12.1.1.2", slice_type="embb"}
nexslice_rtt_max_ms{ue_ip="12.1.1.2", slice_type="embb"}

# Jitter et perte
nexslice_jitter_ms{ue_ip="12.1.1.2", slice_type="embb"}
nexslice_packet_loss_percent{ue_ip="12.1.1.2", slice_type="embb"}

# Débit
nexslice_throughput_mbps{ue_ip="12.1.1.2", slice_type="embb"}
nexslice_download_time_seconds{ue_ip="12.1.1.2", slice_type="embb"}

# Connectivité
nexslice_ue_connected{ue_ip="12.1.1.2", slice_type="embb"}

# Interface réseau
nexslice_interface_rx_bytes{ue_ip="12.1.1.2", interface="uesimtun0"}
nexslice_interface_tx_bytes{ue_ip="12.1.1.2", interface="uesimtun0"}
```

### Requêtes Prometheus Utiles
```promql
# Latence moyenne sur 5 minutes
avg_over_time(nexslice_rtt_avg_ms{ue_ip="12.1.1.2"}[5m])

# Débit maximum observé
max_over_time(nexslice_throughput_mbps{ue_ip="12.1.1.2"}[5m])

# Perte de paquets totale
sum(nexslice_packet_loss_percent{slice_type="embb"})

# Vérifier si UE est connecté
nexslice_ue_connected{ue_ip="12.1.1.2"}
```

### Système d'Alertes

Les alertes suivantes sont pré-configurées:

| Alerte | Condition | Durée | Sévérité |
|--------|-----------|-------|----------|
| **HighLatency** | RTT > 50ms | 2 min | Warning |
| **PacketLoss** | Perte > 1% | 1 min | Critical |
| **LowThroughput** | Débit < 10 Mbps | 5 min | Warning |
| **UE_Disconnected** | UE offline | 1 min | Critical |

**Consulter les alertes**: http://localhost:30090/alerts

### Export Manuel de Métriques

Si vous souhaitez exporter des métriques manuellement:
```bash
# Utiliser le script d'export
source ./scripts/monitoring/export-metrics.sh

# Exporter une métrique simple
export_metric "nexslice_custom_metric" "42.5" "gauge" "/ue_ip/12.1.1.2"

# Exporter depuis un fichier JSON
export_from_json "results/performance/ping_latest.json" "12.1.1.2" "embb"
```

---

## Exploiter les Résultats

### 1. Récupérer les Métriques pour votre Rapport
```bash
# Latence moyenne
jq -r '.results.rtt_avg_ms' results/performance/ping_*.json

# Jitter
jq -r '.results.jitter_ms' results/performance/ping_*.json

# Perte de paquets
jq -r '.results.packet_loss_percent' results/performance/ping_*.json
```

### 2. Calculer le Débit Moyen
```bash
# Depuis les métriques curl
grep "Vitesse download:" results/curl_metrics_*.txt | awk '{print $3}'

# Conversion en Mbps
BYTES_PER_SEC=$(grep "Vitesse download:" results/curl_metrics_*.txt | awk '{print $3}')
echo "scale=2; $BYTES_PER_SEC * 8 / 1000000" | bc
```

### 3. Générer un Tableau de Résultats
```bash
# Via Prometheus API
PROMETHEUS_URL="http://localhost:30090"
UE_IP="12.1.1.2"

# Récupérer la latence moyenne
RTT_AVG=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=nexslice_rtt_avg_ms{ue_ip=\"${UE_IP}\"}" | jq -r '.data.result[0].value[1]')

# Récupérer le débit
THROUGHPUT=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=nexslice_throughput_mbps{ue_ip=\"${UE_IP}\"}" | jq -r '.data.result[0].value[1]')

# Récupérer la perte de paquets
PACKET_LOSS=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=nexslice_packet_loss_percent{ue_ip=\"${UE_IP}\"}" | jq -r '.data.result[0].value[1]')

# Générer le tableau
echo "| Métrique | Valeur |"
echo "|----------|--------|"
echo "| Latence moyenne | ${RTT_AVG} ms |"
echo "| Débit moyen | ${THROUGHPUT} Mbps |"
echo "| Perte de paquets | ${PACKET_LOSS}% |"
```

### 4. Exporter les Métriques Historiques
```bash
# Exporter 24h de métriques depuis Prometheus
curl -G http://localhost:30090/api/v1/query_range \
  --data-urlencode 'query=nexslice_rtt_avg_ms{ue_ip="12.1.1.2"}' \
  --data-urlencode 'start=2025-11-29T00:00:00Z' \
  --data-urlencode 'end=2025-11-30T00:00:00Z' \
  --data-urlencode 'step=15s' | jq > metrics_24h.json
```

---

## Dépannage Commun

### Erreur: "Interface uesimtun0 non trouvée"

**Cause**: Le UE UERANSIM n'est pas démarré ou n'a pas réussi à se connecter.

**Solution**:
```bash
# Vérifier les pods
kubectl get pods -n nexslice

# Vérifier les logs du UE
kubectl logs -n nexslice <ue-pod-name> | grep -i "connection setup"

# Devrait afficher:
# [INFO] Connection setup for PDU session[1] is successful
```

### Erreur: "No route to host"

**Cause**: Le Core 5G n'a pas configuré correctement le routage.

**Solution**:
```bash
# Vérifier l'UPF
kubectl get pods -n nexslice | grep upf
kubectl logs -n nexslice <upf-pod-name>

# Redémarrer le UE si nécessaire
kubectl delete pod -n nexslice <ue-pod-name>
```

### Warning: "Stack de monitoring non accessible"

**Cause**: Prometheus, Pushgateway ou Grafana ne sont pas démarrés.

**Solution**:
```bash
# Vérifier les pods de monitoring
kubectl get pods -n monitoring

# Si des pods sont en erreur
kubectl describe pod -n monitoring <pod-name>

# Réinstaller si nécessaire
./scripts/monitoring/cleanup-monitoring.sh
./scripts/monitoring/setup-monitoring.sh
```

### Erreur: "Métriques non visibles dans Grafana"

**Cause**: Les métriques n'ont pas été exportées ou Prometheus ne scrape pas correctement.

**Solution**:
```bash
# Vérifier que Pushgateway a reçu les métriques
curl http://localhost:30091/metrics | grep nexslice

# Vérifier que Prometheus scrape correctement
curl http://localhost:30090/api/v1/targets | jq

# Relancer les tests
./scripts/measure-performance.sh
```

---

## Conseils et Bonnes Pratiques

### 1. Exécuter les Tests dans l'Ordre

Toujours commencer par le test de connectivité:
```bash
./scripts/test-connectivity.sh    # D'abord
./scripts/test-video-streaming.sh # Ensuite
./scripts/measure-performance.sh  # Puis
```

Ou utiliser le script maître:
```bash
sudo ./scripts/run-all-tests.sh   # Tout automatiquement
```

### 2. Sauvegarder les Résultats
```bash
# Créer une archive des résultats
tar -czf resultats_$(date +%Y%m%d).tar.gz results/

# Copier dans un endroit sûr
cp resultats_*.tar.gz ~/backup/
```

### 3. Monitoring Continu

Pour surveiller en continu votre infrastructure:
```bash
# Option 1: Avec watch (toutes les 5 minutes)
watch -n 300 './scripts/measure-performance.sh'

# Option 2: Avec cron (automatique)
crontab -e
# Ajouter: */5 * * * * /path/to/scripts/measure-performance.sh
```

### 4. Répéter les Tests

Pour des résultats fiables, répétez les tests 3 fois:
```bash
for i in 1 2 3; do
    echo "=== Test $i/3 ==="
    sudo ./scripts/run-all-tests.sh
    sleep 60  # Attendre 1 minute entre les tests
done
```

---

## Utilisation pour la Présentation

### Créer une Démonstration Live
```bash
# 1. Ouvrir Grafana en mode kiosque (plein écran)
# Dans votre navigateur: http://localhost:30300/d/nexslice?refresh=5s&kiosk

# 2. Lancer les tests en arrière-plan
./scripts/run-all-tests.sh &

# 3. Les graphiques se mettent à jour automatiquement
# 4. Pointer vers les métriques clés:
#    - Latence stable autour de 2-5ms
#    - Débit constant à 25-30 Mbps
#    - Zéro perte de paquets
```

### Préparer des Captures d'Écran

Pendant les tests, prenez des screenshots de:
1. `kubectl get pods -n nexslice` (pods Running)
2. `ip addr show uesimtun0` (interface 5G)
3. `./scripts/test-connectivity.sh` (résultats)
4. Dashboard Grafana (métriques en temps réel)

Sauvegarder dans `images/`:
```bash
mkdir -p images/
# Copiez vos screenshots ici
```

---

## Nettoyage

### Supprimer la Stack de Monitoring
```bash
./scripts/monitoring/cleanup-monitoring.sh
```

### Supprimer les Résultats de Tests
```bash
# Supprimer tous les résultats
rm -rf results/

# Ou supprimer seulement les anciennes captures
find results/ -name "*.pcap" -mtime +7 -delete
```

---

## Support

Si vous rencontrez des problèmes:

1. Vérifiez d'abord la section **Dépannage Commun** ci-dessus
2. Consultez les logs: `cat results/test_run_*.log`
3. Vérifiez l'infrastructure: `kubectl get pods -n nexslice`
4. Vérifiez le monitoring: `./scripts/monitoring/check-monitoring.sh`

---

*Guide d'utilisation des scripts - Projet NexSlice - Groupe 4*
