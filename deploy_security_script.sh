#!/bin/bash

echo "🔒 Déploiement sécurisé de l'application Tournoi"

# Vérifier que kubectl est configuré
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl n'est pas configuré ou le cluster n'est pas accessible"
    exit 1
fi

# Créer le namespace
echo "📁 Création du namespace..."
kubectl apply -f kubernetes/namespace.yaml

# Déployer RBAC en premier
echo "🔐 Configuration RBAC..."
kubectl apply -f kubernetes/rbac-security.yaml

# Attendre que le service account soit créé
echo "⏳ Attente de la création du service account..."
kubectl wait --for=condition=ready serviceaccount/tournoi-service-account -n tournoi-app --timeout=60s

# Déployer les secrets
echo "🔑 Déploiement des secrets..."
kubectl apply -f kubernetes/secrets.yaml

# Déployer PostgreSQL
echo "🗄️ Déploiement PostgreSQL..."
kubectl apply -f kubernetes/postgres-deployment.yaml

# Attendre PostgreSQL
echo "⏳ Attente PostgreSQL..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres-deployment -n tournoi-app

# Déployer backend sécurisé
echo "🔧 Déploiement backend sécurisé..."
kubectl apply -f kubernetes/backend-deployment-secure.yaml
kubectl apply -f kubernetes/backend-service.yaml

# Attendre backend
echo "⏳ Attente backend..."
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n tournoi-app

# Déployer frontend sécurisé  
echo "🌐 Déploiement frontend sécurisé..."
kubectl apply -f kubernetes/frontend-deployment-secure.yaml
kubectl apply -f kubernetes/frontend-service.yaml

# Attendre frontend
echo "⏳ Attente frontend..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n tournoi-app

# Déployer les politiques réseau
echo "🌐 Configuration des politiques réseau..."
# Vérifier si le cluster supporte les NetworkPolicy
if kubectl api-resources | grep -q networkpolicies; then
    kubectl apply -f kubernetes/network-policy.yaml
    echo "✅ NetworkPolicy appliquées"
else
    echo "⚠️ NetworkPolicy non supportées par ce cluster"
fi

# Déployer ingress sécurisé
echo "🚪 Configuration ingress sécurisé..."
kubectl apply -f kubernetes/ingress-secure.yaml

echo ""
echo "✅ Déploiement sécurisé terminé!"

# Vérifications
echo ""
echo "🔍 Vérifications de sécurité:"

# Vérifier les service accounts
echo "👤 Service Accounts:"
kubectl get serviceaccounts -n tournoi-app

# Vérifier les secrets
echo "🔑 Secrets:"
kubectl get secrets -n tournoi-app

# Vérifier les pods avec leur contexte de sécurité
echo "🔒 Pods avec contexte de sécurité:"
kubectl get pods -n tournoi-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\t"}{.spec.securityContext.runAsNonRoot}{"\n"}{end}' | column -t

# Vérifier les network policies si disponibles
if kubectl api-resources | grep -q networkpolicies; then
    echo "🌐 Network Policies:"
    kubectl get networkpolicies -n tournoi-app
fi

echo ""
echo "📊 Status final:"
kubectl get all -n tournoi-app

echo ""
echo "🎯 Application accessible sur:"
echo "- http://tournoi.local (après ajout dans /etc/hosts)"
echo "- IP Minikube: $(minikube ip 2>/dev/null || echo 'N/A')"

echo ""
echo "🔧 Commandes de debug:"
echo "- kubectl logs -f deployment/backend-deployment -n tournoi-app"
echo "- kubectl logs -f deployment/frontend-deployment -n tournoi-app" 
echo "- kubectl describe pod <pod-name> -n tournoi-app"