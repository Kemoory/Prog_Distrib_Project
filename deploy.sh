#!/bin/bash

echo "🚀 Déploiement complet de l'application Tournoi sur Kubernetes"

# Créer le namespace
echo "📁 Création du namespace..."
kubectl apply -f kubernetes/namespace.yaml

# Déployer la sécurité RBAC
echo "🔒 Configuration de la sécurité RBAC..."
kubectl apply -f kubernetes/rbac-security.yaml

# Déployer les secrets
echo "🔑 Déploiement des secrets..."
kubectl apply -f kubernetes/advanced-security.yaml

# Déployer les ConfigMaps
echo "⚙️ Déploiement des ConfigMaps..."
kubectl apply -f kubernetes/configmap.yaml

# Déployer PostgreSQL
echo "🗄️ Déploiement de la base de données PostgreSQL..."
kubectl apply -f kubernetes/postgres-deployment.yaml

# Attendre que PostgreSQL soit prêt
echo "⏳ Attente du démarrage de PostgreSQL..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres-deployment -n tournoi-app

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

# Déployer l'Ingress sécurisé
echo "🌍 Configuration de l'Ingress sécurisé..."
kubectl apply -f kubernetes/ingress.yaml

# Vérifier le déploiement
echo "✅ Déploiement terminé!"
echo ""
echo "📊 Status des pods:"
kubectl get pods -n tournoi-app -o wide

echo ""
echo "🌐 Services:"
kubectl get services -n tournoi-app

echo ""
echo "🚪 Ingress:"
kubectl get ingress -n tournoi-app

echo ""
echo "🔒 RBAC configuré:"
kubectl get serviceaccounts,roles,rolebindings -n tournoi-app

echo ""
echo "🗄️ Base de données:"
kubectl get pvc -n tournoi-app

echo ""
echo "🎯 Pour accéder à l'application:"
echo "1. Ajoutez '<ip minikube> tournoi.local' à votre fichier /etc/hosts"
echo "   Obtenez l'IP avec: minikube ip"
echo "2. Accédez à http://tournoi.local"
echo "3. API disponible sur http://tournoi.local/api/"
echo ""
echo "🔧 Commandes utiles:"
echo "- Logs backend: kubectl logs -f deployment/backend-deployment -n tournoi-app"
echo "- Logs frontend: kubectl logs -f deployment/frontend-deployment -n tournoi-app"
echo "- Logs PostgreSQL: kubectl logs -f deployment/postgres-deployment -n tournoi-app"
echo "- Port-forward DB: kubectl port-forward service/postgres-service 5432:5432 -n tournoi-app"