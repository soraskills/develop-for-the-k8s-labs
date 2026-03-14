# Module 9 — Lab : Jobs et CronJobs

## Prérequis

- Un cluster Kubernetes fonctionnel (k3d)
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Créer un Job simple

### 1.1 Créer un namespace dédié

```bash
kubectl create namespace lab-jobs
```

### 1.2 Créer un Job basique

Créez un fichier `job-simple.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
  namespace: lab-jobs
spec:
  template:
    spec:
      containers:
        - name: hello
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Hello from Kubernetes Job!' && date"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-simple.yaml
```

### 1.3 Observer l'exécution du Job

```bash
# Vérifier le statut du Job
kubectl get jobs -n lab-jobs

# Observer le pod créé par le Job
kubectl get pods -n lab-jobs
```

**À observer** : le pod passe par les états `ContainerCreating` → `Running` → `Completed`. Le Job affiche `1/1` dans la colonne `COMPLETIONS`.

### 1.4 Consulter les logs

```bash
kubectl logs job/hello-job -n lab-jobs
```

**Question** : Le message "Hello from Kubernetes Job!" apparaît-il dans les logs ? Le pod est-il en état `Completed` ?

### 1.5 Inspecter le Job

```bash
kubectl describe job hello-job -n lab-jobs
```

**À observer** : les conditions du Job (`Complete`), la durée d'exécution et le pod associé.

---

## Exercice 2 — Comprendre le comportement en cas d'échec

### 2.1 Créer un Job qui échoue

Créez un fichier `job-fail.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
  namespace: lab-jobs
spec:
  backoffLimit: 3
  template:
    spec:
      containers:
        - name: fail
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Attempting...' && exit 1"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-fail.yaml
```

### 2.2 Observer les tentatives

```bash
# Suivre l'évolution du Job
kubectl get jobs -n lab-jobs -w
```

Attendez quelques instants, puis dans un autre terminal :

```bash
# Voir les pods créés (un par tentative)
kubectl get pods -n lab-jobs -l job-name=failing-job
```

**À observer** : Kubernetes crée un nouveau pod à chaque tentative. Après 3 échecs (`backoffLimit: 3`), le Job est marqué comme `Failed`.

### 2.3 Vérifier le statut final

```bash
kubectl describe job failing-job -n lab-jobs
```

**Question** : Combien de pods ont été créés ? Quel est le statut final du Job ? Observez-vous le délai croissant entre les tentatives (backoff exponentiel) ?

---

## Exercice 3 — Job avec completions et parallelism

### 3.1 Créer un Job avec plusieurs completions

Créez un fichier `job-parallel.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
  namespace: lab-jobs
spec:
  completions: 6
  parallelism: 2
  template:
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo \"Pod $(hostname) processing...\" && sleep 5 && echo Done"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-parallel.yaml
```

### 3.2 Observer le parallélisme

```bash
# Suivre l'évolution des completions
kubectl get jobs -n lab-jobs -w
```

Dans un autre terminal :

```bash
# Observer les pods en temps réel
kubectl get pods -n lab-jobs -l job-name=batch-job -w
```

**À observer** : au maximum 2 pods tournent en même temps (`parallelism: 2`). Dès qu'un pod se termine, un nouveau est lancé jusqu'à atteindre 6 completions.

### 3.3 Vérifier le résultat

```bash
kubectl describe job batch-job -n lab-jobs
```

**Question** : Combien de pods ont été créés au total ? Combien de temps le Job a-t-il pris ? Comparez avec le temps qu'il aurait pris sans parallélisme (6 × 5s = 30s).

### 3.4 Consulter les logs de tous les pods

```bash
kubectl logs -n lab-jobs -l job-name=batch-job --prefix
```

**À observer** : chaque pod a un hostname différent, confirmant que ce sont bien des pods distincts.

---

## Exercice 4 — TTL et nettoyage automatique

### 4.1 Créer un Job avec TTL

Créez un fichier `job-ttl.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ttl-job
  namespace: lab-jobs
spec:
  ttlSecondsAfterFinished: 30
  template:
    spec:
      containers:
        - name: quick-task
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Quick task done' && date"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-ttl.yaml
```

### 4.2 Observer le nettoyage automatique

```bash
# Le Job est visible juste après complétion
kubectl get jobs -n lab-jobs

# Attendre 30 secondes puis vérifier
sleep 35
kubectl get jobs -n lab-jobs
```

**Question** : Le Job `ttl-job` a-t-il été automatiquement supprimé après 30 secondes ?

---

## Exercice 5 — CronJob

### 5.1 Créer un CronJob

Créez un fichier `cronjob.yaml` :

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: periodic-job
  namespace: lab-jobs
spec:
  schedule: "*/1 * * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: cron-task
              image: busybox:1.36
              command: ["sh", "-c", "echo \"Cron execution at $(date)\""]
          restartPolicy: Never
```

```bash
kubectl apply -f cronjob.yaml
```

### 5.2 Observer les exécutions

```bash
# Vérifier le CronJob
kubectl get cronjobs -n lab-jobs

# Attendre 2-3 minutes puis vérifier les Jobs créés
kubectl get jobs -n lab-jobs -l job-name -w
```

**À observer** : un nouveau Job est créé chaque minute. La colonne `LAST SCHEDULE` du CronJob indique la dernière exécution.

### 5.3 Vérifier l'historique

Après 4-5 minutes :

```bash
kubectl get jobs -n lab-jobs
```

**Question** : Combien de Jobs réussis sont conservés ? Correspond-il à `successfulJobsHistoryLimit: 3` ?

### 5.4 Déclencher manuellement un CronJob

```bash
kubectl create job manual-run --from=cronjob/periodic-job -n lab-jobs
```

```bash
kubectl get jobs -n lab-jobs
kubectl logs job/manual-run -n lab-jobs
```

**À observer** : on peut déclencher un CronJob à la demande sans attendre le prochain schedule.

### 5.5 Suspendre le CronJob

```bash
# Suspendre
kubectl patch cronjob periodic-job -n lab-jobs -p '{"spec":{"suspend":true}}'

# Vérifier
kubectl get cronjobs -n lab-jobs
```

**À observer** : la colonne `SUSPEND` passe à `True`. Aucun nouveau Job ne sera créé tant que le CronJob est suspendu.

```bash
# Reprendre
kubectl patch cronjob periodic-job -n lab-jobs -p '{"spec":{"suspend":false}}'
```

---

## Exercice 6 — Nettoyage complet

```bash
kubectl delete namespace lab-jobs
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get all -n lab-jobs
kubectl get jobs -n lab-jobs
kubectl get cronjobs -n lab-jobs
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quelle est la différence entre un Job et un Deployment ?
2. Quelles valeurs sont autorisées pour `restartPolicy` dans un Job ? Pourquoi `Always` n'est-il pas permis ?
3. Que se passe-t-il quand un pod d'un Job échoue ? Quel rôle joue `backoffLimit` ?
4. Comment `completions` et `parallelism` interagissent-ils pour contrôler l'exécution d'un Job ?
5. À quoi sert `ttlSecondsAfterFinished` ?
6. Quelle est la relation entre un CronJob et un Job ?
7. Que fait `concurrencyPolicy: Forbid` sur un CronJob ?
8. Comment déclencher manuellement l'exécution d'un CronJob ?
