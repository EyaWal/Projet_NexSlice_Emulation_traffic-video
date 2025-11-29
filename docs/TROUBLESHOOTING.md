# Troubleshooting

## Interface uesimtun0 absente
```bash
sudo k3s kubectl logs -n nexslice <pod-ue>
```

## Pas de connectivité
```bash
sudo k3s kubectl get pods -n nexslice
sudo k3s kubectl logs -n nexslice ffmpeg-server
```
