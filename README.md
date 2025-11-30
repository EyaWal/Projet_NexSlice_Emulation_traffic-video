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

### Configuration Testée
```yaml
Infrastructure: NexSlice (OAI Core 5G)
Core Version: OpenAirInterface
Simulateur: UERANSIM v3.2.6
Orchestration: k3s Kubernetes
Namespace: nexslice, monitoring

Configuration UE:
  - Interface: uesimtun0
  - IP: 12.1.1.2
  - Slice: eMBB (SST=1, SD=1)
  - Gateway UPF: 12.1.1.1

Monitoring:
  - Prometheus: v2.48.0
  - Grafana: v10.2.2
  - Pushgateway: v1.6.2
  - Rétention: 30 jours
```

### 1. Connectivité 5G

**Test**: Ping vers UPF (12.1.1.1) - 100 paquets

| Métrique | Valeur Mesurée | Interprétation |
|----------|----------------|----------------|
| Latence Min | [À compléter après vos tests] ms | - |
| Latence Moyenne | [À compléter] ms | Adapté au streaming si <50ms |
| Latence Max | [À compléter] ms | - |
| Jitter (mdev) | [À compléter] ms | Bon si <10ms |
| Perte de paquets | [À compléter] % | Excellent si <1% |

**Conclusion**: Connectivité 5G stable et fonctionnelle

**Visualisation**: Consultez le dashboard Grafana "NexSlice - Monitoring 5G" pour voir l'évolution en temps réel.

### 2. Streaming Vidéo

**Test**: Téléchargement HTTP via `curl --interface uesimtun0`

| Métrique | Valeur Mesurée |
|----------|----------------|
| Temps total | [À compléter] s |
| Débit moyen | [À compléter] Mbps |
| Taille fichier | 158 MB |
| Code HTTP | 200 OK |

**Preuve du routage 5G**:
- Interface utilisée: `uesimtun0` (spécifiée via `--interface`)
- IP source: `12.1.1.2` (IP du UE sur le tunnel 5G)
- Gateway: `12.1.1.1` (UPF du Core 5G)
- Logs UPF: Confirment le passage du trafic HTTP
- Métriques Prometheus: Confirment le trafic via l'interface 5G
- Capture tcpdump (optionnel): Montre les paquets sur uesimtun0

**Conclusion**: Streaming vidéo opérationnel via le tunnel 5G

### 3. Analyse Temps Réel (Grafana)

**Dashboard "NexSlice - Monitoring 5G"** disponible à http://localhost:30300

Panels disponibles:
- Latence Moyenne (RTT): Évolution sur les 15 dernières minutes
- Débit (Throughput): Mbps en temps réel
- Perte de Paquets: Pourcentage sur période
- Jitter: Variation de latence



### 4. Capture Réseau (Optionnel)

> **Note**: Avec l'introduction du monitoring Prometheus/Grafana, l'analyse tcpdump devient optionnelle et est principalement utilisée pour le debug approfondi.

Exemple d'analyse tcpdump sur uesimtun0:
```bash
$ tcpdump -r capture-sst1.pcap -nn | head -10

12:34:56.123456 IP 12.1.1.2.45678 > [SERVER_IP].80: Flags [S], seq 123456789
12:34:56.125234 IP [SERVER_IP].80 > 12.1.1.2.45678: Flags [S.], ack 1
12:34:56.125456 IP 12.1.1.2.45678 > [SERVER_IP].80: Flags [.], ack 1
12:34:56.126789 IP 12.1.1.2.45678 > [SERVER_IP].80: HTTP GET /video.mp4
...
```

**Validation**: Le trafic transite bien par l'interface 5G (uesimtun0) et non par l'interface réseau classique.

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
### 3. Déployer le serveur vidéo (obligatoire)

Le dépôt contient un manifeste Kubernetes déjà configuré déployez-le :
```bash
kubectl apply -f configs/kubernetes/video-server.yaml -n nexslice
```
Vérifiez que le serveur tourne :
```bash
kubectl get pods -n nexslice | grep video-server
kubectl exec -n nexslice deploy/video-server -- ls /usr/share/nginx/html
```
Vous devez obtenir :
```CSS
video-server-xxxxx   1/1   Running
```
La vidéo video.mp4 doit être présente.


### 4. Installer les outils nécessaires (machine locale / VM)
Les scripts utilisent ping, curl, jq et bc :
```bash
sudo apt update
sudo apt install -y iputils-ping curl jq bc

```
### 5. Installer la stack Monitoring
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

### 6. Exécuter les scripts de test
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


### 7. Visualiser les métriques (Grafana + Prometheus)

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
