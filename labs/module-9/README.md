# Module 9 — Jobs et CronJobs

## Objectif

Exécuter des tâches ponctuelles ou planifiées dans Kubernetes en utilisant les objets Job et CronJob.

## Le problème

Un Deployment maintient des pods en permanence : si un pod s'arrête, il est redémarré. Mais certaines tâches ne doivent s'exécuter qu'une seule fois (ou de manière planifiée) puis se terminer :

| Cas d'usage | Description |
|---|---|
| Migration de base de données | Exécuter un script de migration une seule fois |
| Batch processing | Traiter un lot de données puis s'arrêter |
| Nettoyage | Supprimer des fichiers temporaires ou des données expirées |
| Sauvegarde | Lancer un backup à intervalles réguliers |
| Envoi de rapports | Générer et envoyer un rapport chaque jour |

Un Deployment n'est pas adapté à ces cas : il redémarrerait le pod indéfiniment. Kubernetes propose deux objets dédiés : le Job et le CronJob.

---

## Job

Un Job crée un ou plusieurs pods et s'assure qu'un nombre donné d'entre eux se terminent avec succès. Une fois la tâche complétée, le Job est marqué comme terminé (les pods ne sont pas redémarrés).

| Propriété | Description |
|---|---|
| Exécution | Lance un pod qui exécute une tâche jusqu'à complétion |
| Succès | Le Job est terminé quand le nombre de `completions` est atteint |
| Échec | En cas d'échec, le pod est relancé selon `backoffLimit` |
| Nettoyage | Les pods terminés restent visibles (pour consulter les logs) |

### Cycle de vie d'un Job

```
┌──────────────────────────────────────────────────────┐
│                        JOB                           │
│                                                      │
│  1. Création du Job                                  │
│     │                                                │
│     ▼                                                │
│  2. Le Job crée un Pod                               │
│     │                                                │
│     ├── Succès → completion +1                       │
│     │   └── completions atteint ? → Job Complete ✓   │
│     │                                                │
│     └── Échec → retry (backoffLimit)                 │
│         └── backoffLimit atteint ? → Job Failed ✗    │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Manifest Job simple

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
spec:
  template:
    spec:
      containers:
        - name: hello
          image: busybox:1.36
          command: ["echo", "Hello from Kubernetes Job!"]
      restartPolicy: Never
```

### Points clés

- `restartPolicy` doit être `Never` ou `OnFailure` (jamais `Always`)
  - `Never` : en cas d'échec, un nouveau pod est créé
  - `OnFailure` : le même pod est redémarré
- Le pod reste visible après complétion (état `Completed`) pour consulter les logs
- Le Job lui-même reste dans le cluster jusqu'à suppression manuelle (ou TTL)

---

## Paramètres clés d'un Job

### completions

Nombre de pods qui doivent se terminer avec succès pour que le Job soit considéré comme terminé.

```yaml
spec:
  completions: 5  # 5 pods doivent réussir
```

Par défaut : `1`.

### parallelism

Nombre de pods pouvant s'exécuter en parallèle.

```yaml
spec:
  parallelism: 3  # jusqu'à 3 pods en même temps
```

Par défaut : `1` (exécution séquentielle).

### backoffLimit

Nombre maximum de tentatives en cas d'échec avant de marquer le Job comme `Failed`.

```yaml
spec:
  backoffLimit: 4  # 4 tentatives max
```

Par défaut : `6`. Le délai entre les tentatives augmente exponentiellement (10s, 20s, 40s...).

### Combinaison completions + parallelism

| completions | parallelism | Comportement |
|---|---|---|
| 1 | 1 | 1 pod, séquentiel (défaut) |
| 5 | 1 | 5 pods, un à la fois |
| 5 | 3 | 5 pods au total, jusqu'à 3 en parallèle |
| 1 | 3 | 1 seul succès nécessaire, 3 pods lancés en parallèle |

