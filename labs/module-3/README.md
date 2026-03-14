# Module 3 — Namespaces, Quotas, NetworkPolicies, LimitRanges

## Objectif

Isoler et contrôler les ressources au sein d'un cluster Kubernetes en utilisant les mécanismes de namespaces, quotas, limites et politiques réseau.

## Les Namespaces

Un Namespace est une isolation logique des ressources dans un cluster. Il permet de séparer les environnements (dev, staging, prod) ou les équipes au sein d'un même cluster.

| Propriété | Description |
|---|---|
| Isolation logique | Les ressources d'un namespace ne sont pas visibles depuis un autre (sauf exceptions) |
| Scope | Certaines ressources sont namespacées (Pods, Services), d'autres sont globales (Nodes, PersistentVolumes) |
| Défaut | Sans namespace spécifié, les ressources sont créées dans `default` |
| DNS | Les services sont accessibles via `<service>.<namespace>.svc.cluster.local` |

### Exemple de manifest Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
```

### Points clés

- Les namespaces ne fournissent pas d'isolation réseau par défaut — il faut des NetworkPolicies pour ça
- On peut définir des quotas et des limites par namespace pour contrôler la consommation
- Supprimer un namespace supprime toutes les ressources qu'il contient

---

## ResourceQuota

Un ResourceQuota limite la consommation globale de ressources dans un namespace. Il agit comme un plafond : une fois la limite atteinte, toute nouvelle demande est refusée.

| Propriété | Description |
|---|---|
| CPU / Mémoire | Limite la somme totale des requests et limits de tous les pods du namespace |
| Nombre d'objets | Limite le nombre de pods, services, configmaps, etc. |
| Enforcement | Les créations qui dépassent le quota sont rejetées par l'API server |

### Exemple de manifest ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-quota
  namespace: my-namespace
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "10"
```

### Points clés

- Quand un ResourceQuota CPU/mémoire est actif, chaque pod doit obligatoirement spécifier ses requests et limits (sinon la création est refusée)
- On peut combiner un ResourceQuota avec un LimitRange pour définir des valeurs par défaut
- `kubectl describe resourcequota` permet de voir la consommation actuelle vs la limite

---

## LimitRange

Un LimitRange définit des contraintes par défaut et des bornes min/max pour les containers d'un namespace. Contrairement au ResourceQuota qui agit au niveau global, le LimitRange agit au niveau de chaque container ou pod.

| Propriété | Description |
|---|---|
| `default` | Valeurs de limits appliquées automatiquement si non spécifiées par le container |
| `defaultRequest` | Valeurs de requests appliquées automatiquement si non spécifiées |
| `min` / `max` | Bornes minimales et maximales autorisées pour un container |
| Type | Peut s'appliquer aux `Container`, `Pod` ou `PersistentVolumeClaim` |

### Exemple de manifest LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: my-limits
  namespace: my-namespace
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 256Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      min:
        cpu: 50m
        memory: 64Mi
      max:
        cpu: "1"
        memory: 512Mi
```

### Points clés

- Le LimitRange est particulièrement utile en combinaison avec un ResourceQuota : il fournit les valeurs par défaut que le quota exige
- Si un container demande plus que le `max` ou moins que le `min`, la création est refusée
- Les valeurs `default` et `defaultRequest` ne s'appliquent qu'aux containers qui ne spécifient pas leurs propres valeurs

---

## NetworkPolicy

Une NetworkPolicy contrôle le trafic réseau entre les pods. Par défaut, tous les pods d'un cluster peuvent communiquer entre eux. Les NetworkPolicies permettent de restreindre ce trafic.

| Propriété | Description |
|---|---|
| `podSelector` | Sélectionne les pods auxquels la policy s'applique |
| `ingress` | Règles pour le trafic entrant |
| `egress` | Règles pour le trafic sortant |
| `policyTypes` | Types de trafic contrôlés : `Ingress`, `Egress`, ou les deux |

### Comportement par défaut

- Sans NetworkPolicy : tout le trafic est autorisé
- Dès qu'une NetworkPolicy sélectionne un pod, tout le trafic non explicitement autorisé est bloqué (pour les types déclarés dans `policyTypes`)

### Exemple : deny all ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: my-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### Exemple : autoriser le trafic depuis certains pods

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: my-namespace
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 80
```

### Points clés

- Les NetworkPolicies nécessitent un CNI (Container Network Interface) qui les supporte (Calico, Cilium, Weave). k3s utilise Flannel par défaut qui ne supporte pas les NetworkPolicies — il faut utiliser le flag `--flannel-backend=none` et installer un CNI compatible, ou utiliser le network policy controller intégré de k3s
- Les règles sont additives : on ne peut pas créer de règle "deny" explicite, on bloque en ne créant pas de règle "allow"
- Le `podSelector: {}` vide sélectionne tous les pods du namespace

---

## Commandes utiles

```bash
# Namespaces
kubectl get namespaces
kubectl create namespace <nom>
kubectl delete namespace <nom>

# ResourceQuota
kubectl get resourcequota -n <namespace>
kubectl describe resourcequota <nom> -n <namespace>

# LimitRange
kubectl get limitrange -n <namespace>
kubectl describe limitrange <nom> -n <namespace>

# NetworkPolicy
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <nom> -n <namespace>
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
