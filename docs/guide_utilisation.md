# 📘 Guide d'Utilisation des Scripts - NexSlice

## 🎯 Vue d'Ensemble

Ce guide vous explique comment utiliser les 4 scripts de test fournis pour valider votre infrastructure 5G et collecter des métriques de performance avec **monitoring en temps réel via Prometheus et Grafana**.

---

## 📦 Scripts Disponibles

| Script | Rôle | Durée | Privilèges |
|--------|------|-------|------------|
| `test-connectivity.sh` | Test connectivité 5G de base | ~30s | Utilisateur |
| `test-video-streaming.sh` | Test streaming vidéo complet | ~2-5 min | **sudo** |
| `measure-performance.sh` | Mesures réseau détaillées | ~2 min | Utilisateur* |
| `run-all-tests.sh` | Orchestration complète | ~5-10 min | **sudo** |

*\* Certaines fonctionnalités nécessitent sudo*

---

## 🚀 Utilisation

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
sudo apt install -y iputils-ping curl tcpdump iperf3 jq bc
```

4. **Prometheus et Grafana sont déployés** (voir section [Monitoring](#-monitoring-avec-prometheus-et-grafana))

---

## 📝 Script 1: test-connectivity.sh

### Description
Vérifie la connectivité 5G de base vers l'UPF.

### Utilisation
```bash
cd scripts/
./test-connectivity.sh
```

### Ce qu'il fait
1. ✅ Vérifie l'existence de l'interface `uesimtun0`
2. ✅ Vérifie l'IP du UE (12.1.1.2)
3. ✅ Vérifie le routage vers l'UPF
4. ✅ Envoie 10 pings vers l'UPF (12.1.1.1)
5. ✅ Teste l'accès Internet (optionnel)

### Résultat Attendu
```
================================================
  Test de Connectivité 5G - NexSlice
================================================

[1/5] Vérification interface uesimtun0...
✓ Interface uesimtun0 existe
Détails interface:
    inet 12.1.1.2/32 scope global uesimtun0

[2/5] Vérification IP du UE...
✓ IP UE correcte: 12.1.1.2

[3/5] Vérification routing via UPF...
✓ Route configurée via uesimtun0

[4/5] Test ping vers UPF Gateway (12.1.1.1)...
Envoi de 10 paquets ICMP...
✓ Connectivité 5G vers UPF
Statistiques:
  - Latence moyenne: 2.456 ms
  - Perte de paquets: 0%

[5/5] Test résolution DNS...
✓ Accès Internet via tunnel 5G

================================================
✓ Tests de connectivité terminés avec succès
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

## 🎥 Script 2: test-video-streaming.sh

### Description
Teste le streaming vidéo via le tunnel 5G avec métriques détaillées et export vers Prometheus.

### Utilisation
```bash
cd scripts/
sudo ./test-video-streaming.sh
```

⚠️ **Nécessite sudo** pour la capture tcpdump

### Ce qu'il fait
1. ✅ Vérifie l'interface 5G
2. ✅ Télécharge une vidéo (Big Buck Bunny, ~158 MB) via le tunnel
3. ✅ Mesure le débit, temps de téléchargement
4. ✅ **Exporte les métriques vers Prometheus**
5. ✅ Vérifie le routage via UPF

### Résultat Attendu
```
================================================
  Test Streaming Vidéo via Slice 5G (SST=1)
================================================

[1/4] Vérification interface 5G...
✓ Interface uesimtun0 active
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

✓ Téléchargement réussi
Temps écoulé: 45s
  Taille fichier: 151M
  Débit moyen: 27.96 Mbps

[3/4] Export des métriques vers Prometheus...
✓ Métriques exportées
  Endpoint: http://localhost:9091/metrics/job/nexslice_test

[4/4] Vérification du routage via UPF...
  IP source (UE): 12.1.1.2
  IP destination: 142.250.185.48
  Gateway UPF: 12.1.1.1
✓ Trafic routé via le tunnel 5G

================================================
✓ Test de streaming terminé avec succès
✓ Consultez Grafana: http://localhost:3000
================================================
```