### Manifest avec completions et parallelism

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  completions: 5
  parallelism: 2
  backoffLimit: 3
  template:
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo Processing item... && sleep 5 && echo Done"]
      restartPolicy: Never
```

Ce Job lance 5 pods au total, 2 à la fois maximum. Si un pod échoue, il est retenté jusqu'à 3 fois.

---

## TTL après complétion

Par défaut, les Jobs terminés (et leurs pods) restent dans le cluster. On peut configurer un nettoyage automatique avec `ttlSecondsAfterFinished` :

```yaml
spec:
  ttlSecondsAfterFinished: 120  # supprimé 2 minutes après complétion
```

| Valeur | Comportement |
|---|---|
| Non défini | Le Job reste indéfiniment |
| `0` | Supprimé immédiatement après complétion |
| `120` | Supprimé 120 secondes après complétion |

---

## CronJob

Un CronJob crée des Jobs de manière planifiée, selon une expression cron.

| Propriété | Description |
|---|---|
| Planification | Exécute un Job selon un schedule cron |
| Récurrence | Peut s'exécuter toutes les minutes, heures, jours, etc. |
| Gestion | Crée un nouvel objet Job à chaque exécution |
| Historique | Conserve un historique des Jobs exécutés |

### Syntaxe cron

```
┌───────────── minute (0 - 59)
│ ┌───────────── heure (0 - 23)
│ │ ┌───────────── jour du mois (1 - 31)
│ │ │ ┌───────────── mois (1 - 12)
│ │ │ │ ┌───────────── jour de la semaine (0 - 6, 0 = dimanche)
│ │ │ │ │
* * * * *
```

| Expression | Description |
|---|---|
| `*/5 * * * *` | Toutes les 5 minutes |
| `0 * * * *` | Toutes les heures (à la minute 0) |
| `0 2 * * *` | Tous les jours à 2h du matin |
| `0 0 * * 0` | Tous les dimanches à minuit |
| `0 9 1 * *` | Le 1er de chaque mois à 9h |

### Manifest CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-cronjob
spec:
  schedule: "*/10 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: cleanup
              image: busybox:1.36
              command: ["sh", "-c", "echo Cleanup started at $(date) && sleep 5 && echo Done"]
          restartPolicy: Never
```

### Champs importants du CronJob

| Champ | Description |
|---|---|
| `schedule` | Expression cron définissant la planification |
| `jobTemplate` | Template du Job à créer à chaque exécution |
| `successfulJobsHistoryLimit` | Nombre de Jobs réussis à conserver (défaut : 3) |
| `failedJobsHistoryLimit` | Nombre de Jobs échoués à conserver (défaut : 1) |
| `concurrencyPolicy` | Comportement si un Job est encore en cours au prochain déclenchement |
| `startingDeadlineSeconds` | Délai max pour démarrer un Job manqué |
| `suspend` | `true` pour suspendre le CronJob sans le supprimer |

### concurrencyPolicy

| Valeur | Comportement |
|---|---|
| `Allow` | Plusieurs Jobs peuvent s'exécuter en même temps (défaut) |
| `Forbid` | Le nouveau Job est ignoré si le précédent est encore en cours |
| `Replace` | Le Job en cours est supprimé et remplacé par le nouveau |

---

## Commandes utiles

```bash
# Jobs
kubectl get jobs
kubectl describe job <nom>
kubectl logs job/<nom>
kubectl delete job <nom>

# CronJobs
kubectl get cronjobs
kubectl describe cronjob <nom>
kubectl delete cronjob <nom>

# Voir les pods créés par un Job
kubectl get pods --selector=job-name=<nom-du-job>

# Déclencher manuellement un CronJob
kubectl create job --from=cronjob/<nom-cronjob> <nom-job-manuel>

# Suspendre / reprendre un CronJob
kubectl patch cronjob <nom> -p '{"spec":{"suspend":true}}'
kubectl patch cronjob <nom> -p '{"spec":{"suspend":false}}'
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
