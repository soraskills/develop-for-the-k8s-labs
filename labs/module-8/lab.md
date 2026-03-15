# Module 8 — Lab : Volumes, PersistentVolume, PersistentVolumeClaim

## Prérequis

- Un cluster Kubernetes fonctionnel (cf. Module 0)
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Comprendre le problème des données éphémères

### 1.1 Créer un namespace dédié

```bash
kubectl create namespace lab-volumes
```

### 1.2 Créer un Pod sans volume

Créez un fichier `pod-ephemeral.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-ephemeral
  namespace: lab-volumes
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f pod-ephemeral.yaml
```

### 1.3 Écrire des données dans le container

```bash
kubectl exec -n lab-volumes pod-ephemeral -- sh -c "mkdir -p /data && echo 'données importantes' > /data/message.txt"
```

### 1.4 Vérifier que les données existent

```bash
kubectl exec -n lab-volumes pod-ephemeral -- cat /data/message.txt
```

**À observer** : le fichier contient bien "données importantes".

### 1.5 Supprimer et recréer le Pod

```bash
kubectl delete pod pod-ephemeral -n lab-volumes
kubectl apply -f pod-ephemeral.yaml
```

### 1.6 Vérifier les données après recréation

```bash
kubectl exec -n lab-volumes pod-ephemeral -- cat /data/message.txt
```

**Question** : Le fichier existe-t-il encore ? Pourquoi ?

> **Réponse attendue** : Non, le fichier n'existe plus. Les données écrites dans le filesystem d'un container sont éphémères et perdues quand le Pod est supprimé.

### 1.7 Nettoyage

```bash
kubectl delete pod pod-ephemeral -n lab-volumes
```

---

## Exercice 2 — Volume emptyDir : partage entre containers

### 2.1 Créer un Pod multi-containers avec emptyDir

Créez un fichier `pod-emptydir.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-emptydir
  namespace: lab-volumes
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "while true; do date >> /data/log.txt; sleep 5; done"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "sleep 10 && tail -f /data/log.txt"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
  volumes:
    - name: shared-data
      emptyDir: {}
```

```bash
kubectl apply -f pod-emptydir.yaml
```

### 2.2 Vérifier le partage de données

```bash
# Lire les logs écrits par le container writer via le container reader
kubectl logs -n lab-volumes pod-emptydir -c reader
```

**Question** : Le container `reader` voit-il les données écrites par le container `writer` ? Pourquoi ?

### 2.3 Vérifier le contenu du volume

```bash
kubectl exec -n lab-volumes pod-emptydir -c writer -- cat /data/log.txt
```

### 2.4 Nettoyage

```bash
kubectl delete pod pod-emptydir -n lab-volumes
```

**Question** : Que devient le contenu du volume `emptyDir` quand le Pod est supprimé ?

---

## Exercice 3 — PersistentVolume et PersistentVolumeClaim (provisionnement statique)

### 3.1 Vérifier les StorageClasses disponibles

```bash
kubectl get storageclass
```

**À observer** : la StorageClass `local-path` est disponible par défaut dans k3s/k3d.

### 3.2 Créer un PersistentVolume

Créez un fichier `pv.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: lab-pv
spec:
  storageClassName: ""
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/lab-pv-data
```

```bash
kubectl apply -f pv.yaml
```

### 3.3 Vérifier le PV

```bash
kubectl get pv
```

**Question** : Quel est le statut du PV ? Pourquoi est-il `Available` ?

### 3.4 Créer un PersistentVolumeClaim

Créez un fichier `pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lab-pvc
  namespace: lab-volumes
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
```

> **Note** : `storageClassName: ""` empêche le provisionnement dynamique et force le binding vers un PV existant.

```bash
kubectl apply -f pvc.yaml
```

### 3.5 Vérifier le binding

```bash
kubectl get pv
kubectl get pvc -n lab-volumes
```

**Question** : Le PVC est-il `Bound` ? À quel PV est-il lié ? Le statut du PV a-t-il changé ?

### 3.6 Inspecter le binding

```bash
kubectl describe pvc lab-pvc -n lab-volumes
kubectl describe pv lab-pv
```

**À observer** : les champs `Volume` (dans le PVC) et `Claim` (dans le PV) montrent le lien entre les deux.

---

## Exercice 4 — Utiliser un PVC dans un Pod

### 4.1 Créer un Pod qui utilise le PVC

Créez un fichier `pod-with-pvc.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-writer
  namespace: lab-volumes
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo 'données persistantes' > /data/message.txt && ls -la /data/ && sleep 3600"]
      volumeMounts:
        - name: storage
          mountPath: /data
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: lab-pvc
```

```bash
kubectl apply -f pod-with-pvc.yaml
```

