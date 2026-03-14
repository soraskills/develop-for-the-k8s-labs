# Module 0 — Lab : Créer le cluster Kubernetes

## Prérequis

- Docker installé et démarré
- `k3d` installé
- `kubectl` installé

---

## Exercice 1 — Créer le cluster

### 1.1 Lancer la création du cluster

```bash
k3d cluster create lab-cluster --agents 1 -p "8080:80@loadbalancer" --wait
```

La commande va créer :
- 1 nœud server (control plane)
- 1 nœud agent (worker)
- 1 load balancer qui mappe le port 8080 de votre machine vers le port 80 du cluster

### 1.2 Vérifier que le cluster est prêt

```bash
kubectl get nodes
```

Vous devriez voir 2 nœuds en status `Ready` :
- `k3d-lab-cluster-server-0` (control plane)
- `k3d-lab-cluster-agent-0` (worker)

### 1.3 Vérifier le contexte kubectl

```bash
kubectl config current-context
```

Le contexte actif devrait être `k3d-lab-cluster`.

---

## Exercice 2 — Commandes k3d utiles

```bash
# Lister les clusters k3d
k3d cluster list

# Stopper le cluster (sans le supprimer)
k3d cluster stop lab-cluster

# Redémarrer le cluster
k3d cluster start lab-cluster

# Supprimer le cluster
k3d cluster delete lab-cluster
```

---

## Vérification des acquis

À la fin de ce lab, vous devez :

1. Avoir un cluster Kubernetes fonctionnel avec 2 nœuds
2. Pouvoir exécuter `kubectl get nodes` et voir les nœuds en status `Ready`
3. Avoir le port 8080 mappé vers le cluster pour les labs suivants
