#!/bin/bash

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les résultats
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "${BLUE}🧪 BATTERIE DE TESTS - APPLICATION TOURNOI${NC}"
echo "=============================================="

# 1. TESTS DE BASE - DÉPLOIEMENT
echo -e "\n${YELLOW}📦 1. TESTS DE DÉPLOIEMENT${NC}"
echo "----------------------------"

# Vérifier que le namespace existe
kubectl get namespace tournoi-app &>/dev/null
print_result $? "Namespace tournoi-app existe"

# Vérifier tous les déploiements
deployments=("backend-deployment" "frontend-deployment" "postgres-deployment")
for deployment in "${deployments[@]}"; do
    kubectl get deployment $deployment -n tournoi-app &>/dev/null
    print_result $? "Déploiement $deployment existe"
    
    # Vérifier que le déploiement est prêt
    ready=$(kubectl get deployment $deployment -n tournoi-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    replicas=$(kubectl get deployment $deployment -n tournoi-app -o jsonpath='{.spec.replicas}' 2>/dev/null)
    if [ "$ready" = "$replicas" ] && [ "$ready" != "" ]; then
        print_result 0 "Déploiement $deployment est prêt ($ready/$replicas)"
    else
        print_result 1 "Déploiement $deployment n'est pas prêt ($ready/$replicas)"
    fi
done

# 2. TESTS POSTGRESQL
echo -e "\n${YELLOW}🗄️  2. TESTS POSTGRESQL${NC}"
echo "------------------------"

# Vérifier que PostgreSQL est accessible
print_info "Test de connectivité PostgreSQL..."
kubectl run postgres-test --rm -i --restart=Never --image=postgres:15 --env="PGPASSWORD=mypassword" -n tournoi-app -- psql -h postgres-service -U username -d tournament_db -c "SELECT 1;" &>/dev/null
print_result $? "Connexion à PostgreSQL réussie"

# Vérifier le PVC
kubectl get pvc postgres-pvc -n tournoi-app &>/dev/null
print_result $? "PVC PostgreSQL existe"

pvc_status=$(kubectl get pvc postgres-pvc -n tournoi-app -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$pvc_status" = "Bound" ]; then
    print_result 0 "PVC PostgreSQL est lié (Bound)"
else
    print_result 1 "PVC PostgreSQL n'est pas lié (Status: $pvc_status)"
fi

# Test de persistance des données
print_info "Test de persistance des données..."
kubectl exec -n tournoi-app deployment/postgres-deployment -- psql -U username -d tournament_db -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));" &>/dev/null
kubectl exec -n tournoi-app deployment/postgres-deployment -- psql -U username -d tournament_db -c "INSERT INTO test_table (name) VALUES ('test_persistence');" &>/dev/null
result=$(kubectl exec -n tournoi-app deployment/postgres-deployment -- psql -U username -d tournament_db -t -c "SELECT COUNT(*) FROM test_table WHERE name='test_persistence';" 2>/dev/null | tr -d ' ')
if [ "$result" = "1" ]; then
    print_result 0 "Persistance des données PostgreSQL"
else
    print_result 1 "Problème de persistance des données PostgreSQL"
fi

# 3. TESTS RBAC
echo -e "\n${YELLOW}🔒 3. TESTS RBAC${NC}"
echo "----------------"

# Vérifier ServiceAccount
kubectl get serviceaccount tournoi-service-account -n tournoi-app &>/dev/null
print_result $? "ServiceAccount tournoi-service-account existe"

# Vérifier Role
kubectl get role tournoi-role -n tournoi-app &>/dev/null
print_result $? "Role tournoi-role existe"

# Vérifier RoleBinding
kubectl get rolebinding tournoi-role-binding -n tournoi-app &>/dev/null
print_result $? "RoleBinding tournoi-role-binding existe"

# Test des permissions RBAC
print_info "Test des permissions RBAC..."
kubectl auth can-i get pods --as=system:serviceaccount:tournoi-app:tournoi-service-account -n tournoi-app &>/dev/null
print_result $? "ServiceAccount peut lister les pods"

