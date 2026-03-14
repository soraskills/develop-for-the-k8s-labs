# Module 7 — Lab : ConfigMaps et Secrets

## Prérequis

- Un cluster Kubernetes fonctionnel
- `kubectl` configuré et connecté au cluster

---

## Exercice 1 — Créer un ConfigMap

### 1.1 Créer un namespace dédié

```bash
kubectl create namespace lab-config
```

### 1.2 Créer un ConfigMap avec des clés/valeurs

Créez un fichier `configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: lab-config
data:
  APP_ENV: "production"
  APP_COLOR: "blue"
  APP_MESSAGE: "Hello from ConfigMap"
```

```bash
kubectl apply -f configmap.yaml
```

### 1.3 Vérifier le ConfigMap

```bash
kubectl get configmap -n lab-config
kubectl describe configmap app-config -n lab-config
kubectl get configmap app-config -n lab-config -o yaml
```

**Question** : Quelles clés sont présentes dans le ConfigMap ? Les valeurs sont-elles stockées en clair ?

---

## Exercice 2 — Créer un Secret

### 2.1 Créer un Secret avec `stringData`

Créez un fichier `secret.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: lab-config
type: Opaque
stringData:
  DB_PASSWORD: "super-secret-password"
  API_KEY: "my-api-key-12345"
```

```bash
kubectl apply -f secret.yaml
```

### 2.2 Vérifier le Secret

```bash
kubectl get secret -n lab-config
kubectl describe secret app-secret -n lab-config
```

**À observer** : `kubectl describe` ne montre pas les valeurs des Secrets, seulement leur taille en octets.

### 2.3 Décoder les valeurs du Secret

```bash
# Voir le Secret en YAML (valeurs encodées en base64)
kubectl get secret app-secret -n lab-config -o yaml

# Décoder une valeur spécifique
kubectl get secret app-secret -n lab-config -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo  # retour à la ligne
```

**Question** : Les valeurs dans le YAML sont-elles lisibles directement ? Que donne le décodage base64 ?

---

## Exercice 3 — Injecter un ConfigMap comme variables d'environnement

### 3.1 Créer un Pod avec injection par `envFrom`

Créez un fichier `pod-env.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-env
  namespace: lab-config
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      envFrom:
        - configMapRef:
            name: app-config
```

```bash
kubectl apply -f pod-env.yaml
```

### 3.2 Vérifier les variables d'environnement

```bash
# Attendre que le pod soit Running
kubectl get pod pod-env -n lab-config

# Lister les variables d'environnement
kubectl exec pod-env -n lab-config -- env | grep APP_
```

**Question** : Les trois variables `APP_ENV`, `APP_COLOR` et `APP_MESSAGE` sont-elles présentes ? Leurs valeurs correspondent-elles au ConfigMap ?

### 3.3 Injecter des clés spécifiques

Créez un fichier `pod-env-specific.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-env-specific
  namespace: lab-config
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
        - name: PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_PASSWORD
```

```bash
kubectl apply -f pod-env-specific.yaml
```

```bash
kubectl exec pod-env-specific -n lab-config -- env | grep -E "ENVIRONMENT|PASSWORD"
```

**Question** : Les variables ont-elles les noms personnalisés (`ENVIRONMENT`, `PASSWORD`) ? Les valeurs sont-elles correctes ?

---

## Exercice 4 — Monter un Secret comme fichier dans un Pod

### 4.1 Créer un Pod avec montage en volume

Créez un fichier `pod-volume.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-volume
  namespace: lab-config
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
        - name: config-volume
          mountPath: /etc/config
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: app-secret
    - name: config-volume
      configMap:
        name: app-config
```

```bash
kubectl apply -f pod-volume.yaml
```

### 4.2 Vérifier les fichiers montés

```bash
# Attendre que le pod soit Running
kubectl get pod pod-volume -n lab-config

# Lister les fichiers de configuration
kubectl exec pod-volume -n lab-config -- ls /etc/config

# Lire une valeur de configuration
kubectl exec pod-volume -n lab-config -- cat /etc/config/APP_ENV

# Lister les fichiers secrets
kubectl exec pod-volume -n lab-config -- ls /etc/secrets

# Lire une valeur secrète
kubectl exec pod-volume -n lab-config -- cat /etc/secrets/DB_PASSWORD
```

**Question** : Chaque clé est-elle devenue un fichier ? Le contenu des fichiers correspond-il aux valeurs du ConfigMap et du Secret ?

### 4.3 Vérifier que le montage est en lecture seule

```bash
kubectl exec pod-volume -n lab-config -- sh -c "echo test > /etc/secrets/NEW_FILE"
```

**Question** : Que se passe-t-il quand on essaie d'écrire dans le volume monté en `readOnly` ?

---

## Exercice 5 — Mise à jour dynamique

### 5.1 Modifier le ConfigMap

```bash
kubectl edit configmap app-config -n lab-config
```

Changez la valeur de `APP_COLOR` de `blue` à `red`, puis sauvegardez.

Ou via `kubectl patch` :

```bash
kubectl patch configmap app-config -n lab-config \
  --type merge -p '{"data":{"APP_COLOR":"red"}}'
```

### 5.2 Observer la mise à jour dans le volume

```bash
# Vérifier la valeur dans le pod avec montage en volume (attendre ~1 minute)
kubectl exec pod-volume -n lab-config -- cat /etc/config/APP_COLOR
```

**À observer** : La valeur est mise à jour automatiquement dans le volume monté (avec un délai pouvant aller jusqu'à 1 minute).

### 5.3 Observer les variables d'environnement

```bash
# Vérifier la valeur dans le pod avec envFrom
kubectl exec pod-env -n lab-config -- env | grep APP_COLOR
```

**Question** : La variable d'environnement a-t-elle été mise à jour ? Pourquoi ?

> **Réponse attendue** : Non. Les variables d'environnement ne sont pas mises à jour dynamiquement. Il faut redémarrer le Pod pour prendre en compte les changements.

---

## Exercice 6 — Nettoyage complet

```bash
kubectl delete namespace lab-config
```

Vérifiez que toutes les ressources ont été supprimées :

```bash
kubectl get all -n lab-config
kubectl get configmap -n lab-config
kubectl get secret -n lab-config
```

---

## Vérification des acquis

À la fin de ce lab, vous devez être capable de répondre à ces questions :

1. Quelle est la différence entre un ConfigMap et un Secret ?
2. Pourquoi l'encodage base64 des Secrets n'est-il pas une mesure de sécurité ?
3. Comment injecter un ConfigMap comme variables d'environnement dans un Pod ?
4. Comment monter un Secret comme fichier dans un Pod ?
5. Quelle est la différence de comportement lors d'une mise à jour entre l'injection par variable d'environnement et le montage en volume ?
6. Pourquoi est-il recommandé de monter les Secrets en `readOnly` ?
7. Quel avantage offre `stringData` par rapport à `data` dans un manifest Secret ?
