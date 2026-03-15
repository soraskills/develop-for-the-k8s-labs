# Module 6 — Horizontal Pod Autoscaler (HPA)

## Objectif

Adapter automatiquement le nombre de pods en fonction de la charge en utilisant le Horizontal Pod Autoscaler.

## Le concept de HPA

Le Horizontal Pod Autoscaler (HPA) est un contrôleur Kubernetes qui ajuste automatiquement le nombre de réplicas d'un Deployment (ou ReplicaSet) en fonction de métriques observées. L'objectif est de maintenir une utilisation cible des ressources.

| Propriété | Description |
|---|---|
| Scaling automatique | Augmente ou diminue le nombre de pods selon la charge |
| Métriques | Basé sur l'utilisation CPU, mémoire ou des métriques custom |
| Boucle de contrôle | Vérifie les métriques toutes les 15 secondes par défaut |
| Bornes | Définit un `minReplicas` et un `maxReplicas` pour encadrer le scaling |

### Fonctionnement général

```
┌──────────────────────────────────────────────────────────┐
│                          HPA                             │
│                                                          │
│  Cible : CPU à 50%                                       │
│  minReplicas: 1    maxReplicas: 10                       │
│                                                          │
│  ┌──────────────┐    métriques    ┌──────────────────┐   │
│  │ metrics-     │ ◄─────────────  │   Pods du        │   │
│  │ server       │                 │   Deployment     │   │
│  └──────┬───────┘                 └──────────────────┘   │
│         │                                  ▲             │
│         ▼                                  │             │
│  ┌──────────────┐    scale         ┌───────┴──────┐      │
│  │     HPA      │ ──────────────►  │  Deployment  │      │
│  │  controller  │                  └──────────────┘      │
│  └──────────────┘                                        │
└──────────────────────────────────────────────────────────┘
```

### Algorithme de scaling

Le HPA calcule le nombre de réplicas souhaité avec la formule :

```
replicas souhaités = ceil( replicas actuels × (métrique actuelle / métrique cible) )
```

Exemple : si la cible CPU est 50%, qu'il y a 2 pods et que l'utilisation moyenne est 80% :

```
replicas = ceil(2 × (80 / 50)) = ceil(3.2) = 4
```

### Points clés

- Le HPA ne crée pas de pods directement : il modifie le champ `replicas` du Deployment
- Le scale down est plus lent que le scale up (stabilisation de 5 minutes par défaut) pour éviter le flapping
- Le HPA nécessite que les containers aient des `requests` définies pour les métriques basées sur CPU/mémoire

---

## Prérequis : metrics-server

Le HPA a besoin d'un composant qui collecte les métriques de ressources des pods : le `metrics-server`.

| Propriété | Description |
|---|---|
| Rôle | Collecte les métriques CPU et mémoire des pods et nœuds |
| API | Expose les métriques via l'API `metrics.k8s.io` |
| k3s / k3d | Inclus par défaut dans k3s |
| Vérification | `kubectl top pods` et `kubectl top nodes` fonctionnent si metrics-server est actif |

### Vérifier que metrics-server est actif

```bash
# Vérifier le déploiement
kubectl get deployment metrics-server -n kube-system

# Tester l'API de métriques
kubectl top nodes
kubectl top pods -A
```

Si `kubectl top` retourne des valeurs, metrics-server fonctionne.

---

## Métriques utilisées

Le HPA peut utiliser plusieurs types de métriques :

| Type | Description | Exemple |
|---|---|---|
| `Resource` | Métriques CPU/mémoire des containers | Utilisation CPU à 50% |
| `Pods` | Métriques custom par pod | Requêtes par seconde |
| `Object` | Métriques d'un objet Kubernetes | Requêtes sur un Ingress |
| `External` | Métriques externes au cluster | Longueur d'une queue SQS |

Dans ce module, on se concentre sur les métriques `Resource` (CPU et mémoire).

### Lien avec requests et limits

Le pourcentage d'utilisation CPU du HPA est calculé par rapport aux `requests`, pas aux `limits` :

```
utilisation CPU (%) = usage CPU actuel / requests CPU × 100
```

Exemple : un container avec `requests.cpu: 200m` qui utilise 160m → utilisation = 80%.

C'est pourquoi les `requests` doivent être définies pour que le HPA fonctionne.

---

## Manifest HPA

### Exemple basique (CPU)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

### Champs importants

| Champ | Description |
|---|---|
| `scaleTargetRef` | Référence vers le Deployment (ou ReplicaSet) à scaler |
| `minReplicas` | Nombre minimum de pods (plancher) |
| `maxReplicas` | Nombre maximum de pods (plafond) |
| `metrics` | Liste des métriques et seuils cibles |
| `averageUtilization` | Pourcentage cible d'utilisation (par rapport aux requests) |

### Exemple avec CPU et mémoire

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
```

Quand plusieurs métriques sont définies, le HPA calcule le nombre de réplicas pour chaque métrique et prend le maximum.

---

## Comportement de scaling

### Scale up

- Déclenché quand la métrique dépasse le seuil cible
- Réaction rapide (par défaut, fenêtre de stabilisation de 0 secondes)
- Le nombre de pods augmente progressivement

### Scale down

- Déclenché quand la métrique descend sous le seuil cible
- Réaction lente (fenêtre de stabilisation de 5 minutes par défaut)
- Évite le flapping (oscillation rapide entre scale up et scale down)

### Personnaliser le comportement

```yaml
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
```

---

## Commandes utiles

```bash
# HPA
kubectl get hpa
kubectl describe hpa <nom>
kubectl get hpa <nom> -w  # watch en temps réel

# Métriques
kubectl top pods
kubectl top nodes
kubectl top pods -n <namespace>

# Créer un HPA rapidement (autoscaling/v1)
kubectl autoscale deployment <nom> --cpu-percent=50 --min=1 --max=10
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
