# Module 2 — Objets de base : Pod, ReplicaSet, Deployment

## Objectif

Comprendre la hiérarchie des objets fondamentaux de Kubernetes et comment ils interagissent pour déployer et gérer des applications.

## La hiérarchie des objets

Dans Kubernetes, les applications sont gérées à travers une hiérarchie d'objets :

```
Deployment
   └── ReplicaSet
          └── Pod
                └── Container(s)
```

Chaque niveau apporte une couche de fonctionnalité supplémentaire.

---

## Le Pod

Le Pod est la plus petite unité déployable dans Kubernetes. Il encapsule un ou plusieurs containers qui partagent le même réseau et le même stockage.

| Propriété | Description |
|---|---|
| Plus petite unité | Un Pod = un ou plusieurs containers qui tournent ensemble |
| Réseau partagé | Tous les containers d'un Pod partagent la même adresse IP |
| Stockage partagé | Les containers peuvent partager des volumes |
| Éphémère | Un Pod n'est pas redémarré automatiquement s'il meurt (sauf si géré par un controller) |

### Exemple de manifest Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: my-app
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

### Points clés

- Un Pod a toujours un `status` : `Pending`, `Running`, `Succeeded`, `Failed`, `Unknown`
- Les `labels` sont essentiels : ils permettent aux autres objets (ReplicaSet, Service) de sélectionner les Pods
- Un Pod seul n'a aucune garantie de disponibilité — s'il est supprimé, personne ne le recrée

---

## Le ReplicaSet

Le ReplicaSet garantit qu'un nombre défini de réplicas d'un Pod tourne à tout moment. Si un Pod meurt, le ReplicaSet en recrée un automatiquement.

| Propriété | Description |
|---|---|
| `replicas` | Nombre de Pods souhaités |
| `selector` | Sélectionne les Pods à gérer via les labels |
| `template` | Modèle de Pod à créer |
| Réconciliation | Boucle continue : si le nombre réel ≠ nombre souhaité, le ReplicaSet corrige |

### Exemple de manifest ReplicaSet

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: my-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

### Points clés

- Le `selector.matchLabels` doit correspondre aux `labels` du template
- En pratique, on ne crée presque jamais un ReplicaSet directement — on utilise un Deployment
- Le ReplicaSet ne gère pas les mises à jour d'image — c'est le rôle du Deployment

---

## Le Deployment

Le Deployment est l'objet le plus utilisé pour déployer des applications. Il gère un ReplicaSet et ajoute des fonctionnalités de mise à jour et de rollback.

| Propriété | Description |
|---|---|
| Gestion déclarative | Vous décrivez l'état souhaité, Kubernetes s'en occupe |
| Rolling update | Mise à jour progressive des Pods sans interruption de service |
| Rollback | Retour à une version précédente en une commande |
| Historique | Conserve l'historique des révisions (ReplicaSets précédents) |

### Exemple de manifest Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

### Stratégies de mise à jour

| Stratégie | Description |
|---|---|
| `RollingUpdate` (défaut) | Remplace les Pods progressivement. Paramètres : `maxSurge` et `maxUnavailable` |
| `Recreate` | Supprime tous les anciens Pods avant de créer les nouveaux (interruption de service) |

### Rolling Update — Fonctionnement

```
Deployment (image: nginx:1.27)
   └── ReplicaSet-v1 (3 pods nginx:1.27)

  kubectl set image deployment/my-deployment nginx=nginx:1.28

Deployment (image: nginx:1.28)
   ├── ReplicaSet-v1 (en cours de scale down)
   └── ReplicaSet-v2 (en cours de scale up avec nginx:1.28)

  ... une fois terminé :

Deployment (image: nginx:1.28)
   ├── ReplicaSet-v1 (0 pods — conservé pour rollback)
   └── ReplicaSet-v2 (3 pods nginx:1.28)
```

### Rollback

```bash
# Voir l'historique des révisions
kubectl rollout history deployment/my-deployment

# Revenir à la révision précédente
kubectl rollout undo deployment/my-deployment

# Revenir à une révision spécifique
kubectl rollout undo deployment/my-deployment --to-revision=1
```

---

## Relations entre les objets

```
┌──────────────────────────────────────────────────┐
│                  DEPLOYMENT                      │
│  - Gère les rolling updates et rollbacks         │
│  - Crée et supervise les ReplicaSets             │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │              REPLICASET                     │ │
│  │  - Maintient le nombre de réplicas          │ │
│  │  - Recrée les Pods si nécessaire            │ │
│  │                                             │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐        │ │
│  │  │  POD 1  │ │  POD 2  │ │  POD 3  │        │ │
│  │  │ nginx   │ │ nginx   │ │ nginx   │        │ │
│  │  └─────────┘ └─────────┘ └─────────┘        │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

---

## Commandes utiles

```bash
# Pods
kubectl get pods
kubectl describe pod <nom>
kubectl delete pod <nom>
kubectl logs <nom>

# ReplicaSets
kubectl get replicasets
kubectl describe replicaset <nom>

# Deployments
kubectl get deployments
kubectl describe deployment <nom>
kubectl rollout status deployment/<nom>
kubectl rollout history deployment/<nom>
kubectl scale deployment/<nom> --replicas=5
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