### Fichiers Générés
```
results/
├── video_20251129_123456.mp4           # Vidéo téléchargée
└── curl_metrics_20251129_123456.txt    # Métriques curl
```

---

## 📊 Script 3: measure-performance.sh

### Description
Mesure détaillée de performance réseau (latence, jitter, débit) avec export Prometheus.

### Utilisation
```bash
cd scripts/
./measure-performance.sh
```

### Ce qu'il fait
1. ✅ **Test 1**: Latence et jitter (100 pings)
2. ✅ **Test 2**: Débit avec iperf3 (optionnel si serveur disponible)
3. ✅ **Test 3**: Statistiques interface réseau
4. ✅ **Exporte toutes les métriques vers Prometheus**
5. ✅ Génère un rapport Markdown

### Résultat Attendu
```
================================================
  Mesures de Performance - Slice eMBB (SST=1)
================================================

[Prérequis] Vérification des outils nécessaires...
✓ Interface uesimtun0 active (IP: 12.1.1.2)

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
✓ Fichier sauvegardé: results/performance/ping_20251129_123456.json
✓ Métriques exportées vers Prometheus

================================================
[Test 2/3] Mesure Débit (iperf3)
================================================
Entrez l'IP du serveur iperf3 (ou appuyez sur Entrée pour sauter):
[attend 10 secondes]
⚠ Test iperf3 ignoré (pas de serveur configuré)

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
✓ Fichier sauvegardé: results/performance/interface_stats_20251129_123456.txt
✓ Métriques exportées vers Prometheus

================================================
  Génération du Rapport
================================================
✓ Rapport généré: results/performance/rapport_performance_20251129_123456.md
✓ Dashboard Grafana mis à jour: http://localhost:3000/d/nexslice
```

### Fichiers Générés
```
results/performance/
├── ping_20251129_123456.json          # Métriques latence (JSON)
├── ping_20251129_123456.txt           # Sortie brute ping
├── interface_stats_20251129_123456.txt # Stats interface
└── rapport_performance_20251129_123456.md # Rapport complet
```

---

## 📈 Monitoring avec Prometheus et Grafana

### Installation et Configuration

#### 1. Déployer Prometheus
```bash
# Créer le namespace monitoring
kubectl create namespace monitoring

# Créer la configuration Prometheus
cat > monitoring/prometheus-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'nexslice'
        replica: '1'

    scrape_configs:
      # Métriques des pods Kubernetes
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - nexslice
                - monitoring
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__

      # Métriques des scripts de test (Pushgateway)
      - job_name: 'pushgateway'
        honor_labels: true
        static_configs:
          - targets: ['pushgateway:9091']

      # Node exporter pour métriques système
      - job_name: 'node-exporter'
        static_configs:
          - targets: ['node-exporter:9100']
            labels:
              node: 'nexslice-node'

      # Métriques réseau personnalisées
      - job_name: 'nexslice-ue'
        static_configs:
          - targets: ['ue-exporter:9102']
            labels:
              slice_type: 'embb'
              sst: '1'
EOF

kubectl apply -f monitoring/prometheus-config.yaml

# Déployer Prometheus
cat > monitoring/prometheus-deployment.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30090
  selector:
    app: prometheus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.console.libraries=/usr/share/prometheus/console_libraries'
          - '--web.console.templates=/usr/share/prometheus/consoles'
          - '--storage.tsdb.retention.time=30d'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        emptyDir: {}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

kubectl apply -f monitoring/prometheus-deployment.yaml
```

