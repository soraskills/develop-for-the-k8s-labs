# Module 10 — Lab : GitOps avec ArgoCD

## Prérequis

- Un cluster Kubernetes fonctionnel (k3d)
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Installer ArgoCD

### 1.1 Créer le namespace ArgoCD

```bash
kubectl create namespace argocd
```

### 1.2 Installer ArgoCD

```bash
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> **Note** : l'option `--server-side` est nécessaire car certaines CRDs d'ArgoCD dépassent la limite de taille des annotations `kubectl.kubernetes.io/last-applied-configuration` (256 Ko). Le server-side apply évite ce problème.

### 1.3 Vérifier l'installation

```bash
kubectl get pods -n argocd
```

Attendez que tous les pods soient en état `Running` :

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=120s
```

**À observer** : plusieurs composants sont déployés — `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-redis`, `argocd-dex-server`.

### 1.4 Récupérer le mot de passe admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Notez ce mot de passe, il sera utilisé pour se connecter à l'interface web.

### 1.5 Exposer l'interface web d'ArgoCD

Si le devcontainer est sur votre PC :

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Ouvrez votre navigateur sur `https://localhost:8081` (acceptez le certificat auto-signé).

Si le devcontainer est sur GitHub Codespaces:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443 --address 0.0.0.0
```

Puis dans l'onglet Ports de Visual Studio Code (à côté des Terminals):
- Passer le protocol à `HTTPS`
- Passer la visibilité à `Public`
- Cliquer sur la planète pour ouvrir l'interface ArgoCD

Connectez-vous avec :
- Utilisateur : `admin`
- Mot de passe : celui récupéré à l'étape 1.4

**À observer** : le dashboard ArgoCD est vide, aucune application n'est encore configurée.

---

## Exercice 2 — Préparer un dépôt Git avec des manifests

Pour ce lab, on va utiliser un dépôt Git public d'exemple fourni par ArgoCD.

Le dépôt `https://github.com/argoproj/argocd-example-apps` contient un dossier `guestbook/` avec une application simple (un Deployment et un Service).

### 2.1 Explorer le contenu du dépôt

Vérifiez le contenu du dossier `guestbook` :

```bash
# On peut voir les manifests directement depuis le dépôt
curl -s https://raw.githubusercontent.com/argoproj/argocd-example-apps/master/guestbook/guestbook-ui-deployment.yaml
curl -s https://raw.githubusercontent.com/argoproj/argocd-example-apps/master/guestbook/guestbook-ui-svc.yaml
```

**À observer** : le dossier contient un Deployment (`guestbook-ui`) et un Service de type ClusterIP.

---

## Exercice 3 — Créer une Application ArgoCD (sync manuel)

### 3.1 Créer l'Application

Créez un fichier `app-guestbook.yaml` :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: master
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl create namespace guestbook
kubectl apply -f app-guestbook.yaml
```

### 3.2 Vérifier l'état de l'Application

```bash
kubectl get applications -n argocd
```

**À observer** : l'application est en statut `OutOfSync` — ArgoCD a détecté les manifests dans Git mais ne les a pas encore appliqués (pas de sync policy automatique).

### 3.3 Observer dans l'interface web

Retournez sur `https://localhost:8080`. L'application `guestbook` apparaît avec un statut jaune `OutOfSync`.

Cliquez sur l'application pour voir le détail : ArgoCD montre les ressources qui seront créées (Deployment + Service).

### 3.4 Synchroniser manuellement

```bash
kubectl -n argocd patch application guestbook --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"apply":{"force":false}}}}}'
```

Ou plus simplement, cliquez sur le bouton `SYNC` dans l'interface web, puis `SYNCHRONIZE`.

### 3.5 Vérifier le déploiement

```bash
# L'application est déployée dans le namespace guestbook
kubectl get all -n guestbook
```

**À observer** : le Deployment et le Service ont été créés par ArgoCD. Le statut de l'application passe à `Synced` et `Healthy`.

### 3.6 Inspecter l'Application

```bash
kubectl describe application guestbook -n argocd
```

**À observer** : les champs `Sync Status`, `Health Status`, et la liste des ressources managées.

---

## Exercice 4 — Détecter un drift

### 4.1 Modifier manuellement une ressource

