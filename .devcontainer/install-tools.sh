#!/bin/bash
set -e

# 1. Installer k3d (pour faire tourner k3s dans Docker)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.6.0 bash

# 2. Installer kubectx et kubens
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# 3. Installer k9s (via binaire direct pour éviter les dépendances lourdes)
# Plus propre avec awk
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | awk -F '"' '{print $4}')
curl -sL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz | tar xz
sudo mv k9s /usr/local/bin/

# 4. Créer le cluster Kubernetes local (k3d)
# On mappe le port 8080 pour tester les Ingress/Services plus tard
# Version propre pour le script .sh
# k3d cluster create lab-cluster --agents 1 -p "8080:80@loadbalancer" --wait
#echo "Configuration terminée ! Tapez 'k9s' pour explorer votre cluster."