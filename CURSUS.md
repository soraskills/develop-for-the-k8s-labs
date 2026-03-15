# Kubernetes Training — Master 2 Cursus

Training progressif Kubernetes, du cluster à l'orchestration avancée. Chaque module va à l'essentiel pour comprendre les concepts fondamentaux.

---

## Module 1 — Composants d'un Cluster Kubernetes

Comprendre l'architecture d'un cluster Kubernetes et le rôle de chaque composant.

### Concepts abordés

- Architecture Control Plane / Worker Nodes
- Le namespace `kube-system` et ses pods système :
  - `etcd` — base de données clé/valeur du cluster
  - `kube-apiserver` — point d'entrée de toutes les requêtes
  - `kube-scheduler` — placement des pods sur les nœuds
  - `kube-controller-manager` — boucles de réconciliation
  - `coredns` — résolution DNS interne
  - `kube-proxy` — règles réseau sur chaque nœud
- Interaction avec `kubectl` et `k9s` pour explorer le cluster
- `k9s` : interface terminal interactive pour naviguer dans le cluster

### Lab

- Explorer le cluster avec `kubectl`
- Utiliser `k9s` pour naviguer visuellement dans le cluster
- Lister les namespaces système et les pods du namespace `kube-system`
- Identifier le rôle de chaque pod système

---

## Module 2 — Objets de base : Pod, ReplicaSet, Deployment

Comprendre la hiérarchie des objets fondamentaux de Kubernetes.

### Concepts abordés

- Le Pod : plus petite unité déployable
- Le ReplicaSet : maintenir un nombre de réplicas d'un pod
- Le Deployment : gestion déclarative des ReplicaSets, rolling updates, rollbacks
- Relations entre ces objets (Deployment → ReplicaSet → Pod)

### Lab

- Créer un Pod simple
- Créer un ReplicaSet et observer le maintien du nombre de réplicas
- Créer un Deployment, effectuer un rolling update et un rollback

---

## Module 3 — Namespaces, Quotas, NetworkPolicies, LimitRanges

Isoler et contrôler les ressources au sein d'un cluster.

### Concepts abordés

- Namespaces : isolation logique des ressources
- ResourceQuota : limiter la consommation globale d'un namespace (CPU, mémoire, nombre d'objets)
- LimitRange : définir des limites par défaut et des contraintes par pod/container dans un namespace
- NetworkPolicy : contrôler le trafic réseau entre pods (ingress/egress)

### Lab

- Créer un namespace dédié
- Appliquer un ResourceQuota et observer le comportement quand la limite est atteinte
- Configurer un LimitRange avec des defaults
- Mettre en place une NetworkPolicy pour restreindre la communication entre pods

---

## Module 4 — Services : ClusterIP et NodePort

Comprendre comment exposer une application à l'intérieur puis à l'extérieur du cluster.

### Concepts abordés

- Le concept de Service dans Kubernetes
- Sélection des pods via les labels
- ClusterIP : service par défaut, accessible uniquement depuis l'intérieur du cluster
- Résolution DNS interne des services
- NodePort : extension de ClusterIP, expose le service sur un port de chaque nœud
- Mapping des ports : port, targetPort, nodePort
- Relation entre NodePort et ClusterIP (NodePort wrappe un ClusterIP)

### Lab

- Déployer une application et l'exposer via un Service ClusterIP
- Tester l'accès au service depuis un autre pod dans le cluster (via DNS interne)
- Passer le service en NodePort et accéder à l'application depuis l'extérieur du cluster

---

## Module 5 — Ingress avec Traefik

Router le trafic HTTP vers les services via un Ingress Controller.

### Concepts abordés

- Le rôle d'un Ingress Controller
- Traefik comme Ingress Controller
- Ressource Ingress : règles de routage basées sur le host et le path
- Lien entre Ingress → Service → Pods

### Lab

- Vérifier que Traefik est déployé comme Ingress Controller
- Créer une ressource Ingress pour router le trafic vers un service
- Tester le routage HTTP basé sur le host ou le path

---

## Module 6 — Horizontal Pod Autoscaler (HPA)

Adapter automatiquement le nombre de pods en fonction de la charge.

### Concepts abordés

- Le Horizontal Pod Autoscaler (HPA)
- Métriques utilisées : CPU, mémoire
- Fonctionnement : seuil cible → scale up / scale down
- Prérequis : metrics-server
- Lien avec les requests/limits des containers

### Lab

- Déployer une application avec des resource requests définies
- Créer un HPA basé sur l'utilisation CPU
- Générer de la charge et observer le scaling automatique

---

## Module 7 — ConfigMaps et Secrets

Externaliser la configuration et les données sensibles.

### Concepts abordés

- ConfigMap : stocker de la configuration non sensible (clés/valeurs, fichiers)
- Secret : stocker des données sensibles (encodées en base64)
- Injection dans les pods : variables d'environnement ou montage en volume
- Bonnes pratiques de gestion des secrets

### Lab

- Créer un ConfigMap et un Secret
- Injecter un ConfigMap comme variable d'environnement dans un pod
- Monter un Secret comme fichier dans un pod

---

## Module 8 — Volumes, PersistentVolume, PersistentVolumeClaim

Persister les données au-delà du cycle de vie d'un pod.

### Concepts abordés

- Problème : les données d'un container sont éphémères
- Volume : stockage attaché à un pod
- PersistentVolume (PV) : ressource de stockage provisionnée dans le cluster
- PersistentVolumeClaim (PVC) : demande de stockage par un pod
- StorageClass et provisionnement dynamique
- Access modes : ReadWriteOnce, ReadOnlyMany, ReadWriteMany

### Lab

- Créer un PersistentVolume et un PersistentVolumeClaim
- Monter un PVC dans un pod et vérifier la persistance des données après suppression du pod

---

## Module 9 — Jobs et CronJobs

Exécuter des tâches ponctuelles ou planifiées.

### Concepts abordés

- Job : exécuter une tâche jusqu'à complétion (un ou plusieurs pods)
- Paramètres clés : `completions`, `parallelism`, `backoffLimit`
- CronJob : planifier l'exécution récurrente d'un Job (syntaxe cron)
- Cas d'usage : migrations, batch processing, nettoyage

### Lab (Job uniquement)

- Créer un Job simple et observer son exécution jusqu'à complétion
- Configurer un Job avec plusieurs completions et du parallélisme

---

## Module 10 — GitOps avec ArgoCD

Découvrir l'approche GitOps et déployer une application via ArgoCD.

### Concepts abordés

- GitOps : Git comme source de vérité pour l'état du cluster
- ArgoCD : outil de déploiement continu GitOps
- Application ArgoCD : lien entre un dépôt Git et un namespace Kubernetes
- Synchronisation manuelle et automatique
- Détection et correction de drift (selfHeal)
- Sync policy : prune, selfHeal

### Lab

- Installer ArgoCD dans le cluster
- Créer une Application ArgoCD pointant vers un dépôt Git
- Synchroniser manuellement puis automatiquement
- Observer la détection et correction de drift
- Déployer une application Helm via ArgoCD
