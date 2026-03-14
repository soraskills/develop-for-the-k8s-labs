# Module 3 — Lab : Namespaces, Quotas, NetworkPolicies, LimitRanges

## Prérequis

- Un cluster Kubernetes fonctionnel (cf. Module 0)
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Créer un Namespace dédié

### 1.1 Créer le namespace

```bash
kubectl create namespace lab-isolation
```

### 1.2 Vérifier la création

```bash
kubectl get namespaces
```

**Question** : Quels namespaces existent maintenant ? Repérez `lab-isolation` dans la liste.

### 1.3 Déployer un pod dans le namespace

Créez un fichier `pod-isolated.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-isolated
  namespace: lab-isolation
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

```bash
kubectl apply -f pod-isolated.yaml
```

### 1.4 Vérifier l'isolation

```bash
# Le pod n'apparaît pas dans le namespace default
kubectl get pods

# Il apparaît dans lab-isolation
kubectl get pods -n lab-isolation
```

**Question** : Pourquoi le pod n'est-il pas visible sans l'option `-n` ?

---

## Exercice 2 — Appliquer un ResourceQuota

### 2.1 Créer le manifest

Créez un fichier `resourcequota.yaml` :

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: lab-quota
  namespace: lab-isolation
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: 256Mi
    limits.cpu: "1"
    limits.memory: 512Mi
    pods: "3"
```

```bash
kubectl apply -f resourcequota.yaml
```

### 2.2 Vérifier le quota

```bash
kubectl describe resourcequota lab-quota -n lab-isolation
```

**À observer** : les colonnes `Used` et `Hard` montrent la consommation actuelle vs la limite.

### 2.3 Supprimer le pod existant (il n'a pas de requests/limits)

Le pod créé à l'exercice 1 n'a pas de requests/limits. Avec un quota actif, les nouveaux pods devront en avoir. Supprimez-le :

```bash
kubectl delete pod nginx-isolated -n lab-isolation
```

### 2.4 Créer des pods avec des requests/limits

Créez un fichier `pod-with-resources.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-1
  namespace: lab-isolation
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 128Mi
```

```bash
kubectl apply -f pod-with-resources.yaml
```

Vérifiez la consommation du quota :

```bash
kubectl describe resourcequota lab-quota -n lab-isolation
```

### 2.5 Tester le dépassement du quota

Créez un fichier `pod-over-quota.yaml` qui demande plus que ce qui reste :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-greedy
  namespace: lab-isolation
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      resources:
        requests:
          cpu: 500m
          memory: 256Mi
        limits:
          cpu: "1"
          memory: 512Mi
```

```bash
kubectl apply -f pod-over-quota.yaml
```

**Question** : Que se passe-t-il ? Quel message d'erreur obtenez-vous ?

### 2.6 Tester la limite du nombre de pods

Créez 2 pods supplémentaires pour atteindre la limite de 3 pods, puis essayez d'en créer un 4ème.

```bash
# Créer le pod 2
kubectl run nginx-2 --image=nginx:1.27 -n lab-isolation \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx:1.27","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"200m","memory":"128Mi"}}}]}}'

# Créer le pod 3
kubectl run nginx-3 --image=nginx:1.27 -n lab-isolation \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx:1.27","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"200m","memory":"128Mi"}}}]}}'

# Tenter de créer le pod 4
kubectl run nginx-4 --image=nginx:1.27 -n lab-isolation \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx:1.27","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"200m","memory":"128Mi"}}}]}}'
```

**Question** : Le 4ème pod a-t-il été créé ? Pourquoi ?

### 2.7 Nettoyage

```bash
kubectl delete pod --all -n lab-isolation
kubectl delete resourcequota lab-quota -n lab-isolation
```

---

## Exercice 3 — Configurer un LimitRange

### 3.1 Créer le manifest

Créez un fichier `limitrange.yaml` :

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: lab-limits
  namespace: lab-isolation
spec:
  limits:
    - type: Container
      default:
        cpu: 200m
        memory: 128Mi
      defaultRequest:
        cpu: 100m
        memory: 64Mi
      min:
        cpu: 50m
        memory: 32Mi
      max:
        cpu: 500m
        memory: 256Mi
```

```bash
kubectl apply -f limitrange.yaml
```

### 3.2 Vérifier le LimitRange

```bash
kubectl describe limitrange lab-limits -n lab-isolation
```

### 3.3 Créer un pod sans spécifier de resources

Créez un fichier `pod-no-resources.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-default-limits
  namespace: lab-isolation
spec:
  containers:
    - name: nginx
      image: nginx:1.27
```

```bash
kubectl apply -f pod-no-resources.yaml
```

