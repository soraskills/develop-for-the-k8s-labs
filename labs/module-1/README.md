# Module 1 — Composants d'un Cluster Kubernetes

## Objectif

Comprendre l'architecture d'un cluster Kubernetes et le rôle de chaque composant.

## Architecture d'un cluster Kubernetes

Un cluster Kubernetes est composé de deux types de nœuds :

### Control Plane (Master)

Le Control Plane est le cerveau du cluster. Il prend toutes les décisions globales (scheduling, détection d'événements, etc.).

| Composant | Rôle |
|---|---|
| `etcd` | Base de données clé/valeur distribuée. Stocke l'état complet du cluster. |
| `kube-apiserver` | Point d'entrée unique pour toutes les interactions avec le cluster (kubectl, UI, API). |
| `kube-scheduler` | Décide sur quel nœud placer un nouveau pod en fonction des ressources disponibles et des contraintes. |
| `kube-controller-manager` | Exécute les boucles de réconciliation (ex : s'assurer que le nombre de réplicas est respecté). |

### Worker Nodes

Les Worker Nodes exécutent les applications conteneurisées.

| Composant | Rôle |
|---|---|
| `kubelet` | Agent sur chaque nœud, s'assure que les containers tournent dans les pods. |
| `kube-proxy` | Gère les règles réseau sur chaque nœud pour le routage du trafic vers les pods. |
| `container runtime` | Moteur d'exécution des containers (containerd, CRI-O). |

### Services additionnels

| Composant | Rôle |
|---|---|
| `coredns` | Résolution DNS interne du cluster. Permet aux pods de se trouver par nom de service. |

## Schéma simplifié

```
┌─────────────────────────────────────────────────────┐
│                   CONTROL PLANE                      │
│                                                      │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   etcd   │  │ kube-apiserver│  │kube-scheduler│  │
│  └──────────┘  └──────────────┘  └──────────────┘  │
│                ┌──────────────────────┐              │
│                │kube-controller-manager│              │
│                └──────────────────────┘              │
└─────────────────────────────────────────────────────┘
                         │ API
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Worker Node │ │  Worker Node │ │  Worker Node │
│              │ │              │ │              │
│  kubelet     │ │  kubelet     │ │  kubelet     │
│  kube-proxy  │ │  kube-proxy  │ │  kube-proxy  │
│  [pods...]   │ │  [pods...]   │ │  [pods...]   │
└──────────────┘ └──────────────┘ └──────────────┘
```

## Outils

### kubectl

CLI officielle pour interagir avec le cluster Kubernetes via l'API server.

```bash
# Syntaxe générale
kubectl <verbe> <type-de-ressource> [nom] [options]

# Exemples
kubectl get nodes                  # Lister les nœuds
kubectl get pods -n kube-system    # Lister les pods système
kubectl describe pod <nom-du-pod>  # Détails d'un pod
```

### k9s

Interface terminal interactive pour naviguer dans le cluster. Permet de visualiser, filtrer et interagir avec les ressources Kubernetes sans taper de commandes.

```bash
# Lancer k9s
k9s

# Raccourcis utiles dans k9s
# :ns        → naviguer vers les namespaces
# :pods      → lister les pods
# :nodes     → lister les nœuds
# /          → filtrer
# d          → describe
# l          → logs
# Ctrl+a     → afficher toutes les ressources disponibles
# Esc        → retour
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
