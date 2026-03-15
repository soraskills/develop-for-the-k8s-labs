# Formation Kubernetes — Master 2

Formation progressive Kubernetes, du cluster à l'orchestration avancée avec GitOps. Chaque module va à l'essentiel avec une partie théorique et un lab pratique.

## Prérequis

- [Visual Studio Code](https://code.visualstudio.com/) avec l'extension [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installé et lancé
- Ou un compte [GitHub](https://github.com/) pour utiliser GitHub Codespaces

Aucune installation locale de Kubernetes n'est nécessaire : tout est fourni dans le Dev Container.

## Démarrage rapide

### Option 1 — VS Code + Dev Container (recommandé)

1. Cloner le dépôt :
   ```bash
   git clone <url-du-repo>
   cd <nom-du-repo>
   ```
2. Ouvrir le dossier dans VS Code
3. VS Code détecte le fichier `.devcontainer/devcontainer.json` et propose de rouvrir dans le container → cliquer sur **Reopen in Container**
4. Attendre la fin du build (première fois un peu plus long)
5. Un terminal s'ouvre avec tous les outils prêts à l'emploi

### Option 2 — GitHub Codespaces

1. Sur la page GitHub du dépôt, cliquer sur **Code** → **Codespaces** → **Create codespace on main**
2. L'environnement se construit automatiquement avec tous les outils
3. Vous êtes prêts à travailler directement dans le navigateur

## Environnement fourni

Le Dev Container inclut automatiquement :

| Outil | Description |
|---|---|
| `kubectl` | CLI officielle Kubernetes |
| `helm` | Gestionnaire de packages Kubernetes |
| `k3d` | Création de clusters k3s dans Docker |
| `k9s` | Interface terminal interactive pour Kubernetes |
| `kubectx` / `kubens` | Changement rapide de contexte et namespace |
| `docker` | Docker-in-Docker pour k3d |

## Modules

| Module | Sujet |
|---|---|
| [Module 0](labs/module-0/) | Setup du cluster Kubernetes avec k3d |
| [Module 1](labs/module-1/) | Composants d'un cluster Kubernetes |
| [Module 2](labs/module-2/) | Pod, ReplicaSet, Deployment |
| [Module 3](labs/module-3/) | Namespaces, Quotas, NetworkPolicies, LimitRanges |
| [Module 4](labs/module-4/) | Services : ClusterIP et NodePort |
| [Module 5](labs/module-5/) | Ingress avec Traefik |
| [Module 6](labs/module-6/) | Horizontal Pod Autoscaler (HPA) |
| [Module 7](labs/module-7/) | ConfigMaps et Secrets |
| [Module 8](labs/module-8/) | Volumes, PersistentVolume, PersistentVolumeClaim |
| [Module 9](labs/module-9/) | Jobs et CronJobs |
| [Module 10](labs/module-10/) | GitOps avec ArgoCD |

Chaque module contient un `README.md` (théorie) et un `lab.md` (exercices pratiques).

## Structure du dépôt

```
.
├── .devcontainer/          # Configuration Dev Container
│   ├── devcontainer.json
│   └── install-tools.sh    # Installation k3d, k9s, kubectx
├── labs/
│   ├── module-0/           # Setup du cluster
│   ├── module-1/           # → module-10
│   └── ...
├── tmp/                    # Manifests YAML d'exemple
├── CURSUS.md               # Vue d'ensemble du programme
└── README.md
```

## Premier lab

Une fois dans le Dev Container, commencez par le [Module 0](labs/module-0/) pour créer votre cluster Kubernetes local.

## Licence

Voir le fichier [LICENSE](LICENSE).
