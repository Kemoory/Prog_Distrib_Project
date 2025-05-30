# frontend.py
from flask import Flask, render_template, request, redirect, url_for, session, flash
import numpy as np
import requests
import os

app = Flask(__name__)
app.secret_key = os.urandom(24)  # Pour les sessions
BACKEND_URL = os.environ.get('BACKEND_URL', 'http://127.0.0.1:8080') #Get the backend URL from environment variable, default to localhost for local development

@app.route('/')
def index():
    response = requests.get(f"{BACKEND_URL}/dernier-tournoi")
    resultats = response.json()
    return render_template("index.html", resultats=resultats)

@app.route('/classement')
def classement():
    tier = request.args.get('tier', None)
    
    if tier:
        response = requests.get(f"{BACKEND_URL}/classement", params={'tier': tier})
    else:
        response = requests.get(f"{BACKEND_URL}/classement")
        
    joueurs = response.json()
    return render_template("classement.html", joueurs=joueurs, tier_actif=tier)

@app.route('/admin', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        password = request.form.get('password')
        
        # Appel à l'API pour vérifier le mot de passe admin
        response = requests.post(f"{BACKEND_URL}/admin-auth", json={'password': password})
        
        if response.status_code == 200:
            data = response.json()
            session['admin_token'] = data['token']
            return redirect(url_for('add_tournament'))
        else:
            flash('Mot de passe incorrect', 'danger')
    
    # Vérifier si déjà connecté
    if 'admin_token' in session:
        return redirect(url_for('add_tournament'))
    
    return render_template("admin_login.html")

@app.route('/admin/logout')
def admin_logout():
    session.pop('admin_token', None)
    flash('Vous avez été déconnecté', 'info')
    return redirect(url_for('index'))

@app.route('/add_tournament', methods=['GET', 'POST'])
def add_tournament():
    # Vérifier si l'utilisateur est un admin
    if 'admin_token' not in session:
        flash('Accès réservé aux administrateurs', 'danger')
        return redirect(url_for('admin_login'))
    
    # Récupérer la liste des joueurs existants pour l'autocomplétion
    joueurs_response = requests.get(f"{BACKEND_URL}/joueurs")
    joueurs = joueurs_response.json()
    
    if request.method == 'POST':
        date = request.form['date']
        joueurs_liste = []

        for i in range(1, 13):
            nom = request.form.get(f'nom{i}')
            score = request.form.get(f'score{i}')
            if nom and score:
                joueurs_liste.append({'nom': nom, 'score': score})

        payload = {'date': date, 'joueurs': joueurs_liste}
        
        # Inclure le token admin dans les headers
        headers = {'X-Admin-Token': session['admin_token']}
        response = requests.post(f"{BACKEND_URL}/add-tournament", json=payload, headers=headers)
        
        if response.status_code == 200:
            return redirect(url_for('confirmation'))
        else:
            flash('Erreur lors de l\'ajout du tournoi', 'danger')

    return render_template("add_tournament.html", joueurs=joueurs)

@app.route('/confirmation')
def confirmation():
    return render_template("confirmation.html")

@app.route('/stats/joueurs')
def stats_joueurs():
    # Récupérer la liste des joueurs avec leurs stats avancées
    response = requests.get(f"{BACKEND_URL}/stats/joueurs-avances")
    joueurs = response.json()
    
    # Récupérer les distributions des tiers pour le contexte global
    tiers_response = requests.get(f"{BACKEND_URL}/stats/tendances")
    distribution_tiers = tiers_response.json().get('distribution_tiers', {})
    
    return render_template("stats_joueurs.html", joueurs=joueurs, distribution_tiers=distribution_tiers)

@app.route('/stats/joueur/<nom>')
def stats_joueur(nom):
    # Récupérer les stats du joueur
    response = requests.get(f"{BACKEND_URL}/stats/joueur/{nom}")
    
    if response.status_code == 404:
        flash('Joueur non trouvé', 'danger')
        return redirect(url_for('stats_joueurs'))
        
    data = response.json()
    
    # Récupérer les stats avancées pour les valeurs manquantes
    avance_response = requests.get(f"{BACKEND_URL}/stats/joueurs-avances")
    joueurs_avances = avance_response.json()
    
    # Trouver le joueur dans la liste des joueurs avancés
    joueur_avance = next((j for j in joueurs_avances if j['nom'] == nom), None)
    
    # Compléter les stats manquantes à partir de joueur_avance
    stats = data['stats']
    if joueur_avance:
        stats['percentile_trueskill'] = joueur_avance['percentile_trueskill']
        stats['progression_recente'] = joueur_avance['progression_recente']
        
        # Calculer l'écart-type à partir des scores de l'historique
        scores = [tournoi['score'] for tournoi in data['historique']]
        if scores:
            stats['ecart_type_scores'] = float(np.std(scores))
        else:
            stats['ecart_type_scores'] = 0
            
        # Calculer la position moyenne
        positions = [tournoi['position'] for tournoi in data['historique']]
        if positions:
            stats['position_moyenne'] = float(sum(positions) / len(positions))
        else:
            stats['position_moyenne'] = 0
        
    return render_template("stats_joueur.html", 
                          nom=nom, 
                          stats=stats, 
                          historique=data['historique'],
                          percentile_trueskill=stats.get('percentile_trueskill', 0))

@app.route('/stats/tournois')
def stats_tournois():
    # Récupérer la liste des tournois
    response = requests.get(f"{BACKEND_URL}/stats/tournois")
    tournois = response.json()
    
    # Adapter les données au format attendu par le template
    for tournoi in tournois:
        # Renommer nb_joueurs en participants pour correspondre au template
        tournoi['participants'] = tournoi.pop('nb_joueurs') if 'nb_joueurs' in tournoi else 0
        # S'assurer que vainqueur existe
        if 'vainqueur' not in tournoi:
            tournoi['vainqueur'] = "Inconnu"
    
    return render_template("stats_tournois.html", tournois=tournois)

@app.route('/stats/tournoi/<int:tournoi_id>')
def stats_tournoi(tournoi_id):
    # Récupérer les infos du tournoi
    response = requests.get(f"{BACKEND_URL}/stats/tournoi/{tournoi_id}")
    
    if response.status_code == 404:
        flash('Tournoi non trouvé', 'danger')
        return redirect(url_for('stats_tournois'))
        
    data = response.json()
    
    return render_template("stats_tournoi.html", date=data['date'], resultats=data['resultats'])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)