# Module 6 — Lab : Horizontal Pod Autoscaler (HPA)

## Prérequis

- Un cluster Kubernetes fonctionnel (cf. Module 0)
- `kubectl` configuré et connecté au cluster
- `metrics-server` actif (inclus par défaut dans k3s/k3d)

---

## Exercice 1 — Vérifier metrics-server

### 1.1 Vérifier le déploiement

```bash
kubectl get deployment metrics-server -n kube-system
```

**Question** : Le déploiement `metrics-server` est-il présent et prêt ?

### 1.2 Tester les métriques

```bash
kubectl top nodes
```

```bash
kubectl top pods -A
```

**À observer** : si ces commandes retournent des valeurs de CPU et mémoire, metrics-server fonctionne correctement.

> **Note** : si `kubectl top` retourne une erreur, metrics-server n'est peut-être pas encore prêt. Attendez quelques minutes après le démarrage du cluster et réessayez.

---

## Exercice 2 — Déployer une application avec des resource requests

### 2.1 Créer un namespace dédié

```bash
kubectl create namespace lab-hpa
```

### 2.2 Créer un Deployment avec des requests CPU

Créez un fichier `deployment-hpa.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
  namespace: lab-hpa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
        - name: php-apache
          image: registry.k8s.io/hpa-example
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 200m
            limits:
              cpu: 500m
```

```bash
kubectl apply -f deployment-hpa.yaml
```

> **Note** : l'image `registry.k8s.io/hpa-example` est une application PHP qui effectue des calculs CPU intensifs à chaque requête. C'est l'image officielle utilisée dans la documentation Kubernetes pour tester le HPA.

### 2.3 Exposer l'application via un Service

Créez un fichier `service-hpa.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  namespace: lab-hpa
spec:
  selector:
    app: php-apache
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f service-hpa.yaml
```

### 2.4 Vérifier le déploiement

```bash
kubectl get pods -n lab-hpa
kubectl get svc -n lab-hpa
```

**Question** : Combien de pods tournent ? Le Service est-il créé ?

### 2.5 Vérifier les métriques du pod

```bash
kubectl top pods -n lab-hpa
```

**À observer** : le pod consomme très peu de CPU au repos.

---

## Exercice 3 — Créer un HPA basé sur l'utilisation CPU

### 3.1 Créer le HPA via un manifest

Créez un fichier `hpa.yaml` :

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
  namespace: lab-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
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

```bash
kubectl apply -f hpa.yaml
```

### 3.2 Vérifier le HPA

```bash
kubectl get hpa -n lab-hpa
```

**À observer** : la colonne `TARGETS` affiche l'utilisation actuelle vs la cible (ex: `0%/50%`). Si elle affiche `<unknown>/50%`, attendez quelques secondes que metrics-server collecte les données.

### 3.3 Inspecter le HPA

```bash
kubectl describe hpa php-apache-hpa -n lab-hpa
```

**Question** : Quelles informations voyez-vous dans les sections `Metrics` et `Conditions` ?

---

## Exercice 4 — Générer de la charge et observer le scaling

### 4.1 Ouvrir un terminal de monitoring

Dans un premier terminal, lancez un watch sur le HPA :

```bash
kubectl get hpa -n lab-hpa -w
```

Dans un second terminal, lancez un watch sur les pods :

```bash
kubectl get pods -n lab-hpa -w
```

### 4.2 Générer de la charge

Dans un troisième terminal, lancez un pod qui envoie des requêtes en boucle :

```bash
kubectl run load-generator --rm -it --image=busybox:1.36 -n lab-hpa -- sh -c "while true; do wget -q -O- http://php-apache; done"
```

> **Note** : ce pod envoie des requêtes HTTP en continu au Service `php-apache`, ce qui fait monter l'utilisation CPU.

### 4.3 Observer le scale up

Revenez aux terminaux de monitoring et observez :

**Dans le terminal HPA** :
- La colonne `TARGETS` monte progressivement (ex: `120%/50%`, `250%/50%`)
- La colonne `REPLICAS` augmente

**Dans le terminal Pods** :
- De nouveaux pods apparaissent au fur et à mesure

**Question** : Combien de temps faut-il avant que le premier scale up se déclenche ? Combien de pods sont créés ?

### 4.4 Vérifier les métriques pendant la charge

```bash
kubectl top pods -n lab-hpa
```

**À observer** : chaque pod consomme du CPU. La charge est répartie entre les réplicas.

### 4.5 Inspecter les événements du HPA

```bash
kubectl describe hpa php-apache-hpa -n lab-hpa
```

**À observer** : la section `Events` montre les décisions de scaling prises par le HPA avec les raisons.

---

## Exercice 5 — Observer le scale down

### 5.1 Arrêter la charge

Dans le terminal du load-generator, appuyez sur `Ctrl+C` puis tapez `exit` pour arrêter le pod de charge.

### 5.2 Observer le scale down

Revenez aux terminaux de monitoring et observez :

**Dans le terminal HPA** :
- La colonne `TARGETS` descend progressivement
- Après quelques minutes, la colonne `REPLICAS` diminue

**Dans le terminal Pods** :
- Les pods sont terminés progressivement

**Question** : Combien de temps faut-il avant que le scale down commence ? Pourquoi est-ce plus lent que le scale up ?

### 5.3 Vérifier l'état final

Attendez que le scaling se stabilise (environ 5 minutes) :

```bash
kubectl get hpa -n lab-hpa
kubectl get pods -n lab-hpa
```

**Question** : Combien de pods restent après le scale down ? Correspond-il au `minReplicas` ?

---

## Exercice 6 — Créer un HPA via la ligne de commande

### 6.1 Supprimer le HPA existant

```bash
kubectl delete hpa php-apache-hpa -n lab-hpa
```

### 6.2 Créer un HPA avec kubectl autoscale

```bash
kubectl autoscale deployment php-apache -n lab-hpa --cpu-percent=50 --min=1 --max=5
```

### 6.3 Vérifier le HPA créé

```bash
kubectl get hpa -n lab-hpa
kubectl describe hpa php-apache -n lab-hpa
```

**Question** : Quelles différences voyez-vous par rapport au HPA créé via manifest ? Quelle version de l'API est utilisée ?

> **Note** : `kubectl autoscale` crée un HPA en `autoscaling/v1` qui ne supporte que la métrique CPU. Pour utiliser plusieurs métriques ou personnaliser le comportement, il faut passer par un manifest `autoscaling/v2`.

---

## Exercice 7 — Nettoyage complet

```bash
kubectl delete namespace lab-hpa
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get all -n lab-hpa
kubectl get hpa -n lab-hpa
```

**Question** : Que se passe-t-il quand on supprime le namespace ?

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quel est le rôle du Horizontal Pod Autoscaler ?
2. Pourquoi les `requests` CPU doivent-elles être définies pour que le HPA fonctionne ?
3. Comment le HPA calcule-t-il le nombre de réplicas souhaité ?
4. Quel composant fournit les métriques au HPA ?
5. Pourquoi le scale down est-il plus lent que le scale up ?
6. Quelle est la différence entre `autoscaling/v1` et `autoscaling/v2` ?
7. Que se passe-t-il si la charge dépasse la capacité de `maxReplicas` pods ?
