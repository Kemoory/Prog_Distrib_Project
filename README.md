# Prog_Distrib_Project

## Images Docker

Les images Docker sur Docker hub :
- https://hub.docker.com/r/kemoury/mkfrontend
- https://hub.docker.com/r/kemoury/mkbackend

## Application

```
Ingress NGINX
  ├── /frontend → frontend-service (Flask)
  └── /backend  → backend-service (Flask)

Services internes :
  ├── frontend (interface utilisateur)
  ├── backend (API + logique des données)
  └── postgres (base de données)
```
Le frontend fait des requêtes http au backend qui va ensuite récupérer les données dans la base pour ensuite les envoyer au frontend qui va les afficher.

