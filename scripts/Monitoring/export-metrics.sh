#!/bin/bash

# Export Metrics to Prometheus Pushgateway
# Usage: ./export-metrics.sh <metric_name> <value> <labels>

set -e

# Configuration
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:30091}"
JOB_NAME="${JOB_NAME:-nexslice_test}"

# Fonction d'export
export_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local metric_type="${3:-gauge}"
    local labels="$4"
    
    if [ -z "$metric_name" ] || [ -z "$metric_value" ]; then
        echo "Usage: export_metric <name> <value> [type] [labels]"
        return 1
    fi
    
    # Construire l'URL avec labels
    local url="${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}"
    if [ -n "$labels" ]; then
        url="${url}${labels}"
    fi
    
    # Envoyer la métrique
    cat <<EOF | curl --silent --data-binary @- "$url"
# TYPE ${metric_name} ${metric_type}
${metric_name} ${metric_value}
EOF
    
    if [ $? -eq 0 ]; then
        return 0
    else
        echo "Erreur lors de l'export de ${metric_name}" >&2
        return 1
    fi
}

# Export de métriques multiples depuis un fichier JSON
export_from_json() {
    local json_file="$1"
    local ue_ip="$2"
    local slice_type="$3"
    
    if [ ! -f "$json_file" ]; then
        echo "Fichier JSON introuvable: $json_file" >&2
        return 1
    fi
    
    # Labels communs
    local labels="/ue_ip/${ue_ip}/slice_type/${slice_type}"
    
    # Extraire et exporter les métriques
    local rtt_min=$(jq -r '.results.rtt_min_ms' "$json_file")
    local rtt_avg=$(jq -r '.results.rtt_avg_ms' "$json_file")
    local rtt_max=$(jq -r '.results.rtt_max_ms' "$json_file")
    local jitter=$(jq -r '.results.jitter_ms' "$json_file")
    local packet_loss=$(jq -r '.results.packet_loss_percent' "$json_file")
    
    export_metric "nexslice_rtt_min_ms" "$rtt_min" "gauge" "$labels"
    export_metric "nexslice_rtt_avg_ms" "$rtt_avg" "gauge" "$labels"
    export_metric "nexslice_rtt_max_ms" "$rtt_max" "gauge" "$labels"
    export_metric "nexslice_jitter_ms" "$jitter" "gauge" "$labels"
    export_metric "nexslice_packet_loss_percent" "$packet_loss" "gauge" "$labels"
    
    # Métrique de connexion
    export_metric "nexslice_ue_connected" "1" "gauge" "$labels"
}

# Export de métriques de streaming
export_streaming_metrics() {
    local total_time="$1"
    local download_speed_mbps="$2"
    local ue_ip="$3"
    local slice_type="$4"
    
    local labels="/ue_ip/${ue_ip}/slice_type/${slice_type}"
    
    export_metric "nexslice_download_time_seconds" "$total_time" "gauge" "$labels"
    export_metric "nexslice_throughput_mbps" "$download_speed_mbps" "gauge" "$labels"
}

# Export de métriques d'interface
export_interface_metrics() {
    local interface="$1"
    local ue_ip="$2"
    
    # Récupérer les stats de l'interface
    local stats=$(ip -s link show "$interface" 2>/dev/null | grep -A1 "RX:\|TX:")
    
    if [ -z "$stats" ]; then
        echo "Interface $interface introuvable" >&2
        return 1
    fi
    
    local rx_bytes=$(echo "$stats" | grep -A1 "RX:" | tail -1 | awk '{print $1}')
    local rx_packets=$(echo "$stats" | grep -A1 "RX:" | tail -1 | awk '{print $2}')
    local tx_bytes=$(echo "$stats" | grep -A1 "TX:" | tail -1 | awk '{print $1}')
    local tx_packets=$(echo "$stats" | grep -A1 "TX:" | tail -1 | awk '{print $2}')
    
    local labels="/ue_ip/${ue_ip}/interface/${interface}"
    
    export_metric "nexslice_interface_rx_bytes" "$rx_bytes" "counter" "$labels"
    export_metric "nexslice_interface_rx_packets" "$rx_packets" "counter" "$labels"
    export_metric "nexslice_interface_tx_bytes" "$tx_bytes" "counter" "$labels"
    export_metric "nexslice_interface_tx_packets" "$tx_packets" "counter" "$labels"
}

# Si appelé directement avec des arguments
if [ "$#" -ge 2 ]; then
    export_metric "$@"
fi