Changeons le nombre de réplicas directement sur le cluster (sans passer par Git) :

```bash
kubectl scale deployment guestbook-ui -n guestbook --replicas=3
```

### 4.2 Observer le drift

```bash
kubectl get applications -n argocd
```

**À observer** : l'application passe en `OutOfSync` — ArgoCD a détecté que l'état du cluster ne correspond plus à Git (Git dit 1 replica, le cluster en a 3).

### 4.3 Vérifier dans l'interface web

Dans l'UI, l'application est maintenant jaune. Cliquez dessus pour voir le diff : ArgoCD montre exactement ce qui a changé.

### 4.4 Resynchroniser

Cliquez sur `SYNC` puis `SYNCHRONIZE` dans l'interface web (ou utilisez le patch kubectl comme précédemment).

```bash
kubectl get deployment guestbook-ui -n guestbook
```

**Question** : Combien de réplicas sont maintenant en cours d'exécution ? Le drift a-t-il été corrigé ?

---
## Exercice 5 — Activer la synchronisation automatique

### 5.1 Activer le sync automatique avec selfHeal

```bash
kubectl -n argocd patch application guestbook --type merge -p '{
  "spec": {
    "syncPolicy": {
      "automated": {
        "prune": true,
        "selfHeal": true
      },
      "syncOptions": ["CreateNamespace=true"]
    }
  }
}'
```

### 5.2 Tester le selfHeal

Modifiez manuellement le nombre de réplicas :

```bash
kubectl scale deployment guestbook-ui -n guestbook --replicas=5
```

Attendez quelques secondes puis vérifiez :

```bash
kubectl get deployment guestbook-ui -n guestbook
```

**Question** : Combien de réplicas sont en cours d'exécution ? ArgoCD a-t-il automatiquement corrigé le drift ?

> **Réponse attendue** : ArgoCD remet automatiquement le nombre de réplicas à 1 (la valeur dans Git). C'est le selfHeal en action.

### 5.3 Vérifier dans l'interface web

**À observer** : l'application reste `Synced` et `Healthy` — ArgoCD corrige automatiquement tout drift.

---

## Exercice 6 — Déployer une deuxième application

### 6.1 Créer une application avec sync automatique

Créez un fichier `app-helm-guestbook.yaml` :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: master
    path: helm-guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f app-helm-guestbook.yaml
```

### 6.2 Vérifier le déploiement automatique

```bash
# L'application doit se synchroniser automatiquement
kubectl get applications -n argocd

# Vérifier les ressources déployées
kubectl get all -n helm-guestbook
```

**À observer** : cette fois, ArgoCD a automatiquement synchronisé l'application sans intervention manuelle. Le dossier `helm-guestbook` contient un chart Helm qu'ArgoCD sait interpréter nativement.

### 6.3 Observer les deux applications dans l'UI

Retournez sur `https://localhost:8080`.

**À observer** : les deux applications sont visibles, chacune avec son statut de sync et de santé.

---

## Exercice 7 — Nettoyage complet

### 7.1 Supprimer les applications ArgoCD

```bash
kubectl delete application guestbook -n argocd
kubectl delete application helm-guestbook -n argocd
```

**À observer** : ArgoCD supprime automatiquement les ressources Kubernetes associées (grâce à `prune`). Les namespaces `guestbook` et `helm-guestbook` et leur contenu sont nettoyés.

### 7.2 Vérifier la suppression

```bash
kubectl get all -n guestbook
kubectl get all -n helm-guestbook
```

### 7.3 Supprimer ArgoCD

```bash
kubectl delete namespace argocd 2>/dev/null
kubectl delete namespace guestbook 2>/dev/null
kubectl delete namespace helm-guestbook 2>/dev/null
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Qu'est-ce que le GitOps et quel problème résout-il ?
2. Quel est le rôle d'ArgoCD dans une approche GitOps ?
3. Quelle est la différence entre un sync manuel et un sync automatique ?
4. Que se passe-t-il quand on modifie une ressource directement sur le cluster (drift) ?
5. À quoi servent les options `prune` et `selfHeal` dans la sync policy ?
6. Comment ArgoCD sait-il quelles ressources déployer à partir d'un dépôt Git ?
7. Quelle est la différence entre les statuts `Synced` et `OutOfSync` ?
