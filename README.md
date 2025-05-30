# Prog_Distrib_Project

## Images Docker

Les images Docker sur Docker hub :
- https://hub.docker.com/r/kemoury/tournoi-frontend
- https://hub.docker.com/r/kemoury/tournoi-backend

Construire les images : 

```
# Backend
docker build -t your-dockerhub-username/tournoi-backend:latest -f backEnd/Dockerfile.backend .
docker push your-dockerhub-username/tournoi-backend:latest

# Frontend
docker build -t your-dockerhub-username/tournoi-frontend:latest -f frontEnd/Dockerfile.frontend .
docker push your-dockerhub-username/tournoi-frontend:latest
```

## Déploiement
```
minikube start
minikube addons enable ingress

chmod +x deploy.sh
./deploy.sh

minikube ip

echo "<ip minikube> tournoi.local" | sudo tee -a /etc/hosts
```

## Vérification du déploiement

```
# Vérifier les pods
kubectl get pods -n tournoi-app

# Vérifier les services
kubectl get services -n tournoi-app

# Vérifier l'Ingress
kubectl get ingress -n tournoi-app

# Logs du backend
kubectl logs -f deployment/backend-deployment -n tournoi-app

# Logs du frontend
kubectl logs -f deployment/frontend-deployment -n tournoi-app
```


## Test

http://tournoi.local

Pour voir à quoi ressemble le site veuillez télécharger la vidéo : presentation_site.mp4