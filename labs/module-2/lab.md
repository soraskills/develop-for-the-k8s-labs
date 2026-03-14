# Module 2 — Lab : Pod, ReplicaSet, Deployment

## Prérequis

- Un cluster Kubernetes fonctionnel (cf. Module 0)
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Créer un Pod simple

### 1.1 Créer le manifest

Créez un fichier `pod.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

### 1.2 Appliquer le manifest

```bash
kubectl apply -f pod.yaml
```

### 1.3 Vérifier le Pod

```bash
kubectl get pods
```

**Question** : Quel est le status du Pod ? Combien de containers sont `RUNNING` ?

### 1.4 Inspecter le Pod

```bash
kubectl describe pod nginx-pod
```

**À observer** :
- La section `Events` : les étapes de création (Scheduled, Pulling, Created, Started)
- La section `Containers` : l'image utilisée, le port exposé
- Les `Labels` du Pod

### 1.5 Tester l'éphémérité du Pod

```bash
# Supprimer le Pod
kubectl delete pod nginx-pod

# Vérifier qu'il n'est pas recréé
kubectl get pods
```

**Question** : Le Pod a-t-il été recréé automatiquement ? Pourquoi ?

---

## Exercice 2 — Créer un ReplicaSet

### 2.1 Créer le manifest

Créez un fichier `replicaset.yaml` :

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-rs
  template:
    metadata:
      labels:
        app: nginx-rs
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

### 2.2 Appliquer et observer

```bash
kubectl apply -f replicaset.yaml
kubectl get replicasets
kubectl get pods -l app=nginx-rs
```

**Question** : Combien de Pods ont été créés ? Quel est leur nom ?

### 2.3 Tester le maintien des réplicas

Supprimez un Pod et observez ce qui se passe :

```bash
# Notez le nom d'un des pods
kubectl get pods -l app=nginx-rs

# Supprimez-le
kubectl delete pod <nom-du-pod>

# Observez immédiatement
kubectl get pods -l app=nginx-rs
```

**Question** : Que s'est-il passé ? Combien de Pods tournent maintenant ?

### 2.4 Scaler le ReplicaSet

```bash
# Passer à 5 réplicas
kubectl scale replicaset nginx-replicaset --replicas=5
kubectl get pods -l app=nginx-rs

# Redescendre à 2 réplicas
kubectl scale replicaset nginx-replicaset --replicas=2
kubectl get pods -l app=nginx-rs
```

**À observer** : les Pods en excès sont terminés progressivement.

### 2.5 Nettoyage

```bash
kubectl delete replicaset nginx-replicaset
```

---

## Exercice 3 — Créer un Deployment

### 3.1 Créer le manifest

Créez un fichier `deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-deploy
  template:
    metadata:
      labels:
        app: nginx-deploy
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

### 3.2 Appliquer et observer la hiérarchie

```bash
kubectl apply -f deployment.yaml

# Observer le Deployment
kubectl get deployments

# Observer le ReplicaSet créé automatiquement
kubectl get replicasets

# Observer les Pods
kubectl get pods -l app=nginx-deploy
```

**Question** : Quel est le nom du ReplicaSet créé ? Comment est-il lié au Deployment ?

### 3.3 Inspecter les relations

```bash
# Voir les détails du Deployment
kubectl describe deployment nginx-deployment

# Voir le ReplicaSet et son owner
kubectl describe replicaset -l app=nginx-deploy
```

**À observer** : le champ `Controlled By` dans le describe du ReplicaSet et des Pods.

---

## Exercice 4 — Rolling Update

### 4.1 Effectuer une mise à jour d'image

```bash
# Mettre à jour l'image de nginx:1.27 vers nginx:1.28
kubectl set image deployment/nginx-deployment nginx=nginx:1.28

# Suivre le déploiement en temps réel
kubectl rollout status deployment/nginx-deployment
```

### 4.2 Observer le rolling update

```bash
# Voir les ReplicaSets (ancien et nouveau)
kubectl get replicasets -l app=nginx-deploy

# Vérifier l'image utilisée par les Pods
kubectl describe pods -l app=nginx-deploy | grep Image:
```

**Question** : Combien de ReplicaSets existent maintenant ? Combien de Pods dans chacun ?

### 4.3 Consulter l'historique

```bash
kubectl rollout history deployment/nginx-deployment
```

---

## Exercice 5 — Rollback

### 5.1 Simuler un déploiement problématique

```bash
# Déployer une image qui n'existe pas
kubectl set image deployment/nginx-deployment nginx=nginx:9.9.9

# Observer le status
kubectl rollout status deployment/nginx-deployment --timeout=30s

# Voir les Pods en erreur
kubectl get pods -l app=nginx-deploy
```

**Question** : Quel est le status des nouveaux Pods ? Que signifie `ImagePullBackOff` / `ErrImagePull` ?

### 5.2 Effectuer un rollback

```bash
# Revenir à la version précédente
kubectl rollout undo deployment/nginx-deployment

# Vérifier que tout est revenu à la normale
kubectl rollout status deployment/nginx-deployment
kubectl get pods -l app=nginx-deploy
```

### 5.3 Vérifier l'historique après rollback

```bash
kubectl rollout history deployment/nginx-deployment
```

**Question** : Que remarquez-vous dans l'historique des révisions ?

---

## Exercice 6 — Nettoyage

```bash
kubectl delete deployment nginx-deployment
```

Vérifiez que le ReplicaSet et les Pods associés sont aussi supprimés :

```bash
kubectl get replicasets
kubectl get pods -l app=nginx-deploy
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quelle est la différence entre un Pod seul et un Pod géré par un ReplicaSet ?
2. Pourquoi utilise-t-on un Deployment plutôt qu'un ReplicaSet directement ?
3. Que se passe-t-il quand on supprime un Pod géré par un ReplicaSet ?
4. Comment fonctionne un rolling update ?
5. Comment revenir à une version précédente d'un Deployment ?
6. Quelle est la relation entre Deployment, ReplicaSet et Pod ?
