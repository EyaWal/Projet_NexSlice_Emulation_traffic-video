#!/bin/bash

# Export de métriques vers Prometheus - NexSlice

PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:30091}"

# Fonction simple d'export
export_metric() {
    local name=$1
    local value=$2
    local ue_ip=$3
    
    curl -s --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/nexslice/ue_ip/${ue_ip}/slice_type/embb" <<EOF
# TYPE ${name} gauge
${name} ${value}
EOF
}

# Exemple d'utilisation:
# export_metric "nexslice_rtt_avg_ms" "2.5" "12.1.1.2"

echo "Fonction export_metric disponible"
echo "Usage: export_metric <nom> <valeur> <ue_ip>"