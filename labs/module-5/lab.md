# Module 5 — Lab : Ingress avec Traefik

## Prérequis

- Un cluster Kubernetes fonctionnel avec Traefik (k3d par défaut)
- `kubectl` configuré et connecté au cluster
- Le port 8080 mappé vers le port 80 du cluster (cf. Module 0 : `-p "8080:80@loadbalancer"`)

---

## Exercice 1 — Vérifier l'Ingress Controller Traefik

### 1.1 Vérifier que Traefik est déployé

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

**À observer** : un pod Traefik doit être en état `Running`.

### 1.2 Vérifier le Service Traefik

```bash
kubectl get svc -n kube-system -l app.kubernetes.io/name=traefik
```

**À observer** : Traefik expose un Service de type `LoadBalancer` sur les ports 80 (HTTP) et 443 (HTTPS).

### 1.3 Vérifier l'IngressClass

```bash
kubectl get ingressclass
```

**Question** : Quel est le nom de l'IngressClass disponible ? Est-elle marquée comme `default` ?

### 1.4 Inspecter Traefik

```bash
kubectl describe pod -n kube-system -l app.kubernetes.io/name=traefik
```

**À observer** : les ports d'écoute, l'image utilisée et les arguments de configuration.

---

## Exercice 2 — Déployer les applications

### 2.1 Créer un namespace dédié

```bash
kubectl create namespace lab-ingress
```

### 2.2 Déployer une première application (web)

Créez un fichier `app-web.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: lab-ingress
spec:
  replicas: 2
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
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: lab-ingress
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f app-web.yaml
```

### 2.3 Déployer une deuxième application (api)

Créez un fichier `app-api.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-app
  namespace: lab-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: hashicorp/http-echo:0.2.3
          args:
            - "-text=Hello from API"
          ports:
            - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: lab-ingress
spec:
  type: ClusterIP
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 5678
```

```bash
kubectl apply -f app-api.yaml
```

### 2.4 Vérifier les déploiements

```bash
kubectl get pods -n lab-ingress
kubectl get svc -n lab-ingress
```

**Question** : Les deux Deployments sont-ils prêts ? Les Services ont-ils une ClusterIP ?

---

## Exercice 3 — Routage par host

### 3.1 Créer l'Ingress avec routage par host

Créez un fichier `ingress-host.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-routing
  namespace: lab-ingress
spec:
  ingressClassName: traefik
  rules:
    - host: web.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
    - host: api.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

```bash
kubectl apply -f ingress-host.yaml
```

### 3.2 Vérifier l'Ingress

```bash
kubectl get ingress -n lab-ingress
kubectl describe ingress host-routing -n lab-ingress
```

**À observer** : les règles de routage, les hosts configurés et les backends associés.

### 3.3 Tester le routage par host

```bash
# Accéder à l'application web
curl -H "Host: web.localhost" http://localhost:8080

# Accéder à l'API
curl -H "Host: api.localhost" http://localhost:8080
```

> **Note** : On utilise le header `Host` pour simuler la résolution DNS. Avec k3d et le port 8080 mappé vers le port 80 du cluster (cf. Module 0), `localhost:8080` pointe vers le load balancer Traefik.

**Question** : Obtenez-vous la page nginx pour `web.localhost` et le message "Hello from API" pour `api.localhost` ?

### 3.4 Tester avec un host inconnu

```bash
curl -H "Host: unknown.localhost" http://localhost:8080
```

**Question** : Que se passe-t-il quand le host ne correspond à aucune règle ?

---

## Exercice 4 — Routage par path

### 4.1 Créer l'Ingress avec routage par path

Créez un fichier `ingress-path.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
  namespace: lab-ingress
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.localhost
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

```bash
kubectl apply -f ingress-path.yaml
```

### 4.2 Tester le routage par path

```bash
# Le path / doit router vers web-service (nginx)
curl -H "Host: myapp.localhost" http://localhost:8080/

# Le path /api doit router vers api-service
curl -H "Host: myapp.localhost" http://localhost:8080/api
```

**Question** : Le routage fonctionne-t-il correctement ? Le path `/api` renvoie-t-il bien "Hello from API" ?

### 4.3 Tester les sous-chemins

```bash
# /api/users doit aussi matcher la règle /api (pathType: Prefix)
curl -H "Host: myapp.localhost" http://localhost:8080/api/users

# /about doit matcher la règle / (pathType: Prefix)
curl -H "Host: myapp.localhost" http://localhost:8080/about
```

**Question** : Pourquoi `/api/users` est-il routé vers le service API ? Que renvoie `/about` ?

---

## Exercice 5 — Inspecter le fonctionnement

### 5.1 Lister toutes les ressources Ingress

```bash
kubectl get ingress -n lab-ingress -o wide
```

### 5.2 Vérifier les logs de Traefik

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20
```

**À observer** : Traefik log les changements de configuration quand des ressources Ingress sont créées ou modifiées.

### 5.3 Vérifier la chaîne complète

```bash
# Ingress → Service → Endpoints → Pods
kubectl describe ingress host-routing -n lab-ingress
kubectl get endpoints web-service -n lab-ingress
kubectl get endpoints api-service -n lab-ingress
kubectl get pods -n lab-ingress -o wide
```

**Question** : Les endpoints des Services correspondent-ils aux IPs des Pods ?

### 5.4 Tester la mise à jour dynamique

```bash
# Scaler l'application web
kubectl scale deployment web-app -n lab-ingress --replicas=4

# Vérifier que les endpoints sont mis à jour
kubectl get endpoints web-service -n lab-ingress

# Le routage fonctionne toujours
curl -H "Host: web.localhost" http://localhost:8080
```

**À observer** : Traefik détecte automatiquement les nouveaux Pods via les endpoints du Service.

```bash
# Remettre à 2 réplicas
kubectl scale deployment web-app -n lab-ingress --replicas=2
```

---

## Exercice 6 — Nettoyage complet

```bash
kubectl delete namespace lab-ingress
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get all -n lab-ingress
kubectl get ingress -n lab-ingress
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quel est le rôle d'un Ingress Controller dans Kubernetes ?
2. Quelle est la différence entre un Ingress et un NodePort pour exposer un service ?
3. Comment Traefik est-il déployé dans un cluster k3s/k3d ?
4. Comment fonctionne le routage par host dans une ressource Ingress ?
5. Comment fonctionne le routage par path ? Pourquoi l'ordre des paths est-il important ?
6. Quelle est la chaîne complète du trafic : Client → Ingress → Service → Pods ?
7. Que se passe-t-il quand un host de la requête ne correspond à aucune règle Ingress ?