### 3.4 Vérifier les valeurs par défaut appliquées

```bash
kubectl describe pod nginx-default-limits -n lab-isolation
```

**À observer** : dans la section `Containers`, les champs `Requests` et `Limits` ont été automatiquement remplis avec les valeurs du LimitRange.

**Question** : Quelles valeurs de CPU et mémoire ont été attribuées au container ?

### 3.5 Tester le dépassement du max

Créez un fichier `pod-over-limits.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-over-limits
  namespace: lab-isolation
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      resources:
        requests:
          cpu: "1"
          memory: 512Mi
```

```bash
kubectl apply -f pod-over-limits.yaml
```

**Question** : Que se passe-t-il ? Quel message d'erreur obtenez-vous ?

### 3.6 Nettoyage

```bash
kubectl delete pod --all -n lab-isolation
kubectl delete limitrange lab-limits -n lab-isolation
```

---

## Exercice 4 — Mettre en place une NetworkPolicy

### 4.1 Déployer deux applications

Créez un fichier `apps.yaml` :

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: lab-isolation
  labels:
    app: backend
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: lab-isolation
  labels:
    app: frontend
spec:
  containers:
    - name: busybox
      image: busybox:1.36
      command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: intruder
  namespace: lab-isolation
  labels:
    app: intruder
spec:
  containers:
    - name: busybox
      image: busybox:1.36
      command: ["sleep", "3600"]
```

```bash
kubectl apply -f apps.yaml
```

### 4.2 Vérifier la communication par défaut

Récupérez l'IP du pod backend :

```bash
kubectl get pod backend -n lab-isolation -o wide
```

Testez la connectivité depuis `frontend` et `intruder` :

```bash
# Depuis frontend
kubectl exec frontend -n lab-isolation -- wget -qO- --timeout=3 http://<IP-BACKEND>

# Depuis intruder
kubectl exec intruder -n lab-isolation -- wget -qO- --timeout=3 http://<IP-BACKEND>
```

**Question** : Les deux pods peuvent-ils accéder au backend ?

### 4.3 Appliquer une NetworkPolicy deny-all

Créez un fichier `netpol-deny-all.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: lab-isolation
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
```

```bash
kubectl apply -f netpol-deny-all.yaml
```

### 4.4 Tester le blocage

```bash
# Depuis frontend — devrait échouer (timeout)
kubectl exec frontend -n lab-isolation -- wget -qO- --timeout=3 http://<IP-BACKEND>

# Depuis intruder — devrait échouer (timeout)
kubectl exec intruder -n lab-isolation -- wget -qO- --timeout=3 http://<IP-BACKEND>
```

**Question** : Le trafic est-il bloqué pour les deux pods ?

> **Note** : Si le trafic n'est pas bloqué, votre CNI ne supporte peut-être pas les NetworkPolicies. Avec k3d, vous pouvez recréer le cluster avec `--k3s-arg "--flannel-backend=none@server:*"` et installer Calico ou Cilium.

### 4.5 Autoriser uniquement le frontend

Créez un fichier `netpol-allow-frontend.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: lab-isolation
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

```bash
kubectl apply -f netpol-allow-frontend.yaml
```

### 4.6 Tester l'accès sélectif

```bash
# Depuis frontend — devrait fonctionner
kubectl exec frontend -n lab-isolation -- wget -qO- --timeout=3 http://<IP-BACKEND>

# Depuis intruder — devrait toujours échouer
kubectl exec intruder -n lab-isolation -- wget -qO- --timeout=3 http://<IP-BACKEND>
```

**Question** : Le frontend peut-il accéder au backend ? Et l'intruder ?

### 4.7 Inspecter les NetworkPolicies

```bash
kubectl get networkpolicy -n lab-isolation
kubectl describe networkpolicy allow-frontend -n lab-isolation
```

---

## Exercice 5 — Nettoyage complet

```bash
kubectl delete namespace lab-isolation
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get all -n lab-isolation
kubectl get networkpolicy -n lab-isolation
kubectl get resourcequota -n lab-isolation
kubectl get limitrange -n lab-isolation
```

**Question** : Que se passe-t-il quand on supprime un namespace ?

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. À quoi sert un Namespace et quelle isolation fournit-il par défaut ?
2. Que se passe-t-il quand un ResourceQuota est atteint ?
3. Pourquoi un pod sans requests/limits est-il refusé quand un ResourceQuota CPU/mémoire est actif ?
4. Comment un LimitRange résout-il ce problème ?
5. Quel est le comportement réseau par défaut entre les pods d'un cluster ?
6. Comment une NetworkPolicy de type deny-all fonctionne-t-elle ?
7. Comment autoriser le trafic uniquement depuis certains pods ?