#### 2. Déployer Pushgateway (pour les scripts)
```bash
cat > monitoring/pushgateway-deployment.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: pushgateway
  namespace: monitoring
spec:
  type: NodePort
  ports:
    - port: 9091
      targetPort: 9091
      nodePort: 30091
  selector:
    app: pushgateway
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pushgateway
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pushgateway
  template:
    metadata:
      labels:
        app: pushgateway
    spec:
      containers:
      - name: pushgateway
        image: prom/pushgateway:latest
        ports:
        - containerPort: 9091
EOF

kubectl apply -f monitoring/pushgateway-deployment.yaml
```

#### 3. Déployer Grafana
```bash
cat > monitoring/grafana-deployment.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30300
  selector:
    app: grafana
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true
      editable: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        - name: GF_INSTALL_PLUGINS
          value: "grafana-piechart-panel"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
      volumes:
      - name: grafana-storage
        emptyDir: {}
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
EOF

kubectl apply -f monitoring/grafana-deployment.yaml
```

#### 4. Vérifier le déploiement
```bash
# Vérifier que tous les pods sont Running
kubectl get pods -n monitoring

# Devrait afficher:
# NAME                           READY   STATUS    RESTARTS   AGE
# prometheus-xxxxx              1/1     Running   0          2m
# pushgateway-xxxxx             1/1     Running   0          2m
# grafana-xxxxx                 1/1     Running   0          2m

# Accéder aux interfaces
echo "Prometheus: http://localhost:30090"
echo "Pushgateway: http://localhost:30091"
echo "Grafana: http://localhost:30300"
```

---

### Modifier les Scripts pour Exporter vers Prometheus

#### Script d'export des métriques

Créez un fichier `scripts/export-to-prometheus.sh`:
```bash
#!/bin/bash

PUSHGATEWAY_URL="http://localhost:30091"
JOB_NAME="nexslice_test"

# Fonction pour exporter des métriques
export_metric() {
    local metric_name=$1
    local metric_value=$2
    local labels=$3
    
    cat <<EOF | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}${labels}
# TYPE ${metric_name} gauge
${metric_name} ${metric_value}
EOF
}

# Exemple: exporter la latence
export_metric "nexslice_latency_ms" "2.456" "/ue_ip/12.1.1.2/slice_type/embb"

# Exemple: exporter le débit
export_metric "nexslice_throughput_mbps" "27.96" "/ue_ip/12.1.1.2/slice_type/embb"

# Exemple: exporter la perte de paquets
export_metric "nexslice_packet_loss_percent" "0" "/ue_ip/12.1.1.2/slice_type/embb"
```

#### Modifier `measure-performance.sh`

Ajoutez à la fin du script:
```bash
# Export vers Prometheus
echo ""
echo "================================================"
echo "[Export] Envoi des métriques vers Prometheus"
echo "================================================"

PUSHGATEWAY_URL="http://localhost:30091"
JOB_NAME="nexslice_performance"
UE_IP=$(ip addr show uesimtun0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

# Exporter latence
cat <<EOF | curl --silent --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/ue_ip/${UE_IP}/slice_type/embb
# TYPE nexslice_rtt_min_ms gauge
nexslice_rtt_min_ms ${RTT_MIN}
# TYPE nexslice_rtt_avg_ms gauge
nexslice_rtt_avg_ms ${RTT_AVG}
# TYPE nexslice_rtt_max_ms gauge
nexslice_rtt_max_ms ${RTT_MAX}
# TYPE nexslice_jitter_ms gauge
nexslice_jitter_ms ${JITTER}
# TYPE nexslice_packet_loss_percent gauge
nexslice_packet_loss_percent ${PACKET_LOSS}
EOF

echo "✓ Métriques exportées vers Prometheus"
echo "  Endpoint: ${PUSHGATEWAY_URL}/metrics"
```

---

### Dashboards Grafana Recommandés

#### Dashboard 1: Vue d'Ensemble NexSlice

