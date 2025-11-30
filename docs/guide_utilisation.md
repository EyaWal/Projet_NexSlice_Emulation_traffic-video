# Guide d'Utilisation des Scripts - NexSlice

## Vue d'Ensemble

Ce guide vous explique comment utiliser les scripts de test fournis pour valider votre infrastructure 5G et collecter des métriques de performance avec monitoring en temps réel via Prometheus et Grafana.

---

## Scripts Disponibles

| Script                     | Rôle                                    | Durée      | Privilèges |
|---------------------------|-----------------------------------------|-----------|------------|
| `test-connectivity.sh`    | Vérifie la connectivité 5G de base     | ~30 s     | utilisateur |
| `test-video-streaming.sh` | Teste le téléchargement vidéo via 5G   | ~1–3 min  | **sudo**   |
| `measure-performance.sh`  | Mesure latence + stats interface       | ~1–2 min  | utilisateur |
| `run-all-tests.sh`        | Enchaîne les 3 scripts ci-dessus       | ~3–5 min  | **sudo**   |
| `collect-metrics.sh`      | Récupère des métriques pour le rapport | ~2–3 min  | utilisateur |


### Scripts de Monitoring


| Script                                  | Rôle                                     | Privilèges |
|-----------------------------------------|------------------------------------------|------------|
| `scripts/monitoring/setup-monitoring.sh`   | Déploie Prometheus + Pushgateway + Grafana | utilisateur |
| `scripts/monitoring/check-monitoring.sh`   | Vérifie que la stack de monitoring tourne  | utilisateur |
| `scripts/monitoring/cleanup-monitoring.sh` | Supprime le namespace `monitoring` (K8s)   | utilisateur |
| `scripts/monitoring/export-metrics.sh`     | Fonction shell pour pousser des métriques (usage avancé) | utilisateur |

---

## Prérequis Complets - Checklist

Avant de lancer les tests, vérifiez que TOUT est en place dans cet ordre précis:

### Étape 1: Infrastructure NexSlice
```bash
# Vérifier que tous les pods du Core 5G sont Running
kubectl get pods -n nexslice

# Vous devriez voir:
# - AMF, SMF, UPF, NRF, AUSF, UDM, etc. en "Running"
# - gNB UERANSIM en "Running"
# - UE UERANSIM en "Running"
```

**Si des pods manquent**: Retournez au README de NexSlice et suivez les instructions de déploiement.

### Étape 2: Interface Tunnel 5G
```bash
# Vérifier que uesimtun0 existe
ip link show uesimtun0

# Devrait afficher quelque chose comme:
# 5: uesimtun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN mode DEFAULT group default qlen 500
```

**Si l'interface n'existe pas**:
```bash
# Vérifier les logs du UE UERANSIM
kubectl logs -n nexslice <ue-pod-name>

# Rechercher: "Connection setup for PDU session[1] is successful"
```

### Étape 3: Serveur Vidéo

**Option A: Serveur Externe (Recommandé)**
```bash
# Tester l'accès au serveur vidéo par défaut
curl -I http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4

# Résultat attendu:
# HTTP/1.1 200 OK
# Content-Type: video/mp4
# Content-Length: 158008374
```

**Si le test réussit**: Passez à l'Étape 4. Aucune configuration supplémentaire requise.

