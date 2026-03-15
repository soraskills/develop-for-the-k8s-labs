# Module 10 — GitOps avec ArgoCD

## Objectif

Découvrir l'approche GitOps et déployer une application sur Kubernetes via ArgoCD.

## Le problème

Jusqu'ici, on déploie nos applications avec `kubectl apply -f`. Cette approche pose plusieurs problèmes en équipe et en production :

| Problème | Description |
|---|---|
| Pas de source de vérité | Qui a appliqué quoi ? Quelle version tourne en prod ? |
| Pas d'historique | Impossible de savoir ce qui a changé et quand |
| Pas de rollback facile | Revenir en arrière nécessite de retrouver l'ancien manifest |
| Drift | L'état du cluster peut diverger de ce qui est dans Git |
| Pas de review | Les changements sont appliqués sans validation préalable |

---

## GitOps : Git comme source de vérité

Le GitOps est une pratique où l'état désiré de l'infrastructure est décrit dans un dépôt Git. Un outil (comme ArgoCD) surveille ce dépôt et synchronise automatiquement le cluster avec le contenu de Git.

```
┌──────────────┐     push      ┌──────────────┐     sync      ┌──────────────┐
│  Développeur │ ────────────► │   Git Repo   │ ◄──────────── │   ArgoCD     │
│              │               │  (manifests) │               │  (cluster)   │
└──────────────┘               └──────────────┘               └──────┬───────┘
                                                                     │
                                                                     ▼
                                                              ┌──────────────┐
                                                              │  Kubernetes  │
                                                              │   Cluster    │
                                                              └──────────────┘
```

### Principes du GitOps

| Principe | Description |
|---|---|
| Déclaratif | L'état désiré est décrit dans des fichiers (YAML, Helm, Kustomize) |
| Versionné | Tout est dans Git → historique, review, rollback via `git revert` |
| Automatisé | Un agent (ArgoCD) applique automatiquement les changements |
| Réconciliation | ArgoCD compare en continu l'état du cluster avec Git et corrige les drifts |

---

## ArgoCD

ArgoCD est un outil de déploiement continu GitOps pour Kubernetes. Il est lui-même déployé dans le cluster et surveille un ou plusieurs dépôts Git.

### Concepts clés

| Concept | Description |
|---|---|
| Application | Ressource ArgoCD qui lie un dépôt Git à un namespace Kubernetes |
| Source | Le dépôt Git contenant les manifests (path, revision) |
| Destination | Le cluster et namespace cible |
| Sync | Action de synchroniser l'état du cluster avec Git |
| Sync Policy | Automatique ou manuelle |
| Health Status | État de santé des ressources déployées |
| Sync Status | Comparaison entre Git et le cluster (`Synced`, `OutOfSync`) |

### Architecture simplifiée

```
┌─────────────────────────────────────────────────────┐
│                    ArgoCD                            │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  API Server  │  │  Repo Server │  │ Controller│ │
│  │  (UI + API)  │  │  (clone Git) │  │  (sync)   │ │
│  └─────────────┘  └──────────────┘  └───────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

| Composant | Rôle |
|---|---|
| API Server | Interface web et API REST, authentification |
| Repo Server | Clone les dépôts Git, génère les manifests |
| Application Controller | Compare l'état désiré (Git) avec l'état réel (cluster), effectue la synchronisation |

---

## Ressource Application

Une Application ArgoCD est définie par un manifest Kubernetes :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/user/repo.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Champs importants

| Champ | Description |
|---|---|
| `source.repoURL` | URL du dépôt Git |
| `source.targetRevision` | Branche, tag ou commit à suivre |
| `source.path` | Chemin dans le dépôt contenant les manifests |
| `destination.server` | URL du cluster cible (le cluster local par défaut) |
| `destination.namespace` | Namespace cible pour le déploiement |
| `syncPolicy.automated` | Active la synchronisation automatique |
| `syncPolicy.automated.prune` | Supprime les ressources qui ne sont plus dans Git |
| `syncPolicy.automated.selfHeal` | Corrige les modifications manuelles sur le cluster |

### Sync Policy

| Mode | Description |
|---|---|
| Manuel | L'utilisateur déclenche la synchronisation via l'UI ou la CLI |
| Automatique | ArgoCD synchronise dès qu'un changement est détecté dans Git |
| Automatique + prune | Les ressources supprimées de Git sont aussi supprimées du cluster |
| Automatique + selfHeal | Les modifications manuelles sur le cluster sont annulées |

---

## Statuts d'une Application

### Sync Status

| Statut | Description |
|---|---|
| `Synced` | L'état du cluster correspond à Git |
| `OutOfSync` | L'état du cluster diffère de Git |

### Health Status

| Statut | Description |
|---|---|
| `Healthy` | Toutes les ressources sont en bon état |
| `Progressing` | Un déploiement est en cours |
| `Degraded` | Une ou plusieurs ressources sont en erreur |
| `Missing` | Des ressources définies dans Git n'existent pas dans le cluster |

---

## Commandes utiles (CLI argocd)

```bash
# Se connecter
argocd login <server>

# Lister les applications
argocd app list

# Détails d'une application
argocd app get <nom>

# Synchroniser manuellement
argocd app sync <nom>

# Voir l'historique des syncs
argocd app history <nom>

# Rollback à une version précédente
argocd app rollback <nom> <history-id>

# Supprimer une application
argocd app delete <nom>
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