Créez un fichier `monitoring/grafana-dashboard-overview.json`:
```json
{
  "dashboard": {
    "title": "NexSlice - Vue d'Ensemble",
    "panels": [
      {
        "title": "Latence Moyenne (ms)",
        "targets": [
          {
            "expr": "nexslice_rtt_avg_ms{slice_type=\"embb\"}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Débit (Mbps)",
        "targets": [
          {
            "expr": "nexslice_throughput_mbps{slice_type=\"embb\"}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Perte de Paquets (%)",
        "targets": [
          {
            "expr": "nexslice_packet_loss_percent{slice_type=\"embb\"}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Jitter (ms)",
        "targets": [
          {
            "expr": "nexslice_jitter_ms{slice_type=\"embb\"}"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

#### Dashboard 2: Comparaison Multi-Slices

Pour comparer SST 1, 2, 3:
```json
{
  "dashboard": {
    "title": "NexSlice - Comparaison Slices",
    "panels": [
      {
        "title": "Latence par Slice",
        "targets": [
          {
            "expr": "nexslice_rtt_avg_ms",
            "legendFormat": "SST {{sst}} - {{slice_type}}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Débit par Slice",
        "targets": [
          {
            "expr": "nexslice_throughput_mbps",
            "legendFormat": "SST {{sst}} - {{slice_type}}"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

---

### Importer les Dashboards dans Grafana
```bash
# 1. Accéder à Grafana
open http://localhost:30300
# Login: admin / admin

# 2. Ajouter la source de données Prometheus
# - Aller dans Configuration > Data Sources
# - Add data source > Prometheus
# - URL: http://prometheus:9090
# - Save & Test

# 3. Importer les dashboards
# - Aller dans Create > Import
# - Uploader le fichier JSON ou coller le contenu
# - Sélectionner la source de données Prometheus
# - Import
```

---

### Requêtes Prometheus Utiles
```promql
# Latence moyenne sur les 5 dernières minutes
avg_over_time(nexslice_rtt_avg_ms{ue_ip="12.1.1.2"}[5m])

# Débit maximum
max_over_time(nexslice_throughput_mbps{ue_ip="12.1.1.2"}[5m])

# Perte de paquets totale
sum(nexslice_packet_loss_percent{slice_type="embb"})

# Comparaison latence entre slices
nexslice_rtt_avg_ms{sst=~"1|2|3"}

# Alertes si latence > 50ms
nexslice_rtt_avg_ms > 50

# Alertes si perte de paquets > 1%
nexslice_packet_loss_percent > 1
```

---

### Avantages par rapport à Wireshark/tcpdump

| Critère | Wireshark/tcpdump | Prometheus + Grafana |
|---------|-------------------|----------------------|
| **Temps réel** | ❌ Post-mortem | ✅ Live monitoring |
| **Historique** | ❌ Par capture | ✅ 30 jours (configurable) |
| **Alertes** | ❌ Non | ✅ Oui (règles Prometheus) |
| **Multi-UE** | ⚠️ Difficile | ✅ Facile (labels) |
| **Dashboards** | ❌ Non | ✅ Oui (personnalisables) |
| **Comparaison slices** | ⚠️ Manuel | ✅ Automatique |
| **Analyse réseau** | ✅ Détaillée | ⚠️ Métriques agrégées |

**Recommandation**: Utilisez Prometheus+Grafana pour le monitoring continu et les tests de performance. Gardez tcpdump pour le debug approfondi si nécessaire.

---

## 📊 Exploiter les Résultats avec Grafana

### 1. Créer un Rapport Automatique
```bash
# Script pour générer un rapport depuis Prometheus
cat > scripts/generate-report-from-prometheus.sh << 'EOF'
#!/bin/bash

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
EOF

chmod +x scripts/generate-report-from-prometheus.sh
./scripts/generate-report-from-prometheus.sh
```

### 2. Exporter un Dashboard en PDF
```bash
# Installer grafana-reporter
kubectl apply -f monitoring/grafana-reporter-deployment.yaml

# Générer un PDF du dashboard
curl "http://localhost:8686/api/v5/report/nexslice-overview?apitoken=YOUR_API_TOKEN" > rapport_nexslice.pdf
```

### 3. Configurer des Alertes

Créez `monitoring/prometheus-alerts.yaml`:
```yaml
groups:
- name: nexslice_alerts
  interval: 30s
  rules:
  - alert: HighLatency
    expr: nexslice_rtt_avg_ms > 50
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Latence élevée détectée"
      description: "La latence moyenne est de {{ $value }}ms (seuil: 50ms)"

  - alert: PacketLoss
    expr: nexslice_packet_loss_percent > 1
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Perte de paquets détectée"
      description: "Perte de paquets: {{ $value }}% (seuil: 1%)"

  - alert: LowThroughput
    expr: nexslice_throughput_mbps < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Débit faible"
      description: "Débit: {{ $value }} Mbps (seuil: 10 Mbps)"
```

---

## 🎯 Script 4: run-all-tests.sh (MASTER)

### Description
Orchestre l'exécution de tous les tests avec export automatique vers Prometheus.

Le script génère maintenant:
- Métriques temps réel dans Prometheus
- Dashboards Grafana mis à jour
- Rapport final avec lien vers Grafana

### Résultat Attendu
```
================================================
    NexSlice - Suite de Tests Complète
    Monitoring: Prometheus + Grafana
================================================

Date: 2025-11-29 12:34:56
Log: results/test_run_20251129_123456.log

[Étape 0/5] Vérification du monitoring
================================================
✓ Prometheus actif: http://localhost:30090
✓ Pushgateway actif: http://localhost:30091
✓ Grafana actif: http://localhost:30300

[...exécution des tests...]

================================================
✓ Suite de tests terminée avec succès
================================================

📁 Tous les résultats sont dans: results/

📊 Monitoring:
   - Prometheus: http://localhost:30090
   - Grafana: http://localhost:30300
   - Dashboard NexSlice: http://localhost:30300/d/nexslice

📄 Documents générés:
   - Rapport final: results/RAPPORT_FINAL_20251129_123456.md
   - Log complet: results/test_run_20251129_123456.log

🔍 Prochaines étapes recommandées:
   1. Consulter le dashboard Grafana
   2. Vérifier les alertes Prometheus
   3. Comparer les métriques avec les objectifs du projet
```

---

## 💡 Conseils et Bonnes Pratiques

### 1. Monitoring Continu
```bash
# Lancer les tests toutes les 5 minutes
watch -n 300 './scripts/measure-performance.sh'

# Ou via cron
crontab -e
# Ajouter: */5 * * * * /path/to/scripts/measure-performance.sh
```

### 2. Créer des Snapshots Grafana
```bash
# Sauvegarder l'état du dashboard
curl -X POST http://localhost:30300/api/snapshots \
  -H "Content-Type: application/json" \
  -d @dashboard-snapshot.json
```

### 3. Exporter les Métriques pour Analyse
```bash
# Exporter 24h de métriques
curl -G http://localhost:30090/api/v1/query_range \
  --data-urlencode 'query=nexslice_rtt_avg_ms{ue_ip="12.1.1.2"}' \
  --data-urlencode 'start=2025-11-28T00:00:00Z' \
  --data-urlencode 'end=2025-11-29T00:00:00Z' \
  --data-urlencode 'step=15s' > metrics_24h.json
```

---

## 🎓 Utilisation pour la Présentation

### Préparer une Démonstration Live
```bash
# 1. Ouvrir Grafana en plein écran
open http://localhost:30300/d/nexslice?refresh=5s&kiosk

# 2. Lancer les tests en arrière-plan
./scripts/run-all-tests.sh &

# 3. Montrer les métriques en temps réel
# Les graphiques se mettront à jour automatiquement

# 4. Pointer vers des métriques clés
# - Latence stable autour de 2-5ms
# - Débit constant à 25-30 Mbps
# - Zéro perte de paquets
```

---

*Guide d'utilisation avec monitoring Prometheus & Grafana - Projet NexSlice - Groupe 4*