### 4.2 Vérifier que les données sont écrites

```bash
kubectl exec -n lab-volumes pod-writer -- cat /data/message.txt
```

### 4.3 Supprimer le Pod

```bash
kubectl delete pod pod-writer -n lab-volumes
```

### 4.4 Recréer un Pod qui utilise le même PVC

Créez un fichier `pod-reader.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-reader
  namespace: lab-volumes
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /data/message.txt && sleep 3600"]
      volumeMounts:
        - name: storage
          mountPath: /data
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: lab-pvc
```

```bash
kubectl apply -f pod-reader.yaml
```

### 4.5 Vérifier la persistance des données

```bash
kubectl logs -n lab-volumes pod-reader
```

**Question** : Le fichier `message.txt` est-il toujours présent ? Les données ont-elles survécu à la suppression du Pod ?

### 4.6 Nettoyage des Pods

```bash
kubectl delete pod pod-reader -n lab-volumes
```

---

## Exercice 5 — Provisionnement dynamique avec StorageClass

### 5.1 Créer un PVC avec provisionnement dynamique

Créez un fichier `pvc-dynamic.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
  namespace: lab-volumes
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: local-path
```

```bash
kubectl apply -f pvc-dynamic.yaml
```

### 5.2 Vérifier le PVC

```bash
kubectl get pvc -n lab-volumes
```

**À observer** : le PVC peut rester en `Pending` car `local-path` utilise `WaitForFirstConsumer` — le PV n'est créé que quand un Pod utilise le PVC.

### 5.3 Créer un Pod qui utilise le PVC dynamique

Créez un fichier `pod-dynamic.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-dynamic
  namespace: lab-volumes
spec:
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: web-data
          mountPath: /usr/share/nginx/html
  volumes:
    - name: web-data
      persistentVolumeClaim:
        claimName: dynamic-pvc
```

```bash
kubectl apply -f pod-dynamic.yaml
```

### 5.4 Vérifier le provisionnement dynamique

```bash
# Le PVC doit maintenant être Bound
kubectl get pvc -n lab-volumes

# Un PV a été créé automatiquement
kubectl get pv
```

**Question** : Un nouveau PV a-t-il été créé automatiquement ? Quel est son nom ? Quelle est sa reclaim policy ?

### 5.5 Écrire des données dans le volume

```bash
kubectl exec -n lab-volumes pod-dynamic -- sh -c "echo '<h1>Hello from PVC</h1>' > /usr/share/nginx/html/index.html"
```

### 5.6 Vérifier le contenu

```bash
kubectl exec -n lab-volumes pod-dynamic -- curl -s http://localhost
```

**À observer** : nginx sert le fichier `index.html` depuis le volume persistant.

---

## Exercice 6 — Observer la reclaim policy

### 6.1 Vérifier les PV et PVC actuels

```bash
kubectl get pv,pvc -n lab-volumes
```

**À observer** : notez la reclaim policy de chaque PV (`Retain` pour le PV statique, `Delete` pour le PV dynamique).

### 6.2 Supprimer le Pod dynamique et le PVC

```bash
kubectl delete pod pod-dynamic -n lab-volumes
kubectl delete pvc dynamic-pvc -n lab-volumes
```

### 6.3 Vérifier l'effet sur le PV dynamique

```bash
kubectl get pv
```

**Question** : Le PV créé dynamiquement existe-t-il encore ? Pourquoi ? (Indice : reclaim policy `Delete`)

### 6.4 Supprimer le PVC statique

```bash
kubectl delete pvc lab-pvc -n lab-volumes
```

### 6.5 Vérifier l'effet sur le PV statique

```bash
kubectl get pv
```

**Question** : Le PV `lab-pv` existe-t-il encore ? Quel est son statut ? Pourquoi ? (Indice : reclaim policy `Retain`)

---

## Exercice 7 — Nettoyage complet

```bash
# Supprimer le PV statique (Released)
kubectl delete pv lab-pv

# Supprimer le namespace
kubectl delete namespace lab-volumes
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get pv
kubectl get pvc -n lab-volumes
kubectl get all -n lab-volumes
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Pourquoi les données d'un container sont-elles perdues quand un Pod est supprimé ?
2. Quelle est la différence entre un volume `emptyDir` et un PersistentVolume ?
3. Quel est le rôle du PersistentVolumeClaim par rapport au PersistentVolume ?
4. Comment Kubernetes lie-t-il un PVC à un PV ?
5. Quelle est la différence entre le provisionnement statique et dynamique ?
6. Que signifie `WaitForFirstConsumer` dans le `volumeBindingMode` d'une StorageClass ?
7. Quelle est la différence entre les reclaim policies `Retain` et `Delete` ?
