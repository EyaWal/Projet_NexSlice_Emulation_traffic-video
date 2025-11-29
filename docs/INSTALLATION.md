# Installation NexSlice

## Déploiement
```bash
sudo k3s kubectl create namespace nexslice
sudo k3s kubectl apply -f configs/kubernetes/ffmpeg-server.yaml
sudo k3s kubectl get pods -n nexslice
```

## Tests
```bash
./scripts/run-tests.sh <nom-pod-ue>
```
