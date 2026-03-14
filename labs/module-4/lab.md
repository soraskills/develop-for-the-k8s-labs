# Module 4 — Lab : Services ClusterIP et NodePort

## Prérequis

- Un cluster Kubernetes fonctionnel (cf. Module 0)
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Déployer une application

### 1.1 Créer un namespace dédié

```bash
kubectl create namespace lab-services
```

### 1.2 Créer un Deployment

Créez un fichier `deployment-web.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: lab-services
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

```bash
kubectl apply -f deployment-web.yaml
```

### 1.3 Vérifier le déploiement

```bash
kubectl get pods -n lab-services -l app=web
```

**Question** : Combien de Pods tournent ? Quelles sont leurs IPs ?

```bash
kubectl get pods -n lab-services -l app=web -o wide
```

**À observer** : chaque Pod a une IP différente. Si un Pod est recréé, son IP change.

---

## Exercice 2 — Exposer via un Service ClusterIP

### 2.1 Créer le Service

Créez un fichier `service-clusterip.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: lab-services
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f service-clusterip.yaml
```

### 2.2 Vérifier le Service

```bash
kubectl get svc -n lab-services
```

**À observer** : le Service a reçu une `CLUSTER-IP` fixe. Le champ `EXTERNAL-IP` est `<none>` car c'est un ClusterIP.

### 2.3 Vérifier les endpoints

```bash
kubectl get endpoints web-service -n lab-services
```

**Question** : Combien d'endpoints sont listés ? Correspondent-ils aux IPs des Pods ?

### 2.4 Inspecter le Service

```bash
kubectl describe svc web-service -n lab-services
```

**À observer** : la section `Endpoints` liste les IPs des Pods sélectionnés par le label `app=web`.

---

## Exercice 3 — Tester l'accès interne via DNS

### 3.1 Lancer un pod client

```bash
kubectl run test-client --rm -it --image=busybox:1.36 -n lab-services -- sh
```

### 3.2 Tester l'accès au Service

Depuis le shell du pod `test-client`, testez les différentes formes DNS :

```sh
# Par le nom du service (même namespace)
wget -qO- http://web-service

# Par le nom complet avec namespace
wget -qO- http://web-service.lab-services

# Par le FQDN
wget -qO- http://web-service.lab-services.svc.cluster.local
```

**Question** : Les trois formes fonctionnent-elles ? Quelle est la page affichée ?

### 3.3 Tester le load balancing

Toujours depuis le pod client, exécutez plusieurs requêtes et observez les réponses :

```sh
# Exécuter plusieurs requêtes
for i in 1 2 3 4 5; do wget -qO- http://web-service 2>/dev/null | head -1; done
```

Tapez `exit` pour quitter le pod client.

### 3.4 Tester l'accès depuis un autre namespace

```bash
# Lancer un pod dans le namespace default
kubectl run test-cross-ns --rm -it --image=busybox:1.36 -- sh
```

Depuis ce pod :

```sh
# Le nom court ne fonctionne pas (namespace différent)
wget -qO- --timeout=3 http://web-service

# Il faut utiliser le nom avec le namespace
wget -qO- http://web-service.lab-services
```

**Question** : Pourquoi le nom court `web-service` ne fonctionne-t-il pas depuis un autre namespace ?

Tapez `exit` pour quitter.

---

## Exercice 4 — Observer le lien dynamique Service → Pods

### 4.1 Scaler le Deployment

```bash
# Passer à 5 réplicas
kubectl scale deployment web-app -n lab-services --replicas=5

# Vérifier les endpoints
kubectl get endpoints web-service -n lab-services
```

**Question** : Le nombre d'endpoints a-t-il changé ? Combien y en a-t-il maintenant ?

### 4.2 Réduire les réplicas

```bash
# Redescendre à 2 réplicas
kubectl scale deployment web-app -n lab-services --replicas=2

# Vérifier les endpoints
kubectl get endpoints web-service -n lab-services
```

**À observer** : les endpoints sont mis à jour automatiquement quand des Pods sont ajoutés ou supprimés.

### 4.3 Remettre à 3 réplicas

```bash
kubectl scale deployment web-app -n lab-services --replicas=3
```

---

## Exercice 5 — Passer en NodePort

### 5.1 Modifier le Service

Créez un fichier `service-nodeport.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-nodeport
  namespace: lab-services
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

```bash
kubectl apply -f service-nodeport.yaml
```

### 5.2 Vérifier le Service

```bash
kubectl get svc -n lab-services
```

**À observer** : le Service `web-service-nodeport` a un type `NodePort`, un `CLUSTER-IP` (il wrappe un ClusterIP) et le port affiché est `80:30080/TCP`.

### 5.3 Comparer les deux Services

```bash
kubectl get svc -n lab-services -o wide
```

**Question** : Quelles différences voyez-vous entre le Service ClusterIP et le Service NodePort ?

### 5.4 Accéder depuis l'extérieur du cluster

Récupérez l'IP d'un nœud :

```bash
kubectl get nodes -o wide
```

Testez l'accès via le NodePort :

```bash
# Depuis la machine hôte (en dehors du cluster)
curl http://<NODE-IP>:30080
```

> **Note k3d** : Si vous utilisez k3d, vous devez avoir exposé le port lors de la création du cluster avec `-p "30080:30080@server:0"`. Sinon, recréez le cluster avec ce mapping de port. Avec k3d, vous pouvez accéder via `localhost:30080` si le port est mappé.

**Question** : La page nginx s'affiche-t-elle ? Le Service est-il accessible depuis l'extérieur ?

### 5.5 Vérifier que le NodePort est aussi accessible en interne

```bash
kubectl run test-internal --rm -it --image=busybox:1.36 -n lab-services -- sh
```

Depuis le pod :

```sh
# Accès via le ClusterIP du NodePort Service
wget -qO- http://web-service-nodeport

# Accès via le ClusterIP original
wget -qO- http://web-service
```

**Question** : Les deux Services pointent-ils vers les mêmes Pods ?

Tapez `exit` pour quitter.

---

## Exercice 6 — NodePort avec attribution automatique

### 6.1 Créer un Service sans spécifier le nodePort

Créez un fichier `service-nodeport-auto.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-auto
  namespace: lab-services
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f service-nodeport-auto.yaml
```

### 6.2 Vérifier le port attribué

```bash
kubectl get svc web-service-auto -n lab-services
```

**Question** : Quel `nodePort` a été attribué automatiquement ? Est-il dans la plage 30000-32767 ?

### 6.3 Nettoyage du Service auto

```bash
kubectl delete svc web-service-auto -n lab-services
```

---

## Exercice 7 — Nettoyage complet

```bash
kubectl delete namespace lab-services
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get all -n lab-services
kubectl get svc -n lab-services
```

**Question** : Que se passe-t-il quand on supprime le namespace ?

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quel est le rôle d'un Service dans Kubernetes ?
2. Quelle est la différence entre un ClusterIP et un NodePort ?
3. Comment un Service sélectionne-t-il les Pods vers lesquels router le trafic ?
4. Quelles sont les différentes formes DNS pour accéder à un Service ?
5. Pourquoi le nom court d'un Service ne fonctionne-t-il pas depuis un autre namespace ?
6. Quelle est la relation entre `port`, `targetPort` et `nodePort` ?
7. Que se passe-t-il au niveau des endpoints quand on scale un Deployment ?
