# 📘 Guide d'Utilisation des Scripts - NexSlice

## 🎯 Vue d'Ensemble

Ce guide vous explique comment utiliser les 4 scripts de test fournis pour valider votre infrastructure 5G et collecter des métriques de performance.

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
Teste le streaming vidéo via le tunnel 5G avec métriques détaillées.

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
4. ✅ Capture le trafic réseau (tcpdump)
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

[3/4] Capture réseau (optionnel)...
Lancement capture tcpdump pendant 10s...
✓ Capture terminée: 1234 paquets
  Fichier: results/captures/capture_20251129_123456.pcap

[4/4] Vérification du routage via UPF...
  IP source (UE): 12.1.1.2
  IP destination: 142.250.185.48
  Gateway UPF: 12.1.1.1
✓ Trafic routé via le tunnel 5G

================================================
✓ Test de streaming terminé avec succès
================================================
```

### Fichiers Générés
```
results/
├── video_20251129_123456.mp4           # Vidéo téléchargée
├── curl_metrics_20251129_123456.txt    # Métriques curl
└── captures/
    └── capture_20251129_123456.pcap    # Capture réseau
```

### Analyse des Captures

**Avec Wireshark (interface graphique)**:
```bash
wireshark results/captures/capture_*.pcap
```

Filtres utiles dans Wireshark:
- `ip.src == 12.1.1.2` → Paquets envoyés par le UE
- `http` → Trafic HTTP uniquement
- `tcp` → Trafic TCP

**Avec tcpdump (ligne de commande)**:
```bash
# Voir les 20 premiers paquets
tcpdump -r results/captures/capture_*.pcap -nn | head -20

# Filtrer par IP source
tcpdump -r results/captures/capture_*.pcap -nn src 12.1.1.2

# Statistiques
tcpdump -r results/captures/capture_*.pcap -q | wc -l
```

---

## 📊 Script 3: measure-performance.sh

### Description
Mesure détaillée de performance réseau (latence, jitter, débit).

### Utilisation
```bash
cd scripts/
./measure-performance.sh
```

### Ce qu'il fait
1. ✅ **Test 1**: Latence et jitter (100 pings)
2. ✅ **Test 2**: Débit avec iperf3 (optionnel si serveur disponible)
3. ✅ **Test 3**: Statistiques interface réseau
4. ✅ Génère un rapport Markdown

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

================================================
  Génération du Rapport
================================================
✓ Rapport généré: results/performance/rapport_performance_20251129_123456.md
```

### Fichiers Générés
```
results/performance/
├── ping_20251129_123456.json          # Métriques latence (JSON)
├── ping_20251129_123456.txt           # Sortie brute ping
├── interface_stats_20251129_123456.txt # Stats interface
└── rapport_performance_20251129_123456.md # Rapport complet
```

### Interpréter les Résultats

**Latence**:
- ✅ Excellent: < 10 ms
- ✅ Bon: 10-50 ms (adapté au streaming)
- ⚠️ Acceptable: 50-100 ms
- ❌ Problématique: > 100 ms

**Jitter**:
- ✅ Excellent: < 5 ms
- ✅ Bon: 5-10 ms
- ⚠️ À surveiller: > 10 ms

**Perte de paquets**:
- ✅ Excellent: 0%
- ✅ Acceptable: < 1%
- ⚠️ Problématique: 1-5%
- ❌ Critique: > 5%

---

## 🎯 Script 4: run-all-tests.sh (MASTER)

### Description
Orchestre l'exécution de tous les tests de manière séquentielle et génère un rapport final.

### Utilisation
```bash
cd scripts/
sudo ./run-all-tests.sh
```

⚠️ **Nécessite sudo** pour les captures réseau

### Ce qu'il fait
```
[Étape 0/4] Vérification des prérequis
  ├── Vérifier présence des scripts
  ├── Vérifier outils (ping, curl, tcpdump, iperf3, jq, bc)
  └── Vérifier permissions

[Étape 1/4] Test de Connectivité 5G
  └── Exécute test-connectivity.sh

[Étape 2/4] Test de Streaming Vidéo
  └── Exécute test-video-streaming.sh

[Étape 3/4] Mesures de Performance Réseau
  └── Exécute measure-performance.sh

[Étape 4/4] Génération du Rapport Final
  ├── Compile tous les résultats
  ├── Génère RAPPORT_FINAL.md
  └── Résumé des fichiers créés
```

### Résultat Attendu
```
================================================
    NexSlice - Suite de Tests Complète
    Projet 5G Network Slicing - Groupe 4
================================================

Date: 2025-11-29 12:34:56
Log: results/test_run_20251129_123456.log

[Étape 0/4] Vérification des prérequis
================================================
✓ Tous les scripts sont présents
✓ Tous les outils sont installés

[...exécution des tests...]

================================================
✓ Suite de tests terminée avec succès
================================================

📁 Tous les résultats sont dans: results/

📄 Documents générés:
   - Rapport final: results/RAPPORT_FINAL_20251129_123456.md
   - Log complet: results/test_run_20251129_123456.log

📊 Pour visualiser le rapport:
   cat results/RAPPORT_FINAL_20251129_123456.md

🔍 Prochaines étapes recommandées:
   1. Analyser les captures réseau avec Wireshark
   2. Comparer les métriques avec les objectifs du projet
   3. Documenter les observations dans le README
```

