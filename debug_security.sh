#!/bin/bash

echo "🔍 Diagnostic de sécurité Kubernetes"

# Vérifier la version de Kubernetes
echo "📋 Version Kubernetes:"
kubectl version --short

# Vérifier les resources API disponibles
echo ""
echo "📚 APIs de sécurité disponibles:"
echo "- NetworkPolicy: $(kubectl api-resources | grep networkpolicies | wc -l)"
echo "- PodSecurityPolicy: $(kubectl api-resources | grep podsecuritypolicy | wc -l)"
echo "- SecurityContextConstraints: $(kubectl api-resources | grep securitycontextconstraints | wc -l)"

# Vérifier le namespace
echo ""
echo "📁 Namespace tournoi-app:"
kubectl get namespace tournoi-app -o yaml

# Vérifier les service accounts
echo ""
echo "👤 Service Account:"
if kubectl get serviceaccount tournoi-service-account -n tournoi-app &>/dev/null; then
    kubectl describe serviceaccount tournoi-service-account -n tournoi-app
else
    echo "❌ Service Account 'tournoi-service-account' non trouvé"
fi

# Vérifier les rôles et bindings
echo ""
echo "🔐 RBAC Configuration:"
echo "Roles:"
kubectl get roles -n tournoi-app
echo "RoleBindings:"
kubectl get rolebindings -n tournoi-app

# Vérifier les secrets
echo ""
echo "🔑 Secrets:"
kubectl get secrets -n tournoi-app
if kubectl get secret postgres-secret -n tournoi-app &>/dev/null; then
    echo "✅ Secret postgres-secret existe"
    kubectl describe secret postgres-secret -n tournoi-app
else
    echo "❌ Secret postgres-secret non trouvé"
fi

# Vérifier les pods et leur contexte de sécurité
echo ""
echo "🔒 Pods Security Context:"
for pod in $(kubectl get pods -n tournoi-app -o jsonpath='{.items[*].metadata.name}'); do
    echo "Pod: $pod"
    kubectl get pod $pod -n tournoi-app -o jsonpath='{.spec.securityContext}' | jq . 2>/dev/null || echo "Pas de securityContext au niveau pod"
    echo "Container securityContext:"
    kubectl get pod $pod -n tournoi-app -o jsonpath='{.spec.containers[*].securityContext}' | jq . 2>/dev/null || echo "Pas de securityContext au niveau container"
    echo "---"
done

# Vérifier les events pour les erreurs
echo ""
echo "⚠️ Events récents (erreurs potentielles):"
kubectl get events -n tournoi-app --sort-by=.metadata.creationTimestamp | tail -10

# Vérifier les network policies
echo ""
echo "🌐 Network Policies:"
if kubectl api-resources | grep -q networkpolicies; then
    kubectl get networkpolicies -n tournoi-app
    if kubectl get networkpolicy tournoi-network-policy -n tournoi-app &>/dev/null; then
        echo "Détails de la politique réseau:"
        kubectl describe networkpolicy tournoi-network-policy -n tournoi-app
    fi
else
    echo "❌ NetworkPolicy non supporté par ce cluster"
fi

# Vérifier les pods qui ne démarrent pas
echo ""
echo "🚨 Pods en erreur:"
kubectl get pods -n tournoi-app | grep -E '(Error|CrashLoopBackOff|ImagePullBackOff|Pending)'

# Suggestions de correction
echo ""
echo "💡 Suggestions de correction:"
echo "1. Si les pods ne démarrent pas à cause du securityContext:"
echo "   - Vérifiez que votre image Docker peut tourner avec l'utilisateur 1000"
echo "   - Essayez de supprimer temporairement runAsUser et runAsNonRoot"
echo ""
echo "2. Si les secrets ne sont pas trouvés:"
echo "   - Vérifiez que le namespace existe: kubectl get namespace tournoi-app"
echo "   - Re-déployez les secrets: kubectl apply -f kubernetes/secrets.yaml"
echo ""
echo "3. Si les NetworkPolicy bloquent la communication:"
echo "   - Supprimez temporairement: kubectl delete networkpolicy --all -n tournoi-app"
echo "   - Testez la communication puis re-appliquez progressivement"
echo ""
echo "4. Pour debug un pod spécifique:"
echo "   kubectl describe pod <pod-name> -n tournoi-app"
echo "   kubectl logs <pod-name> -n tournoi-app"