**Si le test échoue** (pas d'accès Internet): Déployez un serveur local (Option B ci-dessous).

**Option B: Serveur Local sur Kubernetes**
```bash
# Créer le déploiement nginx
cat > video-server-deployment.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: nexslice
data:
  nginx.conf: |
    server {
      listen 80;
      location / {
        root /usr/share/nginx/html;
        autoindex on;
      }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: video-server
  namespace: nexslice
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: video-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: video-server
  namespace: nexslice
spec:
  replicas: 1
  selector:
    matchLabels:
      app: video-server
  template:
    metadata:
      labels:
        app: video-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        - name: video-storage
          mountPath: /usr/share/nginx/html
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
      - name: video-storage
        emptyDir: {}
EOF

# Déployer le serveur
kubectl apply -f video-server-deployment.yaml

# Vérifier que le serveur est actif
kubectl get pods -n nexslice | grep video-server
# Devrait afficher: video-server-xxxxx   1/1     Running   0          30s

# Télécharger la vidéo de test
wget http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4

# Copier la vidéo dans le pod
POD_NAME=$(kubectl get pods -n nexslice -l app=video-server -o jsonpath='{.items[0].metadata.name}')
kubectl cp BigBuckBunny.mp4 nexslice/$POD_NAME:/usr/share/nginx/html/

# Vérifier que la vidéo est accessible
kubectl exec -n nexslice $POD_NAME -- ls -lh /usr/share/nginx/html/
```

**Modifier le script de test**:
```bash
# Éditer scripts/test-video-streaming.sh
nano scripts/test-video-streaming.sh

# Trouver la ligne:
VIDEO_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

# Remplacer par:
VIDEO_URL="http://video-server.nexslice.svc.cluster.local/BigBuckBunny.mp4"

# Sauvegarder (Ctrl+O, Entrée, Ctrl+X)
```

### Étape 4: Outils Nécessaires
```bash
# Installation des dépendances
sudo apt update
sudo apt install -y iputils-ping curl jq bc
```

### Étape 5: Stack de Monitoring
```bash
# Installer la stack de monitoring
./scripts/monitoring/setup-monitoring.sh

# Vérifier l'installation
./scripts/monitoring/check-monitoring.sh
```

**Résultat attendu**:
```
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

---

## Checklist Finale Avant les Tests

Cochez chaque élément avant de lancer `run-all-tests.sh`:

- [ ] **Infrastructure NexSlice**: Tous les pods Running
- [ ] **Interface uesimtun0**: Existe et est UP
- [ ] **Serveur vidéo**: Accessible (curl -I réussit)
- [ ] **Outils**: ping, curl, jq, bc installés
- [ ] **Monitoring**: Prometheus, Pushgateway, Grafana actifs

**Si TOUS les éléments sont cochés**: Vous pouvez lancer les tests !

**Si un élément manque**: Retournez à la section correspondante ci-dessus.

---

## Installation du Monitoring

### Déployer la Stack Prometheus + Grafana
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

### Vérifier l'Installation
```bash
./scripts/monitoring/check-monitoring.sh
```

### Accéder à Grafana

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
3. Sauvegarde :la vidéo dans results/video_<timestamp>.mp4
               les métriques curl dans results/curl_metrics_<timestamp>.txt

### Résultat Attendu
```
================================================
  Test Streaming Vidéo via Slice 5G (SST=1)
================================================

[1/3] Vérification interface 5G...
✓ Interface uesimtun0 active
  IP du UE: 12.1.1.2

[2/3] Téléchargement vidéo...
Temps total: 43.21s
Vitesse: 3700000 bytes/s
Code HTTP: 200

✓ Téléchargement réussi
  Temps: 43s
  Taille: 151M

[3/3] Vérification...
  IP source: 12.1.1.2
  Fichier: results/video_20251130_123456.mp4
✓ Test terminé

Résultats dans: results/
 ``` 



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
  Mesures de Performance - Slice eMBB
================================================

✓ Interface uesimtun0 active (IP: 12.1.1.2)

[1/2] Mesure Latence et Jitter...
Résultats:
  - Latence moyenne: 2.45 ms
  - Jitter (mdev): 0.80 ms
  - Perte: 0%

[2/2] Statistiques Interface...
✓ Statistiques sauvegardées

================================================
✓ Mesures terminées
================================================
Résultats dans: results/performance/
  - Ping:  results/performance/ping_20251130_123456.txt
  - Stats: results/performance/interface_stats_20251130_123456.txt

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

### Consultation des Métriques en Temps Réel

**Via Prometheus** :
- URL : http://localhost:30090
- Utilisez les requêtes PromQL pour interroger les métriques
- Créez vos propres graphiques

**Via Grafana** :
- URL : http://localhost:30300
- Dashboards pré-configurés
- Visualisation sur période personnalisable

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

### Erreur: "Failed to download video"

**Cause**: Le serveur vidéo n'est pas accessible.

**Solution**:
```bash
# Tester l'accès au serveur vidéo
curl -I http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4

# Si le test échoue:
# Option 1: Vérifier votre accès Internet
# Option 2: Déployer un serveur local (voir Étape 3 des Prérequis)
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

## Récapitulatif : Ordre d'Exécution Complet

### Phase 1: Déploiement (une seule fois)
```bash
# 1. Infrastructure NexSlice (fournie par le prof)
cd NexSlice && kubectl apply -f ...

# 2. Vérifier l'infrastructure
kubectl get pods -n nexslice

# 3. Serveur vidéo (Option A: serveur externe par défaut)
curl -I http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4

# 4. Stack de monitoring
./scripts/monitoring/setup-monitoring.sh
```

### Phase 2: Tests (répétable)
```bash
# Une fois tout déployé, lancer les tests
sudo ./scripts/run-all-tests.sh
```

### Phase 3: Analyse
```bash
# Consulter Grafana
firefox http://localhost:30300

# Lire le rapport final
cat results/RAPPORT_FINAL_*.md
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

# Ou supprimer seulement les anciens fichiers
find results/ -name "*.mp4" -mtime +7 -delete
```

---

## Support

Si vous rencontrez des problèmes:

1. Vérifiez d'abord la **Checklist Finale** en haut de ce guide
2. Consultez la section **Dépannage Commun** ci-dessus
3. Vérifiez les logs: `cat results/test_run_*.log`
4. Vérifiez l'infrastructure: `kubectl get pods -n nexslice`
5. Vérifiez le monitoring: `./scripts/monitoring/check-monitoring.sh`

---

*Guide d'utilisation des scripts - Projet NexSlice - Groupe 4*
