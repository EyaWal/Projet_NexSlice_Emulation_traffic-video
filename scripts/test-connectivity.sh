#!/bin/bash
UE_POD="${1:-ueransim-ue1-ueransim-ues-64d67cf8bd-2zbls}"
NAMESPACE="nexslice"

echo "Test interface uesimtun0..."
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- ip addr show uesimtun0

echo ""
echo "Test ping UPF..."
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- ping -I uesimtun0 -c 5 12.1.1.1

echo ""
echo "Test ping serveur..."
sudo k3s kubectl exec -n $NAMESPACE $UE_POD -- ping -I uesimtun0 -c 5 ffmpeg-server.nexslice.svc.cluster.local
