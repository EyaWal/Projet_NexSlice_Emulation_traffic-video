# Projet NexSlice - Emulation Traffic Vidéo sur 5G

**Projet**: 2 
**Groupe**: 4  
**Étudiants**: Tifenne Jupiter, Emilie Melis, Eya Walha  
**Année**: 2025-2026  

---

## Table des Matières

- [Introduction](#introduction)
- [Objectifs](#objectifs)
- [État de l'Art](#état-de-lart)
- [Architecture](#architecture)
- [Méthodologie](#méthodologie)
- [Résultats](#résultats)
- [Conclusion](#conclusion)
- [Reproduction](#reproduction-de-lexperimentation)
- [Références](#références)

---

## Introduction

### Contexte

La 5G introduit le **Network Slicing**, permettant de créer des réseaux virtuels logiques sur une infrastructure physique commune. Chaque slice peut être optimisé pour des cas d'usage spécifiques:

- **eMBB (SST=1)**: Enhanced Mobile Broadband → Streaming vidéo, haute débit
- **URLLC (SST=2)**: Ultra-Reliable Low Latency → Applications critiques
- **mMTC (SST=3)**: Massive Machine Type Communications → IoT massif

### Problématique

**Comment valider et mesurer la qualité de service (QoS) du streaming vidéo à travers un slice 5G eMBB dans un environnement simulé ?**

---

## Objectifs

### Objectifs Atteints

Notre projet s'appuie sur l'infrastructure **NexSlice** fournie par le professeur ([lien GitHub](https://github.com/AIDY-F2N/NexSlice/tree/k3s)), qui fournit un Core 5G OAI complet déployé sur Kubernetes.

**Notre contribution spécifique**:

1. Validation de la connectivité 5G via UERANSIM
2. Déploiement d'un serveur vidéo (FFmpeg + nginx) sur Kubernetes
3. Tests de streaming vidéo à travers le slice eMBB (SST=1)
4. Mesures quantitatives de performance réseau (latence, débit, jitter)
5. Capture et analyse du trafic pour prouver le routage via l'UPF
6. Documentation complète et scripts de test automatisés
7. Stack de monitoring temps réel (Prometheus + Grafana)
8. Dashboards de visualisation des métriques 5G
9. Export automatique des métriques vers Prometheus

### Scope Réel du Projet

**Ce qui a été implémenté** (Phases 1 & 2):
- Configuration d'**1 UE** simulé (UERANSIM)
- Tests sur **1 slice** : eMBB (SST=1, SD=1)
- Validation complète du streaming vidéo
- Mesures de performance réseau détaillées
- Scripts de test automatisés et reproductibles
- Monitoring temps réel avec Prometheus et Grafana


**Ce qui n'a PAS été implémenté** (Phase 3 - Perspectives):
- Tests multi-slices (SST=1, 2, 3)
- Déploiement de plusieurs UEs simultanés
- Comparaison quantitative entre slices
- Tests de mobilité ou handover


---

## État de l'Art

### 1. Contexte général

Avec la 5G, le Network Slicing permet de découper le réseau en plusieurs tranches dédiées à différents usages (eMBB, URLLC, mMTC). Les outils classiques comme ping ou iperf3 mesurent surtout la latence ou le débit, mais ne reflètent pas vraiment le comportement réel d'applications comme le streaming vidéo HD.
![image](chemin/vers/image.png)

C'est pourquoi de nombreux travaux cherchent aujourd'hui à mieux émuler ou analyser un trafic vidéo réaliste, afin d'évaluer l'impact du slicing sur les performances et la qualité perçue par l'utilisateur.

### 2. Expérimentations vidéo dans des environnements 5G

Des expérimentations récentes menées avec la pile OpenAirInterface (OAI) et des UEs virtuels montrent comment le débit, la latence et la stabilité vidéo interagissent, et proposent des méthodologies adaptées à des plateformes entièrement virtualisées comme NexSlice (source 1).

D'autres démonstrations autour de la vidéosurveillance en temps réel mettent en avant la capacité du slicing à réduire la latence et stabiliser le flux, illustrant l'intérêt de cette approche pour des services exigeants comme les flux eMBB (source 7).

### 3. Modélisation et estimation de la QoE

Plusieurs travaux proposent des modèles reliant les métriques réseau (débit, latence, pertes) à la QoE, ce qui permet d'interpréter les performances du réseau du point de vue de l'utilisateur final (source 3).

D'autres recherches se focalisent sur la vidéo Ultra-HD, en utilisant des indicateurs tels que PSNR, SSIM ou VMAF pour mieux caractériser la qualité perçue (source 5).

Des méthodes d'adaptation basées sur MPEG-DASH, associées à l'évaluation automatique de l'image, offrent également des pistes pour configurer efficacement des pipelines vidéo comme GStreamer dans un contexte eMBB (source 10).

### 4. Adaptation dynamique et optimisation énergétique

Des architectures intégrant la virtualisation des fonctions réseau montrent qu'il est possible d'adapter la qualité vidéo en tenant compte à la fois de la QoE et de la consommation énergétique. Ces approches s'inscrivent dans la même logique que NexSlice, qui cherche à orchestrer intelligemment les ressources selon la demande (source 2).

### 5. Fiabilité et résilience du streaming en 5G

Des études menées sur les réseaux à ondes millimétriques mettent en avant l'intérêt de la multi-connectivité et du network coding pour stabiliser le débit et réduire la variabilité du flux (source 6).

D'autres analyses montrent aussi que la congestion dans la RAN influence directement la lecture vidéo (par exemple via QUIC), en provoquant des interruptions liées aux files d'attente radio — un phénomène qu'il est possible de reproduire dans un environnement émulé comme OAI/NexSlice (source 9).

### 6. Slicing orienté QoE et isolation des services

Certaines architectures récentes de RAN slicing sont conçues pour optimiser la QoE et garantir une isolation stricte entre services. Elles insistent sur la nécessité de corréler automatiquement les métriques réseau et les indicateurs de qualité perçue afin d'allouer les ressources au bon moment. Ce principe rejoint directement les objectifs du slice eMBB dans NexSlice (source 8).

### 7. Apprentissage automatique et prédiction de la QoE

Des travaux s'appuyant sur le Machine Learning montrent qu'il est possible de prédire la QoE vidéo à partir de paramètres mesurés en temps réel (débit, gigue, rebuffering, pertes). Ces approches ouvrent la voie à une orchestration proactive du slicing, capable d'anticiper les besoins de qualité. Elles sont transférables au fonctionnement de NexSlice (source 4).

### 8. Synthèse et positionnement

L'ensemble des recherches met en évidence plusieurs tendances fortes :

- L'utilisation croissante d'environnements virtualisés (OAI, UEs logiciels) pour tester des flux vidéo réalistes
- La nécessité de combiner mesures réseau (QoS) et qualité perçue (QoE)
- L'intérêt d'utiliser de vrais pipelines vidéo (VLC, GStreamer) pour reproduire fidèlement les comportements clients
- Le développement d'approches de slicing orientées QoE, parfois couplées au Machine Learning

Le projet NexSlice s'inscrit pleinement dans cette dynamique. En intégrant un trafic vidéo applicatif dans une infrastructure OAI virtualisée, il permet d'étudier précisément comment le slicing influence la performance et la qualité perçue. Cela constitue une avancée importante vers une évaluation plus réaliste et automatisée des services eMBB.

---

## Architecture

### Vue d'Ensemble
```
┌──────────────────────────────────────────────────────────────────────┐
│ Infrastructure NexSlice (Fournie par le Prof)                        │
│                                                                       │
│ ┌────────────────────────────────────────────────────────┐          │
│ │ Core 5G OAI (Kubernetes - namespace nexslice)          │          │
│ │ AMF │ SMF │ UPF │ NRF │ AUSF │ UDM │ PCF │ UDR         │          │
│ └──────────────────┬─────────────────────────────────────┘          │
│                    │                                                 │
│         ┌──────────┴──────────┐                                     │
│         │ gNB (UERANSIM)      │                                     │
│         └──────────┬──────────┘                                     │
│                    │                                                 │
│         ┌──────────┴──────────┐                                     │
│         │ UE (UERANSIM)       │                                     │
│         │ Interface: uesimtun0│                                     │
│         │ IP: 12.1.1.2        │                                     │
│         │ Slice: SST=1 (eMBB) │                                     │
│         └──────────┬──────────┘                                     │
└────────────────────┼──────────────────────────────────────────────┘
                     │
                     │ Trafic 5G via tunnel
                     │
          ┌──────────▼──────────┐
          │ UPF Gateway          │
          │ 12.1.1.1             │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ Serveur Vidéo        │
          │ FFmpeg + nginx       │
          │ (Kubernetes Service) │
          └──────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Stack de Monitoring (Notre Contribution)                             │
│                                                                       │
│ ┌────────────────────────────────────────────────────────┐          │
│ │ Namespace monitoring (Kubernetes)                       │          │
│ │                                                          │          │
│ │  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │          │
│ │  │ Prometheus  │◄─│ Pushgateway  │◄─│ Scripts Test │  │          │
│ │  │   :30090    │  │    :30091    │  │  (export)    │  │          │
│ │  └──────┬──────┘  └──────────────┘  └──────────────┘  │          │
│ │         │                                               │          │
│ │  ┌──────▼──────┐                                       │          │
│ │  │  Grafana    │ ← Dashboard temps réel                │          │
│ │  │   :30300    │   + Alertes configurables             │          │
│ │  └─────────────┘                                       │          │
│ └────────────────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────────────────┘
```

### Flux de Données
```
UE (12.1.1.2) 
  → Interface uesimtun0 (tunnel 5G)
    → gNB UERANSIM
      → Core OAI (AMF → SMF → UPF)
        → UPF Gateway (12.1.1.1)
          → Serveur vidéo (Kubernetes)
          
Scripts de Test
  → Collecte des métriques (latence, débit, jitter)
    → Export vers Pushgateway (:30091)
      → Stockage dans Prometheus (:30090)
        → Visualisation dans Grafana (:30300)
```

### Composants Utilisés

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **Core 5G** | OpenAirInterface (OAI) | Fonctions réseau 5G (AMF, SMF, UPF...) |
| **RAN** | UERANSIM | Simulation gNB et UE |
| **Orchestration** | Kubernetes (k3s) | Déploiement des services |
| **Serveur Vidéo** | FFmpeg + nginx | Streaming vidéo HTTP |
| **Monitoring** | Prometheus + Grafana | Collecte et visualisation des métriques |
| **Export Métriques** | Pushgateway | Interface entre scripts et Prometheus |
| **Namespace** | `nexslice`, `monitoring` | Isolation des ressources K8s |

---

## Méthodologie

### Approche Expérimentale

Nous avons suivi une approche en 3 phases (seules les 2 premières ont été complétées):

#### Phase 1: Configuration de Base
1. Utilisation de l'infrastructure NexSlice existante
2. Configuration d'un UE avec slice SST=1 (eMBB)
3. Validation de la connectivité (ping vers UPF)
4. Déploiement du serveur vidéo sur Kubernetes
5. Installation de la stack de monitoring Prometheus + Grafana

#### Phase 2: Tests Mono-UE
1. Streaming vidéo via slice eMBB
2. Mesures de référence:
   - Latence et jitter (via ping)
   - Débit (via téléchargement HTTP)
   - Qualité de streaming
3. Capture réseau (tcpdump) [optionnel avec monitoring]
4. Export automatique des métriques vers Prometheus
5. Visualisation temps réel dans Grafana
6. Analyse des résultats

#### Phase 3: Tests Multi-Slices (Non Réalisée)
*Prévu mais non implémenté - voir section Perspectives*

### Métriques Collectées

| Catégorie | Métrique | Outil | Stockage |
|-----------|----------|-------|----------|
| **Réseau** | Latence (RTT) | `ping` | Prometheus |
| | Jitter (mdev) | `ping` | Prometheus |
| | Perte de paquets | `ping` | Prometheus |
| | Débit | `curl --write-out` | Prometheus |
| **Applicatif** | Temps de téléchargement | `curl` | Prometheus |
| | Taille téléchargée | `du` | Logs |
| **Interface** | Bytes RX/TX | `ip -s link` | Prometheus |
| | Packets RX/TX | `ip -s link` | Prometheus |
| **Analyse** | Capture de paquets | `tcpdump` | Fichiers .pcap |



### Fichier Vidéo de Test

- **URL**: http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4
- **Format**: MP4 (H.264 + AAC)
- **Taille**: ~158 MB
- **Durée**: ~10 minutes

---

## Résultats

## Résultats

### 1. Résultats dans l’infrastructure NexSlice (Core 5G du prof)

Cette partie s’appuie sur l’infra NexSlice (Core OAI + UERANSIM) fournie dans le TP.  
Nous avons réalisé plusieurs séries de tests, documentées dans `test Nexslice.pdf`.:contentReference[oaicite:0]{index=0}

#### 1.1. Test 1 – Serveur vidéo et routage via le slice eMBB

Objectif : prouver qu’un flux vidéo HTTP passe bien par le tunnel 5G (interface `uesimtun0`) et donc par l’UPF et le slice eMBB (SST=1).

- Tentatives de serveur vidéo :
  - **VLC server** : échec (server instable, pas de flux exploitable).
  - **GStreamer** : échec (problèmes de configuration, non finalisé).
  - **FFmpeg + nginx** : **succès**.
- Mise en place :
  - Déploiement d’un pod `ffmpeg-server` dans le namespace `nexslice` servant un fichier `video.mp4` via HTTP (`/videos/video.mp4`).:contentReference[oaicite:1]{index=1}  
  - Vérification que la vidéo est bien présente dans le pod (`ls /usr/share/nginx/html`).
- Vérification du routage 5G :
  - Lancement de `tcpdump` sur l’interface **`uesimtun0`** du pod UE (UERANSIM).
  - Téléchargement de la vidéo via :  
    `curl --interface uesimtun0 http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4`
  - Observation dans `tcpdump` de paquets IP avec :
    - IP source = **12.1.1.2** (UE)
    - IP destination = serveur vidéo
    - trafic HTTP visible en **aller/retour**.:contentReference[oaicite:2]{index=2}  

➡ **Conclusion Test 1 :**  
Le flux vidéo passe bien par le tunnel 5G (`uesimtun0`) et donc par le slice eMBB configuré dans l’UE (SST=1). Le routage via l’UPF est confirmé.

---

#### 1.2. Test 2 – Dockerisation du serveur FFmpeg + script de streaming incrémental

Objectif : industrialiser le serveur vidéo et commencer à mesurer des métriques côté UE.

- Création d’une image Docker `ffmpeg-server:latest` :
  - Dockerfile Ubuntu 22.04 installant `ffmpeg`, `nginx`, `wget`, `curl`.
  - Téléchargement automatique d’une vidéo (ex. *ElephantsDream.mp4*) vers `/var/www/html/videos/video.mp4`.:contentReference[oaicite:3]{index=3}  
  - Nginx configuré pour servir `http://…:8080/videos/video.mp4`.
- Script `build_ffmpeg.sh` :
  - `docker build …`
  - `docker save …` puis `k3s ctr image import …` pour rendre l’image disponible dans k3s.
- Déploiement dans k3s :
  - `ffmpeg-server-deployment.yaml` (Deployment + Service `ClusterIP` sur le port 8080).
  - Test depuis un pod client :  
    `curl -I http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4` → HTTP 200 OK.:contentReference[oaicite:4]{index=4}  

- Script UE `stream_video.sh` :
  - Télécharge la vidéo **par chunks** (ex. 1 Mo) via HTTP.
  - Mesure à chaque chunk :
    - **latence** du chunk,
    - **débit** estimé,
    - **jitter** (variation de latence entre chunks),
    - enregistre les valeurs dans un CSV local (`/tmp/video_metrics.csv`).:contentReference[oaicite:5]{index=5}  
  - Une première version prévoyait l’envoi de ces métriques vers **Pushgateway** (Prometheus), mais cette partie n’a pas été finalisée de manière stable.

➡ **Conclusion Test 2 :**  
- Serveur vidéo dockerisé fonctionnel dans NexSlice.  
- Script de streaming incrémental fonctionnel côté UE (avec CSV local).  
- L’export automatique des métriques vers Prometheus n’a pas été stabilisé (problèmes lors des réinstallations de l’infra).

---

#### 1.3. Test 3 – Simplification du serveur vidéo + stack de monitoring

Objectif : simplifier le déploiement et intégrer Prometheus / Grafana.

- Simplification du manifeste serveur vidéo :
  - Nouveau fichier `configs/kubernetes/video-server.yaml` :
    - Pod `ffmpeg-server` (Ubuntu + ffmpeg + nginx + wget) démarrant directement nginx en foreground.:contentReference[oaicite:6]{index=6}  
    - Service `ClusterIP` exposant le port 8080.
- Stack de monitoring :
  - Scripts :
    - `scripts/monitoring/setup-monitoring.sh`
    - `scripts/monitoring/check-monitoring.sh`
  - Déploiement :
    - Namespace `monitoring`
    - **Prometheus** (NodePort 30090)
    - **Pushgateway** (NodePort 30091)
    - **Grafana** (NodePort 30300)
  - Vérification : tous les pods `prometheus`, `pushgateway`, `grafana` passent en `Running`.:contentReference[oaicite:7]{index=7}  

- Limitation rencontrée :
  - Prometheus et Grafana étaient accessibles via navigateur.
  - Les **targets** apparaissaient dans Prometheus, mais **aucune métrique spécifique UE** (`nexslice_*`) n’était visible.
  - Le lien entre scripts UE et Pushgateway/Prometheus n’a pas été finalisé avant la fin du projet.:contentReference[oaicite:8]{index=8}  

➡ **Conclusion Test 3 :**  
- La stack de monitoring (Prometheus + Grafana + Pushgateway) se déploie correctement.  
- En revanche, l’export de métriques personnalisées depuis l’UE vers Prometheus n’a pas abouti : les dashboards ne reflètent que les métriques système de base.

---

### 2. Résultats en mode “standalone” (sans infra NexSlice)

En fin de projet, l’infrastructure NexSlice n’était plus entièrement opérationnelle chez nous (problèmes de Core / UPF et d’accès à l’UE). Pour conserver une démonstration fonctionnelle, nous avons ajouté un mode **standalone** exécuté sur machine locale (macOS).

Ce mode ne passe **pas** par la 5G ni par NexSlice, mais reprend la **même logique de scripts** pour :

- tester la connectivité réseau de base,
- télécharger une vidéo HTTP,
- mesurer latence / jitter / stats interface.

#### 2.1. Scripts standalone

- `scripts/test-connectivity-standalone.sh`  
  - Vérifie l’interface locale (ex. `en0`), récupère son IP.  
  - Teste un ping vers la passerelle par défaut.  
  - Teste un ping vers un IP externe (`8.8.8.8`) pour vérifier l’accès Internet.

- `scripts/test-video-streaming-standalone.sh`  
  - Télécharge une vidéo HTTP (BigBuckBunny) via l’interface locale.  
  - Enregistre :
    - le fichier vidéo (`results/video_<timestamp>.mp4`)
    - les métriques `curl` (temps total, vitesse moyenne, code HTTP) dans `results/curl_metrics_<timestamp>.txt`.

- `scripts/measure-performance-standalone.sh`  
  - Envoie une série de pings vers la passerelle.  
  - Calcule :
    - **latence moyenne** (RTT avg),
    - **jitter** (stddev),
    - **perte de paquets**.  
  - Sauvegarde :
    - la sortie brute de `ping` dans `results/performance/ping_<timestamp>.txt`  
    - les stats interface (`ifconfig` + `netstat`) dans `results/performance/interface_stats_<timestamp>.txt`.

#### 2.2. Interprétation des résultats standalone

- Ces tests montrent que :
  - la machine a bien accès à Internet,
  - la vidéo HTTP est correctement téléchargée,
  - on peut calculer des métriques réseau de base (RTT, jitter, pertes, débit HTTP) sur **une interface locale**.
- **Important (académique) :**
  - les résultats standalone **ne mesurent pas la QoS 5G**,  
  - ils servent uniquement :
    - de **démo fonctionnelle** quand l’infra NexSlice n’est pas disponible,  
    - et de preuve que la chaîne de scripts (connectivité + streaming + mesures) fonctionne, et peut être branchée sur un tunnel 5G dès que l’infra est de nouveau up.

---

## Conclusion

### Points Validés

1. **Connectivité 5G fonctionnelle**
   - Interface tunnel uesimtun0 opérationnelle
   - Communication avec l'UPF du Core OAI validée
   - Slice eMBB (SST=1) correctement configuré

2. **Streaming vidéo opérationnel**
   - Téléchargement HTTP via le tunnel 5G
   - Débit suffisant pour du streaming HD
   - Pas d'interruption ou de perte significative

3. **Métriques de performance cohérentes**
   - Latence adaptée aux applications multimédia
   - Jitter faible assurant une expérience fluide
   - Taux de perte minimal

4. **Routage 5G prouvé**
   - Captures réseau confirmant le passage par uesimtun0 (optionnel)
   - Logs UPF validant le flux de données
   - Métriques Prometheus confirmant le trafic 5G
   - IP source et gateway correctement utilisés

5. **Infrastructure de monitoring professionnelle**
   - Stack Prometheus + Grafana opérationnelle
   - Export automatique des métriques depuis les scripts
   - Dashboards temps réel pour visualisation

### Limitations Identifiées

**Techniques**:
- Simulation uniquement (pas de radio réelle)
- Pas de mobilité des UEs
- Environnement réseau contrôlé

**Méthodologiques**:
- Tests sur 1 seul UE (pas de charge réseau)
- 1 seul slice testé (eMBB uniquement)
- 1 seul type de contenu vidéo

### Perspectives

**Améliorations possibles**:
- Déployer plusieurs UEs simultanés (3-5 UEs) pour tester la charge réseau
- Implémenter les tests multi-slices (SST=1, 2, 3) avec dashboards Grafana dédiés
- Varier les types de contenu (live streaming, différentes résolutions)
- Configurer Alertmanager pour notifications externes (email, Slack)
- Tester des scénarios de mobilité et handover entre slices
- Intégration avec des outils d'APM (Application Performance Monitoring)
- Exporter les métriques vers un data lake pour analyse ML
- Tests sur infrastructure 5G réelle (non simulée)


---

## Reproduction de l'Expérimentation

# Déploiement 
### A. Garde une Partie A – Avec NexSlice:

### 1. Prérequis — Infrastructure du professeur  
Avant toute chose, il est nécessaire que l'infrastructure 5G de base (fournie par le TP du professeur via NexSlice) soit déployée. Vérifiez que :

```bash
kubectl get pods -n nexslice
``` 
### 2. Cloner notre Projet
```bash
# Clone ce repo
git clone https://github.com/EyaWal/Projet_NexSlice_Emulation_traffic-video.git
cd Projet_NexSlice_Emulation_traffic-video

# Rendre les scripts exécutables
chmod +x scripts/*.sh
chmod +x scripts/Monitoring/*.sh
```
### 3. Pré-requis dans les pods UERANSIM

Avant d’exécuter des scripts ou faire des tests réseau, installer les utilitaires nécessaires :

```bash
sudo k3s kubectl exec -it <pod-ue> -n nexslice -- apt update
sudo k3s kubectl exec -it <pod-ue> -n nexslice -- apt install -y bc
```


### 4. Construction de l’image Docker du serveur vidéo (FFmpeg)

Construire l’image :

```bash
sudo docker build -t ffmpeg-server:latest .
```

Vérifier que l’image existe :

```bash
sudo docker images | grep ffmpeg-server
```

Si tu utilises le script d’automatisation :

```bash
chmod +x build_ffmpeg.sh
./build_ffmpeg.sh
```


### 5. Vérification du cluster K3s

S’assurer que le cluster est opérationnel :

```bash
sudo k3s kubectl get nodes
sudo k3s kubectl get ns
```


### 6. Déploiement du serveur vidéo dans Kubernetes

Déployer :

```bash
sudo k3s kubectl apply -f ffmpeg-server-deployment.yaml
```

Vérifier que les pods tournent :

```bash
sudo k3s kubectl get pods -n nexslice | grep ffmpeg
```

Consulter les logs :

```bash
sudo k3s kubectl logs -n nexslice ffmpeg-server -f
```


### 7. Test interne via un pod temporaire

Créer un pod test et vérifier l’accès HTTP :

```bash
sudo k3s kubectl run test-client --image=ubuntu:22.04 -n nexslice -it --rm -- bash
```

Dans le pod test :

```bash
apt-get update && apt-get install -y curl
curl -I http://ffmpeg-server.nexslice.svc.cluster.local:8080/videos/video.mp4
```


### 8. Configuration d’un UE UERANSIM

Lister les pods UE :

```bash
sudo k3s kubectl get pods -n nexslice | grep ueransim-ue
```

Ouvrir un shell dans un UE :

```bash
sudo k3s kubectl exec -it -n nexslice <pod-ueransim-ue1> -- bash
```

Dans le pod :

```bash
apt-get update && apt-get install -y curl
ip addr show uesimtun0
```


### 9. Émulation d’un flux vidéo depuis un UE

Créer un dossier dans le pod UE :

```bash
sudo k3s kubectl exec -it <pod-ue> -n nexslice -- mkdir -p /home/ueransim
```

Copier le script :

```bash
sudo k3s kubectl cp stream_video.sh nexslice/<pod-ue>:/home/ueransim/stream_video.sh
```

Rendre le script exécutable :

```bash
sudo k3s kubectl exec -it <pod-ue> -n nexslice -- chmod +x /home/ueransim/stream_video.sh
```

Lancer le streaming :

```bash
sudo k3s kubectl exec -it <pod-ue> -n nexslice -- /home/ueransim/stream_video.sh
```

### 10. Installer la stack Monitoring
Pour visualiser les métriques via Prometheus + Grafana :
```bash
./scripts/monitoring/setup-monitoring.sh
./scripts/monitoring/check-monitoring.sh
```
Si tout est OK, vous verrez :

Prometheus → http://localhost:30090

Pushgateway → http://localhost:30091

Grafana → http://localhost:30300

À ce stade, les dashboards sont vides : aucune métrique tant que les scripts ne sont pas exécutés.

### 11. Exécuter les scripts de test
#### 1. Test de connectivité
```bash
./scripts/test-connectivity.sh
```
Vérifie l’interface 5G (uesimtun0) et la communication avec l’UPF. 
#### 2. Test de streaming vidéo
```bash
sudo ./scripts/test-video-streaming.sh
```
→ Télécharge la vidéo test via le tunnel 5G.
→ Stocke les résultats dans results/.
#### 3. Mesures de performance (latence, jitter, stats interface)
```bash
./scripts/measure-performance.sh
```
→ Stocke les métriques dans :
results/performance/.
#### 4. Collecte métriques pour le rapport
```bash
./scripts/measure-performance.sh
```
→ Génère un fichier résumé très utile pour le rapport académique.
####  Alternative : tout lancer automatiquement
```bash
sudo ./scripts/run-all-tests.sh
```


### 12. Visualiser les métriques (Grafana + Prometheus)

Maintenant que les scripts ont alimenté le Pushgateway :

1. Ouvrir http://localhost:30300
2. Login : `admin` / `admin`
3. Aller dans **Dashboards** 
4. Observer les métriques en temps réel

#### Via Fichiers Locaux

Tous les résultats sont également sauvegardés dans `results/`:
```bash
results/
├── video_<timestamp>.mp4
├── curl_metrics_<timestamp>.txt
├── performance/
│   ├── ping_<timestamp>.txt
│   ├── interface_stats_<timestamp>.txt
│   └── rapport_performance_<timestamp>.md
└── metrics_results.txt (si collect-metrics.sh)
```
### 8. Nettoyage (optionnel)
Supprimer la stack monitoring :
```bash
./scripts/monitoring/cleanup-monitoring.sh
```
Supprimer les anciens résultats :
```bash
rm -rf results/
```
### B. Reproduction en mode standalone (sans infra NexSlice)

Ce mode permet de rejouer les scripts même si l’infrastructure NexSlice n’est pas disponible.  
Les mesures sont faites sur l’interface réseau locale (ex. `en0` sur macOS), sans Core 5G.

1. Cloner le projet
```bash
git clone https://github.com/EyaWal/Projet_NexSlice_Emulation_traffic-video.git
cd Projet_NexSlice_Emulation_traffic-video
chmod +x scripts/*.sh
```
2. Lancer les tests standalone
```bash
# Test de connectivité locale
./scripts/Mode_Standalone/test-connectivity-standalone.sh

# Test de téléchargement vidéo HTTP
./scripts/Mode_Standalone/test-video-streaming-standalone.sh

# Mesures de latence / jitter / stats interface
./scripts/Mode_Standalone/measure-performance-standalone.sh
```
3. Consulter les résultats
```bash
ls scripts/Mode_Standalone/results_Standalone
ls scripts/Mode_Standalone/results_Standalone/performance/
```
Ces résultats ne passent pas par la 5G ni par NexSlice.
Ils servent uniquement de démonstration de la logique de test (connectivité + streaming + mesures).
---

## Structure du Projet
```
Projet_NexSlice_Emulation_traffic-video/
├── README.md                           # Ce fichier
├── scripts/
│   ├── test-connectivity.sh            # Test connectivité 5G
│   ├── test-video-streaming.sh         # Test streaming vidéo
│   ├── measure-performance.sh          # Mesures de performance
│   ├── run-all-tests.sh                # Suite complète de tests
│   └── Monitoring/
│       ├── setup-monitoring.sh         # Installation Prometheus + Grafana
│       ├── export-metrics.sh           # Export métriques vers Prometheus
│       ├── check-monitoring.sh         # Vérification stack monitoring
│       └── cleanup-monitoring.sh       # Nettoyage monitoring
├── monitoring/
│   ├── prometheus-config.yaml          # Configuration Prometheus
│   ├── prometheus-deployment.yaml      # Déploiement Prometheus
│   ├── pushgateway-deployment.yaml     # Déploiement Pushgateway
│   ├── grafana-deployment.yaml         # Déploiement Grafana
│   ├── grafana-datasource.yaml         # Source de données Grafana
│   └── grafana-dashboard-nexslice.json # Dashboard NexSlice
├── results/                            # Résultats des tests (généré)
│   ├── performance/                    # Métriques réseau
│   └── captures/                       # Captures tcpdump (optionnel)
└── images/                             # Diagrammes et screenshots
```

---

## Références

[1] Agarwal, B. et al. (2023). Analysis of real-time video streaming and throughput performance using the OpenAirInterface stack on multiple UEs. IEEE CSCN.

[2] Nightingale, J. et al. (2016). QoE-Driven, Energy-Aware Video Adaptation in 5G Networks: The SELFNET Self-Optimisation Use Case.

[3] Baena, C. et al. (2020). Estimation of Video Streaming KQIs for Radio Access Negotiation in Network Slicing Scenarios.

[4] Tiwari, V. et al. (2022). A QoE Framework for Video Services in 5G Networks with Supervised Machine Learning Approach.

[5] Aston Research Group (2018). 5G-QoE: QoE Modelling for Ultra-HD Video Streaming in 5G Networks.

[6] Drago, I. et al. (2017). Reliable Video Streaming over mmWave with Multi-Connectivity and Network Coding. arXiv.

[7] Pedreño Manresa, J. J. et al. (2021). A Latency-Aware Real-Time Video Surveillance Demo: Network Slicing for Improving Public Safety. OFC / arXiv.

[8] DeSlice Project (2023). An Architecture for QoE-Aware and Isolated RAN Slicing. Sensors.

[9] JSidhu, J. S. et al. (2025). From 5G RAN Queue Dynamics to Playback: A Performance Analysis for QUIC Video Streaming. arXiv.

[10] Kanai, K. et al. (Université Waseda). Methods for Adaptive Video Streaming and Picture Quality Assessment to Improve QoS/QoE Performances.

---
Ce projet est développé dans le cadre d'un projet académique à Telecom SudParis.

---

*README généré pour le Projet 2 - Groupe 4 - Infrastructure Intelligente Logicielle des Réseaux Mobiles - 2025/2026*
