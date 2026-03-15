# Module 8 — Volumes, PersistentVolume, PersistentVolumeClaim

## Objectif

Persister les données au-delà du cycle de vie d'un pod en utilisant les Volumes, PersistentVolumes et PersistentVolumeClaims.

## Le problème : données éphémères

Par défaut, le système de fichiers d'un container est éphémère. Quand un container redémarre ou qu'un Pod est supprimé, toutes les données écrites dans le container sont perdues.

| Situation | Conséquence |
|---|---|
| Container qui crash et redémarre | Données perdues |
| Pod supprimé et recréé par un Deployment | Données perdues |
| Rolling update d'un Deployment | Données perdues (nouveaux Pods) |

C'est problématique pour les applications qui ont besoin de persister des données : bases de données, fichiers uploadés, logs, caches, etc.

---

## Volume : stockage attaché à un Pod

Un Volume est un répertoire accessible aux containers d'un Pod. Il a la même durée de vie que le Pod : les données survivent aux redémarrages de containers mais sont perdues si le Pod est supprimé.

| Propriété | Description |
|---|---|
| Durée de vie | Liée au Pod (pas au container) |
| Partage | Peut être partagé entre les containers d'un même Pod |
| Types | `emptyDir`, `hostPath`, `configMap`, `secret`, `persistentVolumeClaim`, etc. |

### emptyDir

Le type le plus simple. Un répertoire vide est créé quand le Pod est assigné à un nœud et supprimé quand le Pod est supprimé.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-emptydir
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo hello > /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "sleep 5 && cat /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
  volumes:
    - name: shared-data
      emptyDir: {}
```

### hostPath

Monte un fichier ou répertoire du nœud hôte dans le Pod. Utile pour le développement mais déconseillé en production (lie le Pod à un nœud spécifique).

```yaml
volumes:
  - name: host-data
    hostPath:
      path: /tmp/data
      type: DirectoryOrCreate
```

### Points clés

- `volumes` définit les volumes disponibles au niveau du Pod
- `volumeMounts` monte un volume dans un container à un chemin donné
- Un même volume peut être monté dans plusieurs containers du même Pod

---

## PersistentVolume (PV)

Un PersistentVolume est une ressource de stockage provisionnée dans le cluster, indépendante du cycle de vie des Pods. C'est une ressource cluster-level (pas namespacée).

| Propriété | Description |
|---|---|
| Scope | Ressource cluster (pas de namespace) |
| Durée de vie | Indépendante des Pods |
| Provisionnement | Manuel (admin) ou dynamique (StorageClass) |
| Capacité | Définie à la création (`storage`) |

### Exemple de PersistentVolume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/my-pv-data
```

### Champs importants

| Champ | Description |
|---|---|
| `capacity.storage` | Taille du volume |
| `accessModes` | Modes d'accès autorisés |
| `persistentVolumeReclaimPolicy` | Que faire du PV quand le PVC est supprimé (`Retain`, `Delete`, `Recycle`) |
| `hostPath` / `nfs` / `csi` | Backend de stockage utilisé |

### Cycle de vie d'un PV

```
Available ──► Bound ──► Released ──► Available (ou supprimé)
    │                       │
    │   PVC créé et matché  │   PVC supprimé
    │                       │
    └───────────────────────┘
```

| État | Description |
|---|---|
| `Available` | PV libre, prêt à être lié à un PVC |
| `Bound` | PV lié à un PVC |
| `Released` | PVC supprimé, PV en attente de récupération |
| `Failed` | Erreur lors de la récupération automatique |

---

## PersistentVolumeClaim (PVC)

Un PersistentVolumeClaim est une demande de stockage faite par un utilisateur. Le PVC est une ressource namespacée qui se lie à un PV correspondant.

| Propriété | Description |
|---|---|
| Scope | Ressource namespacée |
| Rôle | Demande de stockage (taille, access mode) |
| Binding | Kubernetes lie automatiquement le PVC à un PV compatible |
| Utilisation | Référencé dans le Pod via `persistentVolumeClaim` |

### Exemple de PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Binding PV ↔ PVC

Kubernetes lie automatiquement un PVC à un PV compatible selon :

1. La capacité demandée (le PV doit avoir au moins la taille demandée)
2. Les access modes (doivent correspondre)
3. La StorageClass (doit correspondre, ou être vide pour le provisionnement statique)