kubectl auth can-i delete pods --as=system:serviceaccount:tournoi-app:tournoi-service-account -n tournoi-app &>/dev/null
if [ $? -ne 0 ]; then
    print_result 0 "ServiceAccount ne peut PAS supprimer les pods (sécurité OK)"
else
    print_result 1 "ServiceAccount peut supprimer les pods (problème de sécurité)"
fi

# 4. TESTS NETWORK POLICY
echo -e "\n${YELLOW}🌐 4. TESTS NETWORK POLICY${NC}"
echo "----------------------------"

kubectl get networkpolicy tournoi-network-policy -n tournoi-app &>/dev/null
print_result $? "NetworkPolicy tournoi-network-policy existe"

# Test de connectivité réseau interne
print_info "Test de connectivité réseau interne..."
kubectl run network-test --rm -i --restart=Never --image=busybox -n tournoi-app -- wget -q --timeout=5 -O- http://backend-service:8080/dernier-tournoi &>/dev/null
print_result $? "Connectivité interne frontend->backend autorisée"

# 5. TESTS SÉCURITÉ AVANCÉE
echo -e "\n${YELLOW}🛡️  5. TESTS SÉCURITÉ AVANCÉE${NC}"
echo "--------------------------------"

# Vérifier les secrets
kubectl get secret postgres-secret -n tournoi-app &>/dev/null
print_result $? "Secret postgres-secret existe"

# Vérifier que les pods utilisent des utilisateurs non-root
print_info "Vérification des utilisateurs non-root..."
backend_user=$(kubectl get pod -n tournoi-app -l app=backend -o jsonpath='{.items[0].spec.securityContext.runAsUser}' 2>/dev/null)
if [ "$backend_user" = "1000" ]; then
    print_result 0 "Backend s'exécute avec un utilisateur non-root (UID: $backend_user)"
else
    print_result 1 "Backend ne s'exécute pas avec l'utilisateur attendu (UID: $backend_user)"
fi

