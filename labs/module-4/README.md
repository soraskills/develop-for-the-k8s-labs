# Module 4 — Services : ClusterIP et NodePort

## Objectif

Comprendre comment exposer une application à l'intérieur puis à l'extérieur du cluster Kubernetes en utilisant les Services.

## Le concept de Service

Un Service est une abstraction qui définit un point d'accès stable vers un ensemble de Pods. Les Pods étant éphémères (IPs qui changent à chaque recréation), le Service fournit une adresse fixe et un mécanisme de load balancing.

| Propriété | Description |
|---|---|
| Adresse stable | Le Service possède une IP fixe (ClusterIP) qui ne change pas |
| Sélection par labels | Le Service route le trafic vers les Pods correspondant au `selector` |
| Load balancing | Le trafic est réparti entre les Pods sélectionnés |
| Découverte DNS | Chaque Service est accessible via son nom DNS interne |

### Relation Service → Pods

```
┌──────────────────────────────────────────────┐
│                  SERVICE                     │
│  name: my-service                            │
│  selector: app=my-app                        │
│  ClusterIP: 10.43.x.x                        │
│                                              │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │  POD 1  │  │  POD 2  │  │  POD 3  │       │
│  │ app:    │  │ app:    │  │ app:    │       │
│  │ my-app  │  │ my-app  │  │ my-app  │       │
│  └─────────┘  └─────────┘  └─────────┘       │
└──────────────────────────────────────────────┘
```

### Points clés

- Un Service sans `selector` ne route vers aucun Pod (utile pour des endpoints externes)
- Les labels du `selector` doivent correspondre aux labels des Pods cibles
- Un Service découvre dynamiquement les Pods : si un Pod est ajouté ou supprimé, le Service met à jour ses endpoints automatiquement

---

## Sélection des Pods via les labels

Le mécanisme central des Services repose sur les labels. Le champ `selector` du Service définit quels Pods reçoivent le trafic.

```yaml
# Le Service sélectionne les Pods avec le label app: my-app
spec:
  selector:
    app: my-app
```

On peut vérifier les endpoints (Pods sélectionnés) d'un Service :

```bash
kubectl get endpoints <nom-du-service>
```

---

## ClusterIP

Le ClusterIP est le type de Service par défaut. Il attribue une adresse IP interne au cluster, accessible uniquement depuis l'intérieur du cluster.

| Propriété | Description |
|---|---|
| Type par défaut | Si `type` n'est pas spécifié, c'est un ClusterIP |
| IP interne | Accessible uniquement depuis les Pods du cluster |
| DNS interne | Accessible via `<service>.<namespace>.svc.cluster.local` |
| Load balancing | Répartit le trafic entre les Pods sélectionnés |

### Exemple de manifest ClusterIP

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

### Résolution DNS interne

Chaque Service ClusterIP est enregistré dans le DNS interne du cluster (CoreDNS). Les Pods peuvent y accéder via :

| Format DNS | Exemple |
|---|---|
| `<service>` | `my-service` (dans le même namespace) |
| `<service>.<namespace>` | `my-service.default` |
| `<service>.<namespace>.svc.cluster.local` | `my-service.default.svc.cluster.local` (FQDN) |

### Points clés

- Le `port` est le port exposé par le Service (celui qu'on utilise pour y accéder)
- Le `targetPort` est le port sur lequel le container écoute dans le Pod
- `port` et `targetPort` peuvent être différents

---

## NodePort

Le NodePort est une extension du ClusterIP. Il expose le Service sur un port statique de chaque nœud du cluster, rendant l'application accessible depuis l'extérieur.

| Propriété | Description |
|---|---|
| Extension de ClusterIP | Un NodePort crée automatiquement un ClusterIP en dessous |
| Port sur chaque nœud | Le Service est accessible via `<NodeIP>:<NodePort>` |
| Plage de ports | Par défaut entre 30000 et 32767 |
| Attribution | Le `nodePort` peut être spécifié ou attribué automatiquement |

### Exemple de manifest NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service-nodeport
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
```

### Mapping des ports

```
Client externe
    │
    ▼
NodeIP:30080  (nodePort — port sur le nœud)
    │
    ▼
ClusterIP:80  (port — port du Service)
    │
    ▼
Pod:8080      (targetPort — port du container)
```

| Port | Description |
|---|---|
| `nodePort` | Port exposé sur chaque nœud (30000-32767). Accessible depuis l'extérieur |
| `port` | Port du Service à l'intérieur du cluster |
| `targetPort` | Port sur lequel le container écoute |

### Relation NodePort et ClusterIP

Un Service NodePort wrappe un ClusterIP :

```
┌─────────────────────────────────────────────┐
│              NodePort Service                │
│                                              │
│  nodePort: 30080 (accessible de l'extérieur)│
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          ClusterIP (interne)           │  │
│  │  port: 80                              │  │
│  │  → targetPort: 8080 sur les Pods      │  │
│  └────────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Points clés

- Un NodePort est aussi accessible via le ClusterIP interne (il cumule les deux accès)
- En production, on préfère utiliser un Ingress plutôt qu'un NodePort pour exposer des services HTTP
- Le NodePort est utile pour le développement, le debug ou les services non-HTTP

---

## Commandes utiles

```bash
# Services
kubectl get services
kubectl get svc
kubectl describe service <nom>
kubectl get endpoints <nom>

# Créer un Service rapidement via expose
kubectl expose deployment <nom> --type=ClusterIP --port=80 --target-port=8080
kubectl expose deployment <nom> --type=NodePort --port=80 --target-port=8080

# Tester un Service depuis un pod
kubectl run test-client --rm -it --image=busybox:1.36 -- wget -qO- http://<service-name>
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
