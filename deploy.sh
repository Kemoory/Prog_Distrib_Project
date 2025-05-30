#!/bin/bash

echo "🚀 Déploiement de l'application Tournoi sur Kubernetes"

# Créer le namespace
echo "📁 Création du namespace..."
kubectl apply -f kubernetes/namespace.yaml

# Déployer les ConfigMaps
echo "⚙️ Déploiement des ConfigMaps..."
kubectl apply -f kubernetes/configmap.yaml

# Déployer le backend
echo "🔧 Déploiement du backend..."
kubectl apply -f kubernetes/backend-deployment.yaml
kubectl apply -f kubernetes/backend-service.yaml

# Attendre que le backend soit prêt
echo "⏳ Attente du démarrage du backend..."
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n tournoi-app

# Déployer le frontend
echo "🌐 Déploiement du frontend..."
kubectl apply -f kubernetes/frontend-deployment.yaml
kubectl apply -f kubernetes/frontend-service.yaml

# Attendre que le frontend soit prêt
echo "⏳ Attente du démarrage du frontend..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n tournoi-app

# Déployer l'Ingress
echo "🌍 Configuration de l'Ingress..."
kubectl apply -f kubernetes/ingress.yaml

echo "✅ Déploiement terminé!"
echo "📊 Status des pods:"
kubectl get pods -n tournoi-app

echo "🌐 Services:"
kubectl get services -n tournoi-app

echo "🚪 Ingress:"
kubectl get ingress -n tournoi-app

echo ""
echo "🎯 Pour accéder à l'application:"
echo "1. Ajoutez '<ip minikube> tournoi.local' à votre fichier /etc/hosts"
echo "2. Accédez à http://tournoi.local"
echo "3. API disponible sur http://tournoi.local/api/"