# Vérifier SecurityContext
backend_privileged=$(kubectl get pod -n tournoi-app -l app=backend -o jsonpath='{.items[0].spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
if [ "$backend_privileged" = "false" ]; then
    print_result 0 "Backend n'autorise pas l'escalade de privilèges"
else
    print_result 1 "Backend autorise l'escalade de privilèges (problème de sécurité)"
fi

# Vérifier readOnlyRootFilesystem
readonly_fs=$(kubectl get pod -n tournoi-app -l app=backend -o jsonpath='{.items[0].spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
if [ "$readonly_fs" = "true" ]; then
    print_result 0 "Backend utilise un système de fichiers racine en lecture seule"
else
    print_result 1 "Backend n'utilise pas un système de fichiers racine en lecture seule"
fi

# 6. TESTS FONCTIONNELS APPLICATION
echo -e "\n${YELLOW}🚀 6. TESTS FONCTIONNELS${NC}"
echo "-------------------------"

# Attendre que l'ingress soit prêt
sleep 5

# Test de l'API backend
print_info "Test de l'API backend..."
kubectl port-forward service/backend-service 8080:8080 -n tournoi-app &
PORT_FORWARD_PID=$!
sleep 3

curl -s http://localhost:8080/dernier-tournoi &>/dev/null
api_result=$?
kill $PORT_FORWARD_PID &>/dev/null
print_result $api_result "API backend répond sur /dernier-tournoi"

# Test du frontend
print_info "Test du frontend..."
kubectl port-forward service/frontend-service 5000:5000 -n tournoi-app &
PORT_FORWARD_PID=$!
sleep 3

curl -s http://localhost:5000 | grep -q "html\|HTML" &>/dev/null
frontend_result=$?
kill $PORT_FORWARD_PID &>/dev/null
print_result $frontend_result "Frontend serve du contenu HTML"

# 7. TESTS DE PERFORMANCE ET RESSOURCES
echo -e "\n${YELLOW}⚡ 7. TESTS RESSOURCES${NC}"
echo "-----------------------"

# Vérifier les limites de ressources
print_info "Vérification des limites de ressources..."
backend_memory_limit=$(kubectl get deployment backend-deployment -n tournoi-app -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
if [ "$backend_memory_limit" = "512Mi" ]; then
    print_result 0 "Limite mémoire backend configurée: $backend_memory_limit"
else
    print_result 1 "Limite mémoire backend incorrecte: $backend_memory_limit"
fi

# Vérifier l'utilisation des ressources
print_info "Vérification de l'utilisation des ressources..."
kubectl top pods -n tournoi-app --no-headers 2>/dev/null | while read line; do
    pod_name=$(echo $line | awk '{print $1}')
    cpu_usage=$(echo $line | awk '{print $2}')
    memory_usage=$(echo $line | awk '{print $3}')
    echo -e "${GREEN}📊 $pod_name: CPU=$cpu_usage, Memory=$memory_usage${NC}"
done

# 8. TESTS DE HAUTE DISPONIBILITÉ
echo -e "\n${YELLOW}🔄 8. TESTS HAUTE DISPONIBILITÉ${NC}"
echo "--------------------------------"

# Vérifier le nombre de répliques
backend_replicas=$(kubectl get deployment backend-deployment -n tournoi-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$backend_replicas" = "2" ]; then
    print_result 0 "Backend a $backend_replicas répliques (HA)"
else
    print_result 1 "Backend n'a que $backend_replicas réplique(s)"
fi

frontend_replicas=$(kubectl get deployment frontend-deployment -n tournoi-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$frontend_replicas" = "2" ]; then
    print_result 0 "Frontend a $frontend_replicas répliques (HA)"
else
    print_result 1 "Frontend n'a que $frontend_replicas réplique(s)"
fi

# Test de résistance aux pannes
print_info "Test de résistance aux pannes (suppression d'un pod backend)..."
backend_pod=$(kubectl get pods -n tournoi-app -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$backend_pod" ]; then
    kubectl delete pod $backend_pod -n tournoi-app &>/dev/null
    sleep 10
    kubectl wait --for=condition=ready --timeout=60s pod -l app=backend -n tournoi-app &>/dev/null
    print_result $? "Récupération automatique après suppression de pod"
fi

# 9. TESTS DE SÉCURITÉ RÉSEAU
echo -e "\n${YELLOW}🔐 9. TESTS SÉCURITÉ RÉSEAU${NC}"
echo "-----------------------------"

# Test HTTPS redirect (si configuré)
print_info "Vérification de la configuration Ingress sécurisée..."
ssl_redirect=$(kubectl get ingress tournoi-ingress-secure -n tournoi-app -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/force-ssl-redirect}' 2>/dev/null)
if [ "$ssl_redirect" = "true" ]; then
    print_result 0 "Redirection SSL forcée configurée"
else
    print_result 1 "Redirection SSL forcée non configurée"
fi

# Vérifier les headers de sécurité
security_headers=$(kubectl get ingress tournoi-ingress-secure -n tournoi-app -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/configuration-snippet}' 2>/dev/null)
if echo "$security_headers" | grep -q "X-Frame-Options"; then
    print_result 0 "Headers de sécurité configurés"
else
    print_result 1 "Headers de sécurité non configurés"
fi

# 10. RÉSUMÉ FINAL
echo -e "\n${BLUE}📋 RÉSUMÉ DES TESTS${NC}"
echo "==================="

print_info "Vérification finale de l'état du cluster..."
kubectl get all -n tournoi-app

echo -e "\n${GREEN}🎯 TESTS TERMINÉS !${NC}"
echo "Vérifiez les résultats ci-dessus pour identifier les éventuels problèmes."
echo ""
echo -e "${YELLOW}📝 COMMANDES UTILES POUR LE DEBUG:${NC}"
echo "- Logs backend: kubectl logs -l app=backend -n tournoi-app"
echo "- Logs frontend: kubectl logs -l app=frontend -n tournoi-app"  
echo "- Logs PostgreSQL: kubectl logs -l app=postgres -n tournoi-app"
echo "- Événements: kubectl get events -n tournoi-app --sort-by='.lastTimestamp'"
echo "- Description des pods: kubectl describe pods -n tournoi-app"