```
┌──────────────────────────────────────────────────────────┐
│                     CLUSTER                              │
│                                                          │
│  ┌──────────────┐    binding     ┌──────────────────┐   │
│  │     PVC      │ ◄────────────► │       PV         │   │
│  │  my-pvc      │                │  my-pv           │   │
│  │  1Gi, RWO    │                │  1Gi, RWO        │   │
│  └──────┬───────┘                │  hostPath:       │   │
│         │                        │  /tmp/my-pv-data │   │
│         │ référencé par          └──────────────────┘   │
│         ▼                                               │
│  ┌──────────────┐                                       │
│  │     Pod      │                                       │
│  │  volume:     │                                       │
│  │   my-pvc     │                                       │
│  └──────────────┘                                       │
└──────────────────────────────────────────────────────────┘
```

### Utilisation dans un Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-pvc
spec:
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-pvc
```

---

## StorageClass et provisionnement dynamique

La StorageClass permet le provisionnement dynamique de PV. Au lieu de créer manuellement un PV, on définit une StorageClass et Kubernetes crée automatiquement le PV quand un PVC le demande.

| Propriété | Description |
|---|---|
| Provisionnement dynamique | Le PV est créé automatiquement à la demande |
| Provisioner | Plugin qui crée le stockage (ex: `rancher.io/local-path` pour k3s) |
| Paramètres | Configuration spécifique au provisioner |
| Reclaim policy | Politique de récupération par défaut pour les PV créés |

### StorageClass par défaut dans k3s/k3d

k3s inclut une StorageClass par défaut appelée `local-path` :

```bash
kubectl get storageclass
```

```
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```

### Provisionnement dynamique avec StorageClass

Quand un PVC spécifie une `storageClassName` (ou utilise la classe par défaut), Kubernetes crée automatiquement un PV :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  # storageClassName: local-path  # optionnel si c'est la classe par défaut
```

```
PVC créé ──► StorageClass détectée ──► PV créé automatiquement ──► Binding PVC ↔ PV
```

### Points clés

- Si aucune `storageClassName` n'est spécifiée dans le PVC, la StorageClass par défaut est utilisée
- Le provisionnement dynamique évite de devoir créer manuellement les PV
- En k3s/k3d, `local-path` stocke les données sur le nœud local (pas de réplication)

---

## Access Modes

Les access modes définissent comment un volume peut être monté par les nœuds.

| Mode | Abréviation | Description |
|---|---|---|
| `ReadWriteOnce` | RWO | Lecture/écriture par un seul nœud |
| `ReadOnlyMany` | ROX | Lecture seule par plusieurs nœuds |
| `ReadWriteMany` | RWX | Lecture/écriture par plusieurs nœuds |

### Points clés

- RWO est le mode le plus courant et supporté par la plupart des backends
- RWX nécessite un backend de stockage qui le supporte (NFS, CephFS, etc.)
- `local-path` de k3s ne supporte que RWO
- L'access mode est une contrainte au niveau du nœud, pas du Pod

---

## Reclaim Policy

La reclaim policy définit ce qui arrive au PV quand le PVC associé est supprimé.

| Policy | Description |
|---|---|
| `Retain` | Le PV est conservé avec ses données (nécessite un nettoyage manuel) |
| `Delete` | Le PV et les données sont supprimés automatiquement |
| `Recycle` | Déprécié. Les données sont effacées (`rm -rf /volume/*`) et le PV redevient disponible |

### Points clés

- `Delete` est la policy par défaut pour le provisionnement dynamique
- `Retain` est recommandé pour les données critiques (bases de données)
- Avec `Retain`, le PV passe en état `Released` et doit être nettoyé manuellement avant réutilisation

---

## Commandes utiles

```bash
# PersistentVolume
kubectl get pv
kubectl describe pv <nom>

# PersistentVolumeClaim
kubectl get pvc
kubectl get pvc -n <namespace>
kubectl describe pvc <nom> -n <namespace>

# StorageClass
kubectl get storageclass
kubectl get sc
kubectl describe sc <nom>

# Vérifier le binding
kubectl get pv,pvc -n <namespace>

# Supprimer un PVC (attention : peut supprimer le PV selon la reclaim policy)
kubectl delete pvc <nom> -n <namespace>
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
