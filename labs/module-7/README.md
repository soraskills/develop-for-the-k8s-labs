# Module 7 — ConfigMaps et Secrets

## Objectif

Externaliser la configuration et les données sensibles des applications en utilisant les ConfigMaps et les Secrets.

## Le problème

Sans ConfigMap ni Secret, la configuration d'une application est souvent codée en dur dans l'image Docker ou passée directement dans le manifest du Pod. Cela pose plusieurs problèmes :

| Problème | Description |
|---|---|
| Couplage fort | L'image contient la configuration → il faut rebuilder pour chaque changement |
| Sécurité | Les mots de passe et clés API sont visibles dans les manifests ou le code |
| Réutilisabilité | Impossible de réutiliser la même image dans différents environnements (dev, staging, prod) |

La solution Kubernetes : séparer la configuration de l'application en utilisant des objets dédiés.

---

## ConfigMap

Un ConfigMap stocke de la configuration non sensible sous forme de paires clé/valeur ou de fichiers entiers.

| Propriété | Description |
|---|---|
| Données | Paires clé/valeur ou fichiers complets |
| Sensibilité | Données non sensibles uniquement |
| Encodage | Stocké en clair (pas d'encodage) |
| Taille max | 1 Mo par ConfigMap |
| Injection | Variables d'environnement ou montage en volume |

### Manifest ConfigMap

#### Clés/valeurs simples

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  APP_DEBUG: "false"
  APP_PORT: "8080"
```

#### Fichier de configuration complet

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
      listen 80;
      server_name localhost;
      location / {
        root /usr/share/nginx/html;
      }
    }
```

### Créer un ConfigMap en ligne de commande

```bash
# À partir de valeurs littérales
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080

# À partir d'un fichier
kubectl create configmap nginx-config \
  --from-file=nginx.conf

# À partir d'un répertoire (chaque fichier devient une clé)
kubectl create configmap config-dir \
  --from-file=./config/
```

---

## Secret

Un Secret stocke des données sensibles (mots de passe, tokens, clés SSH, certificats). Les valeurs sont encodées en base64.

| Propriété | Description |
|---|---|
| Données | Paires clé/valeur encodées en base64 |
| Sensibilité | Données sensibles (mots de passe, tokens, certificats) |
| Encodage | Base64 (attention : encodage ≠ chiffrement) |
| Taille max | 1 Mo par Secret |
| Injection | Variables d'environnement ou montage en volume |
| Types | `Opaque`, `kubernetes.io/tls`, `kubernetes.io/dockerconfigjson`, etc. |

### Important : base64 n'est pas du chiffrement

L'encodage base64 est réversible par n'importe qui :

```bash
# Encoder
echo -n "mon-mot-de-passe" | base64
# bW9uLW1vdC1kZS1wYXNzZQ==

# Décoder
echo "bW9uLW1vdC1kZS1wYXNzZQ==" | base64 -d
# mon-mot-de-passe
```

Les Secrets Kubernetes ne sont pas chiffrés par défaut. Pour un vrai chiffrement, il faut activer le chiffrement at-rest (`EncryptionConfiguration`) ou utiliser des solutions externes (Vault, Sealed Secrets, etc.).

### Manifest Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  DB_PASSWORD: cGFzc3dvcmQxMjM=    # "password123" en base64
  API_KEY: c2VjcmV0LWtleS14eXo=    # "secret-key-xyz" en base64
```

### Utiliser `stringData` pour éviter l'encodage manuel

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  DB_PASSWORD: "password123"
  API_KEY: "secret-key-xyz"
```

Avec `stringData`, Kubernetes encode automatiquement les valeurs en base64 lors de la création. C'est plus pratique pour les manifests.

### Créer un Secret en ligne de commande

```bash
# À partir de valeurs littérales
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=password123 \
  --from-literal=API_KEY=secret-key-xyz

# À partir d'un fichier
kubectl create secret generic tls-secret \
  --from-file=cert.pem \
  --from-file=key.pem
```

---

## Injection dans les Pods

Il existe deux méthodes pour injecter des ConfigMaps et Secrets dans un Pod.

### Méthode 1 : Variables d'environnement

#### Injecter des clés spécifiques

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: nginx:1.27
      env:
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_PASSWORD
```

#### Injecter toutes les clés d'un ConfigMap

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: nginx:1.27
      envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
```

Avec `envFrom`, chaque clé du ConfigMap/Secret devient une variable d'environnement.

### Méthode 2 : Montage en volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: config-volume
          mountPath: /etc/config
          readOnly: true
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: config-volume
      configMap:
        name: app-config
    - name: secret-volume
      secret:
        secretName: app-secret
```

Chaque clé du ConfigMap/Secret devient un fichier dans le répertoire de montage :

```
/etc/config/
├── APP_ENV          # contenu : "production"
├── APP_DEBUG        # contenu : "false"
└── APP_PORT         # contenu : "8080"

/etc/secrets/
├── DB_PASSWORD      # contenu : "password123"
└── API_KEY          # contenu : "secret-key-xyz"
```

### Comparaison des deux méthodes

| | Variables d'environnement | Montage en volume |
|---|---|---|
| Mise à jour | Nécessite un redémarrage du Pod | Mise à jour automatique (délai ~1 min) |
| Format | Clé=valeur uniquement | Fichiers complets possibles |
| Usage typique | Paramètres simples | Fichiers de configuration |
| Visibilité | Visible via `kubectl exec ... env` | Visible via `kubectl exec ... cat` |

---

## Bonnes pratiques

| Pratique | Description |
|---|---|
| Ne jamais commiter de Secrets | Les Secrets ne doivent pas être dans le dépôt Git |
| Utiliser `stringData` | Plus lisible que d'encoder manuellement en base64 |
| Monter en `readOnly` | Toujours monter les volumes de Secrets en lecture seule |
| Séparer ConfigMap et Secret | Ne pas mélanger configuration et données sensibles |
| Un ConfigMap par contexte | Regrouper les clés par domaine fonctionnel |
| Solutions externes | Pour la production, envisager Vault, Sealed Secrets ou External Secrets |

---

## Commandes utiles

```bash
# ConfigMaps
kubectl get configmap
kubectl get cm
kubectl describe configmap <nom>
kubectl get configmap <nom> -o yaml

# Secrets
kubectl get secret
kubectl get secret <nom> -o yaml
kubectl get secret <nom> -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Vérifier l'injection dans un Pod
kubectl exec <pod> -- env                          # variables d'environnement
kubectl exec <pod> -- cat /etc/config/APP_ENV      # fichier monté
kubectl exec <pod> -- ls /etc/secrets              # lister les fichiers secrets
```

---

## Lab

Passez au fichier [lab.md](./lab.md) pour la partie pratique.
