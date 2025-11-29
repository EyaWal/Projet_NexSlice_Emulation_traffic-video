#!/bin/bash

# Setup Monitoring Stack - Prometheus + Grafana + Pushgateway
# NexSlice Project - Groupe 4

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Installation Stack Monitoring - NexSlice${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$MONITORING_DIR/../../monitoring"

# Créer le dossier monitoring s'il n'existe pas
mkdir -p "$MANIFESTS_DIR"

# ============================================
# 1. Créer le namespace monitoring
# ============================================
echo -e "${BOLD}[1/6] Création du namespace monitoring...${NC}"

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

if kubectl get namespace monitoring &> /dev/null; then
    echo -e "${GREEN}✓ Namespace monitoring créé${NC}"
else
    echo -e "${RED}✗ Échec création namespace${NC}"
    exit 1
fi
echo ""

# ============================================
# 2. Déployer Prometheus
# ============================================
echo -e "${BOLD}[2/6] Déploiement de Prometheus...${NC}"

cat > "$MANIFESTS_DIR/prometheus-config.yaml" <<'EOF'
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
        project: 'network-slicing-5g'

    # Règles d'alerte
    rule_files:
      - /etc/prometheus/alerts.yml

    scrape_configs:
      # Métriques Kubernetes
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

      # Pushgateway pour les scripts de test
      - job_name: 'pushgateway'
        honor_labels: true
        static_configs:
          - targets: ['pushgateway:9091']

      # Node exporter
      - job_name: 'node-exporter'
        static_configs:
          - targets: ['localhost:9100']
            labels:
              node: 'nexslice-host'

  alerts.yml: |
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
          summary: "Latence élevée sur slice {{ $labels.slice_type }}"
          description: "RTT moyen: {{ $value }}ms (seuil: 50ms)"

      - alert: PacketLoss
        expr: nexslice_packet_loss_percent > 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Perte de paquets détectée"
          description: "Perte: {{ $value }}% (seuil: 1%)"

      - alert: LowThroughput
        expr: nexslice_throughput_mbps < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Débit faible"
          description: "Débit: {{ $value }} Mbps (seuil: 10 Mbps)"

      - alert: UE_Disconnected
        expr: nexslice_ue_connected == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "UE déconnecté"
          description: "Le UE {{ $labels.ue_ip }} est déconnecté du réseau 5G"
EOF

cat > "$MANIFESTS_DIR/prometheus-deployment.yaml" <<'EOF'
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
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  type: NodePort
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30090
      name: web
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
        image: prom/prometheus:v2.48.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--storage.tsdb.retention.time=30d'
          - '--web.enable-lifecycle'
          - '--web.console.libraries=/usr/share/prometheus/console_libraries'
          - '--web.console.templates=/usr/share/prometheus/consoles'
        ports:
        - containerPort: 9090
          name: web
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        emptyDir: {}
EOF

kubectl apply -f "$MANIFESTS_DIR/prometheus-config.yaml"
kubectl apply -f "$MANIFESTS_DIR/prometheus-deployment.yaml"

echo -e "${GREEN}✓ Prometheus déployé${NC}"
echo ""

# ============================================
# 3. Déployer Pushgateway
# ============================================
echo -e "${BOLD}[3/6] Déploiement de Pushgateway...${NC}"

cat > "$MANIFESTS_DIR/pushgateway-deployment.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: pushgateway
  namespace: monitoring
  labels:
    app: pushgateway
spec:
  type: NodePort
  ports:
    - port: 9091
      targetPort: 9091
      nodePort: 30091
      name: web
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
        image: prom/pushgateway:v1.6.2
        ports:
        - containerPort: 9091
          name: web
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF

kubectl apply -f "$MANIFESTS_DIR/pushgateway-deployment.yaml"

echo -e "${GREEN}✓ Pushgateway déployé${NC}"
echo ""

# ============================================
# 4. Déployer Grafana
# ============================================
echo -e "${BOLD}[4/6] Déploiement de Grafana...${NC}"

cat > "$MANIFESTS_DIR/grafana-datasource.yaml" <<'EOF'
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
      jsonData:
        timeInterval: "15s"
EOF

cat > "$MANIFESTS_DIR/grafana-deployment.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  type: NodePort
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30300
      name: web
  selector:
    app: grafana
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
        image: grafana/grafana:10.2.2
        ports:
        - containerPort: 3000
          name: web
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        - name: GF_INSTALL_PLUGINS
          value: "grafana-piechart-panel,grafana-clock-panel"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: grafana-storage
        emptyDir: {}
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
EOF

kubectl apply -f "$MANIFESTS_DIR/grafana-datasource.yaml"
kubectl apply -f "$MANIFESTS_DIR/grafana-deployment.yaml"

echo -e "${GREEN}✓ Grafana déployé${NC}"
echo ""

# ============================================
# 5. Attendre que les pods soient prêts
# ============================================
echo -e "${BOLD}[5/6] Attente du démarrage des pods...${NC}"

echo -n "Prometheus: "
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s
echo -n "Pushgateway: "
kubectl wait --for=condition=ready pod -l app=pushgateway -n monitoring --timeout=120s
echo -n "Grafana: "
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=120s

echo -e "${GREEN}✓ Tous les pods sont prêts${NC}"
echo ""

# ============================================
# 6. Créer le dashboard Grafana
# ============================================
echo -e "${BOLD}[6/6] Configuration du dashboard Grafana...${NC}"

cat > "$MANIFESTS_DIR/grafana-dashboard-nexslice.json" <<'EOF'
{
  "dashboard": {
    "title": "NexSlice - Monitoring 5G Network Slicing",
    "tags": ["5g", "nexslice", "network-slicing"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Latence Moyenne (RTT)",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "nexslice_rtt_avg_ms",
            "legendFormat": "{{ ue_ip }} - {{ slice_type }}"
          }
        ],
        "yaxes": [
          {"format": "ms", "label": "Latence (ms)"}
        ]
      },
      {
        "id": 2,
        "title": "Débit (Throughput)",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "nexslice_throughput_mbps",
            "legendFormat": "{{ ue_ip }} - {{ slice_type }}"
          }
        ],
        "yaxes": [
          {"format": "Mbps", "label": "Débit (Mbps)"}
        ]
      },
      {
        "id": 3,
        "title": "Perte de Paquets",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "nexslice_packet_loss_percent",
            "legendFormat": "{{ ue_ip }}"
          }
        ],
        "yaxes": [
          {"format": "percent", "label": "Perte (%)"}
        ]
      },
      {
        "id": 4,
        "title": "Jitter",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "nexslice_jitter_ms",
            "legendFormat": "{{ ue_ip }}"
          }
        ],
        "yaxes": [
          {"format": "ms", "label": "Jitter (ms)"}
        ]
      }
    ],
    "refresh": "5s",
    "time": {"from": "now-15m", "to": "now"}
  }
}
EOF

echo -e "${GREEN}✓ Dashboard Grafana configuré${NC}"
echo ""

# ============================================
# Résumé
# ============================================
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}${BOLD}✓ Stack de monitoring installée avec succès${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${BOLD}Accès aux interfaces:${NC}"
echo -e "  🔹 Prometheus:  ${CYAN}http://localhost:30090${NC}"
echo -e "  🔹 Pushgateway: ${CYAN}http://localhost:30091${NC}"
echo -e "  🔹 Grafana:     ${CYAN}http://localhost:30300${NC}"
echo ""
echo -e "${BOLD}Identifiants Grafana:${NC}"
echo -e "  • Username: ${YELLOW}admin${NC}"
echo -e "  • Password: ${YELLOW}admin${NC}"
echo ""
echo -e "${BOLD}Prochaines étapes:${NC}"
echo "  1. Ouvrir Grafana: http://localhost:30300"
echo "  2. Importer le dashboard: monitoring/grafana-dashboard-nexslice.json"
echo "  3. Lancer les tests: ./scripts/run-all-tests.sh"
echo ""

exit 0