### Fichiers Générés

Le script génère une structure complète de résultats:

```
results/
├── RAPPORT_FINAL_20251129_123456.md      # 📄 Rapport final complet
├── test_run_20251129_123456.log          # 📋 Log de toute l'exécution
├── performance/
│   ├── ping_20251129_123456.json         # Métriques latence (JSON)
│   ├── ping_20251129_123456.txt          # Sortie brute ping
│   ├── interface_stats_20251129_123456.txt
│   └── rapport_performance_20251129_123456.md
├── captures/
│   └── capture_20251129_123456.pcap      # Capture réseau
├── video_20251129_123456.mp4             # Vidéo téléchargée
└── curl_metrics_20251129_123456.txt      # Métriques HTTP
```

---

## 📈 Exploiter les Résultats

### 1. Récupérer les Métriques pour votre README

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

### 3. Créer un Tableau de Résultats

```bash
# Script pour générer un tableau Markdown
cat > generate_table.sh << 'EOF'
#!/bin/bash
PING_JSON=$(ls -t results/performance/ping_*.json | head -1)
CURL_LOG=$(ls -t results/curl_metrics_*.txt | head -1)

RTT_AVG=$(jq -r '.results.rtt_avg_ms' "$PING_JSON")
JITTER=$(jq -r '.results.jitter_ms' "$PING_JSON")
LOSS=$(jq -r '.results.packet_loss_percent' "$PING_JSON")

BYTES_PER_SEC=$(grep "Vitesse download:" "$CURL_LOG" | awk '{print $3}')
DEBIT_MBPS=$(echo "scale=2; $BYTES_PER_SEC * 8 / 1000000" | bc)

echo "| Métrique | Valeur |"
echo "|----------|--------|"
echo "| Latence moyenne | ${RTT_AVG} ms |"
echo "| Jitter | ${JITTER} ms |"
echo "| Perte de paquets | ${LOSS}% |"
echo "| Débit moyen | ${DEBIT_MBPS} Mbps |"
EOF

chmod +x generate_table.sh
./generate_table.sh
```

---

## 🐛 Dépannage Commun

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

### Erreur: "Permission denied" pour tcpdump

**Cause**: tcpdump nécessite des privilèges root.

**Solution**:
```bash
# Relancer avec sudo
sudo ./scripts/test-video-streaming.sh
sudo ./scripts/run-all-tests.sh
```

### Warning: "iperf3 server not accessible"

**Cause**: Pas de serveur iperf3 disponible (normal).

**Solution**: Ce test est optionnel. Pour l'activer:
```bash
# Sur une autre machine accessible:
iperf3 -s

# Puis relancer le script et entrer l'IP du serveur quand demandé
```

---

## 💡 Conseils et Bonnes Pratiques

### 1. Exécuter les Tests dans l'Ordre

Toujours commencer par le test de connectivité:
```bash
./test-connectivity.sh    # D'abord
./test-video-streaming.sh # Ensuite
./measure-performance.sh  # Puis
```

Ou utiliser le script maître:
```bash
sudo ./run-all-tests.sh   # Tout automatiquement
```

### 2. Sauvegarder les Résultats

```bash
# Créer une archive des résultats
tar -czf resultats_$(date +%Y%m%d).tar.gz results/

# Copier dans un endroit sûr
cp resultats_*.tar.gz ~/backup/
```

### 3. Répéter les Tests

Pour des résultats fiables, répétez les tests 3 fois:
```bash
for i in 1 2 3; do
    echo "=== Test $i/3 ==="
    sudo ./scripts/run-all-tests.sh
    sleep 60  # Attendre 1 minute entre les tests
done
```

### 4. Documenter les Conditions de Test

Notez toujours:
- Date et heure
- Version du Core 5G
- Configuration du UE
- Conditions réseau (charge, etc.)

---

## 🎓 Utilisation pour la Présentation

### Créer une Démonstration Live

```bash
# Script de démo pour présentation
cat > demo.sh << 'EOF'
#!/bin/bash
echo "=== Démonstration NexSlice ==="
echo ""
echo "1. Vérification infrastructure..."
kubectl get pods -n nexslice
sleep 3

echo ""
echo "2. Test connectivité 5G..."
./scripts/test-connectivity.sh
sleep 3

echo ""
echo "3. Streaming vidéo via slice eMBB..."
sudo ./scripts/test-video-streaming.sh
EOF

chmod +x demo.sh
./demo.sh
```

### Préparer des Captures d'Écran

```bash
# Pendant les tests, prenez des screenshots de:
# 1. kubectl get pods -n nexslice
# 2. ip addr show uesimtun0
# 3. ./test-connectivity.sh (résultats)
# 4. Wireshark avec capture

# Sauvegarder dans images/
mkdir -p images/
# Copiez vos screenshots ici
```

---

## 📞 Support

Si vous rencontrez des problèmes:

1. Vérifiez d'abord la section **Dépannage** ci-dessus
2. Consultez les logs: `cat results/test_run_*.log`
3. Vérifiez l'infrastructure: `kubectl get pods -n nexslice`
4. Demandez de l'aide avec les logs complets

---

*Guide d'utilisation des scripts - Projet NexSlice - Groupe 4*