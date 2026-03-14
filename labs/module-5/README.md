# Module 5 — Ingress avec Traefik

## Objectif

Router le trafic HTTP externe vers les services internes du cluster via un Ingress Controller, en utilisant Traefik.

## Le concept d'Ingress

Un Ingress est une ressource Kubernetes qui définit des règles de routage HTTP/HTTPS vers les Services du cluster. Contrairement au NodePort qui expose un port brut, l'Ingress permet un routage intelligent basé sur le nom de domaine (host) ou le chemin (path).

| Propriété | Description |
|---|---|
| Routage HTTP | Route le trafic en fonction du host et/ou du path de la requête |
| Point d'entrée unique | Un seul point d'entrée pour plusieurs services |
| TLS | Supporte la terminaison SSL/TLS |
| Nécessite un controller | L'Ingress ne fonctionne pas seul, il faut un Ingress Controller |

### Pourquoi un Ingress plutôt qu'un NodePort ?

| | NodePort | Ingress |
|---|---|---|
| Protocole | TCP/UDP (tout type de trafic) | HTTP/HTTPS |
| Routage | 1 port = 1 service | 1 point d'entrée = N services |
| Nom de domaine | Non | Oui (routage par host) |
| Chemin URL | Non | Oui (routage par path) |
| TLS | Non (à gérer manuellement) | Oui (terminaison TLS intégrée) |
| Usage | Debug, services non-HTTP | Production, applications web |

---

## L'Ingress Controller

La ressource Ingress seule ne fait rien. Il faut un Ingress Controller, un composant qui tourne dans le cluster et qui implémente les règles définies par les ressources Ingress.

```
Client HTTP
    │
    ▼
┌──────────────────────────────────────────┐
│         INGRESS CONTROLLER               │
│         (Traefik, Nginx, etc.)           │
│                                          │
│  Lit les ressources Ingress              │
│  Configure le reverse proxy              │
│  Route le trafic vers les Services       │
└──────────────────────────────────────────┘
    │                    │
    ▼                    ▼
┌──────────┐      ┌──────────┐
│ Service A │      │ Service B │
│ (app-a)   │      │ (app-b)   │
└──────────┘      └──────────┘
```

### Points clés

- L'Ingress Controller est un reverse proxy déployé dans le cluster
- Il surveille les ressources Ingress et met à jour sa configuration automatiquement
- Plusieurs Ingress Controllers existent : Traefik, Nginx, HAProxy, Contour, etc.
- Un cluster peut avoir plusieurs Ingress Controllers (on utilise `ingressClassName` pour choisir)

---

## Traefik comme Ingress Controller

Traefik est l'Ingress Controller par défaut de k3s/k3d. Il est automatiquement déployé lors de la création du cluster.

| Propriété | Description |
|---|---|
| Déployé par défaut | Installé automatiquement avec k3s/k3d |
| Namespace | Tourne dans `kube-system` |
| IngressClass | `traefik` |
| Dashboard | Interface web de monitoring (désactivée par défaut en production) |
| Auto-discovery | Détecte automatiquement les nouvelles ressources Ingress |

### Vérifier que Traefik est déployé

```bash
# Vérifier le pod Traefik
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Vérifier le service Traefik
kubectl get svc -n kube-system -l app.kubernetes.io/name=traefik

# Vérifier l'IngressClass
kubectl get ingressclass
```

---

## La ressource Ingress

Une ressource Ingress définit les règles de routage. Elle fait le lien entre les requêtes HTTP entrantes et les Services du cluster.

### Chaîne complète : Ingress → Service → Pods

```
Client HTTP
    │
    │  GET http://myapp.local/api
    ▼
┌──────────────────────────────────────────┐
│           INGRESS CONTROLLER             │
│                                          │
│  Règle: myapp.local/api → api-service   │
│  Règle: myapp.local/    → web-service   │
└──────────────────────────────────────────┘
    │                    │
    ▼                    ▼
┌──────────┐      ┌──────────┐
│api-service│      │web-service│
│  port:80  │      │  port:80  │
└──────────┘      └──────────┘
    │                    │
    ▼                    ▼
┌──────────┐      ┌──────────┐
│  Pod API  │      │  Pod Web  │
│  :8080    │      │  :80      │
└──────────┘      └──────────┘
```

### Routage par host

Permet de router vers différents services selon le nom de domaine de la requête.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-routing
spec:
  ingressClassName: traefik
  rules:
    - host: app-a.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-a
                port:
                  number: 80
    - host: app-b.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-b
                port:
                  number: 80
```

### Routage par path

Permet de router vers différents services selon le chemin de la requête.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-routing
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.local
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

### Champs importants

| Champ | Description |
|---|---|
| `ingressClassName` | Spécifie quel Ingress Controller doit gérer cette ressource |
| `rules[].host` | Nom de domaine sur lequel la règle s'applique |
| `rules[].http.paths[].path` | Chemin URL à matcher |
| `pathType` | `Prefix` (match par préfixe) ou `Exact` (match exact) |
| `backend.service.name` | Nom du Service cible |
| `backend.service.port.number` | Port du Service cible |

### pathType : Prefix vs Exact

| pathType | path | Match | Ne match pas |
|---|---|---|---|
| `Prefix` | `/api` | `/api`, `/api/`, `/api/users` | `/app`, `/` |
| `Exact` | `/api` | `/api` | `/api/`, `/api/users` |

### Points clés

- L'ordre des paths compte : les règles les plus spécifiques doivent être en premier
- Si aucun `host` n'est spécifié, la règle s'applique à toutes les requêtes (wildcard)
- Le `ingressClassName` est recommandé pour éviter les ambiguïtés quand plusieurs controllers existent

---

## Commandes utiles

```bash
# Ingress
kubectl get ingress
kubectl get ing
kubectl describe ingress <nom>
kubectl get ingress -n <namespace> -o wide

# Ingress Controller (Traefik)
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# IngressClass
kubectl get ingressclass
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
