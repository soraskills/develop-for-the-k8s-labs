# Module 1 — Lab : Explorer un cluster Kubernetes

## Prérequis

- Un cluster Kubernetes fonctionnel (k3s, minikube, kind, etc.)
- `kubectl` configuré et connecté au cluster
- `k9s` installé

---

## Exercice 1 — Découvrir les nœuds du cluster

### 1.1 Lister les nœuds

```bash
kubectl get nodes
```

**Question** : Combien de nœuds composent votre cluster ? Quel est leur rôle (control-plane, worker) ?

### 1.2 Détails d'un nœud

```bash
kubectl describe node <nom-du-noeud>
```

**À observer** :
- Les labels du nœud (notamment `node-role.kubernetes.io/...`)
- La section `Capacity` (CPU, mémoire)
- La section `Allocatable` (ressources disponibles pour les pods)
- La section `Conditions` (état du nœud : Ready, MemoryPressure, etc.)

### 1.3 Format de sortie étendu

```bash
kubectl get nodes -o wide
```

**À observer** : les adresses IP, la version du container runtime, la version de kubelet.

---

## Exercice 2 — Explorer les namespaces

### 2.1 Lister tous les namespaces

```bash
kubectl get namespaces
```

**Question** : Quels namespaces existent par défaut ? À quoi sert chacun ?

| Namespace | Rôle |
|---|---|
| `default` | Namespace par défaut pour les ressources sans namespace spécifié |
| `kube-system` | Composants système du cluster |
| `kube-public` | Ressources accessibles publiquement |
| `kube-node-lease` | Heartbeats des nœuds pour la détection de pannes |

---

## Exercice 3 — Explorer les pods du namespace `kube-system`

### 3.1 Lister les pods système

```bash
kubectl get pods -n kube-system
```

### 3.2 Obtenir plus de détails

```bash
kubectl get pods -n kube-system -o wide
```

**À observer** : sur quel nœud tourne chaque pod système.

### 3.3 Identifier le rôle de chaque pod

Pour chaque pod listé, utilisez `describe` pour comprendre son rôle :

```bash
kubectl describe pod <nom-du-pod> -n kube-system
```

### 3.4 Vérifier les logs d'un composant

```bash
kubectl logs <nom-du-pod> -n kube-system
```

**Essayez** avec `coredns` et `kube-proxy` pour voir leur activité.

---

## Exercice 4 — Explorer avec k9s

### 4.1 Lancer k9s

```bash
k9s
```

### 4.2 Navigation

1. Tapez `:ns` puis Entrée → vous voyez la liste des namespaces
2. Sélectionnez `kube-system` et appuyez sur Entrée → vous voyez les pods de ce namespace
3. Sélectionnez un pod et appuyez sur `d` → vous voyez le describe du pod
4. Appuyez sur `Esc` pour revenir, puis `l` sur un pod → vous voyez ses logs

### 4.3 Explorer les nœuds

1. Tapez `:nodes` puis Entrée
2. Sélectionnez un nœud et appuyez sur `d` pour voir ses détails

### 4.4 Voir toutes les ressources

1. Appuyez sur `Ctrl+a` pour afficher la liste de toutes les ressources disponibles
2. Naviguez dans les différents types de ressources

---

## Exercice 5 — Commandes utiles à retenir

Testez chacune de ces commandes et observez le résultat :

```bash
# Informations sur le cluster
kubectl cluster-info

# Version du client et du serveur
kubectl version

# Lister toutes les ressources API disponibles
kubectl api-resources

# Lister les pods de tous les namespaces
kubectl get pods --all-namespaces

# Alias courant : -A = --all-namespaces
kubectl get pods -A

# Voir les événements du cluster
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quels sont les composants du Control Plane et quel est le rôle de chacun ?
2. Quel composant stocke l'état du cluster ?
3. Quel composant décide sur quel nœud un pod sera placé ?
4. Comment accéder aux logs d'un pod système ?
5. Quelle est la différence entre `kubectl get` et `kubectl describe` ?
6. Comment naviguer dans les namespaces avec `k9s` ?
