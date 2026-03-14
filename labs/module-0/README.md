# Module 0 — Setup du Cluster Kubernetes

## Objectif

Mettre en place un cluster Kubernetes local avec [k3d](https://k3d.io/) pour pouvoir réaliser les labs suivants.

## Qu'est-ce que k3d ?

k3d est un outil qui permet de créer des clusters [k3s](https://k3s.io/) (distribution légère de Kubernetes) dans des containers Docker. C'est idéal pour le développement local et l'apprentissage.

| Concept | Description |
|---|---|
| `k3s` | Distribution légère de Kubernetes, conçue pour l'IoT et l'edge computing, mais parfaite pour le dev local. |
| `k3d` | Wrapper autour de k3s qui utilise Docker pour créer les nœuds du cluster. |
| `agents` | Nœuds worker dans la terminologie k3s/k3d. |
| `loadbalancer` | k3d crée automatiquement un load balancer pour exposer les ports du cluster. |

## Ce que la commande fait

```bash
k3d cluster create lab-cluster --agents 1 -p "8080:80@loadbalancer" --wait
```

| Option | Rôle |
|---|---|
| `lab-cluster` | Nom du cluster |
| `--agents 1` | Crée 1 nœud worker en plus du nœud server (control plane) |
| `-p "8080:80@loadbalancer"` | Mappe le port 8080 de la machine hôte vers le port 80 du load balancer (utile pour accéder aux services HTTP plus tard) |
| `--wait` | Attend que le cluster soit complètement prêt avant de rendre la main |

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
