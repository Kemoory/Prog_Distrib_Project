# backend.py
from flask import Flask, jsonify, request, abort
import psycopg2
from config import db_config
from trueskill import Rating, rate
import numpy as np
import functools
from flask import request, abort

app = Flask(__name__)

# Création d'un jeton d'admin sécurisé pour les sessions (à définir dans config.py)
ADMIN_TOKEN = "b31c9b1c48c2490189b0f49c7f542a2e"  # À remplacer par un token dans config.py

def admin_required(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        token = request.headers.get('X-Admin-Token', None)
        if token != ADMIN_TOKEN:
            abort(403)  # Forbidden
        return f(*args, **kwargs)
    return decorated_function

def get_db_connection():
    return psycopg2.connect(**db_config)

@app.route('/dernier-tournoi')
def dernier_tournoi():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT id FROM Tournois ORDER BY date DESC LIMIT 1")
    dernier = cur.fetchone()

    if dernier:
        tournoi_id = dernier[0]
        cur.execute("""
            SELECT Joueurs.nom, Participations.score
            FROM Participations
            JOIN Joueurs ON Participations.joueur_id = Joueurs.id
            WHERE Participations.tournoi_id = %s
            ORDER BY Participations.score DESC
        """, (tournoi_id,))
        resultats = cur.fetchall()
    else:
        resultats = []

    cur.close()
    conn.close()

    return jsonify(resultats)

@app.route('/classement')
def classement():
    conn = get_db_connection()
    cur = conn.cursor()
    
    tier = request.args.get('tier', None)
    
    if tier in ['S', 'A', 'B', 'C']:
        # Filtrer par tier
        cur.execute("""
            SELECT nom, score_trueskill, tier
            FROM Joueurs
            WHERE tier = %s
            ORDER BY score_trueskill DESC
        """, (tier,))
    else:
        # Tous les joueurs
        cur.execute("""
            SELECT nom, score_trueskill, tier
            FROM Joueurs
            ORDER BY score_trueskill DESC, tier ASC
        """)
    
    joueurs = cur.fetchall()

    cur.close()
    conn.close()

    return jsonify(joueurs)

@app.route('/add-tournament', methods=['POST'])
@admin_required
def add_tournament():
    data = request.get_json()
    date = data.get('date')
    joueurs = data.get('joueurs', [])
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT id FROM Tournois WHERE date = %s", (date,))
    tournoi = cur.fetchone()

    if tournoi is None:
        cur.execute("INSERT INTO Tournois (date) VALUES (%s) RETURNING id", (date,))
        tournoi_id = cur.fetchone()[0]
    else:
        tournoi_id = tournoi[0]

    positions = {}
    player_ids = {}
    player_ratings = []

    for joueur in joueurs:
        nom = joueur['nom']
        score_brut = joueur['score']
        score = int(score_brut)
        # Récupérer ou créer le joueur
        cur.execute("SELECT id, mu, sigma FROM Joueurs WHERE nom = %s", (nom,))
        joueur_data = cur.fetchone()

        if joueur_data is None:
            cur.execute("INSERT INTO Joueurs (nom) VALUES (%s) RETURNING id", (nom,))
            joueur_id = cur.fetchone()[0]
            mu, sigma = 25.0, 8.333  # valeurs par défaut
        else:
            joueur_id, mu, sigma = joueur_data

        player_ids[nom] = joueur_id
        positions[nom] = -score  # TrueSkill veut rangs croissants, donc scores décroissants
        player_ratings.append((nom, Rating(mu=mu, sigma=sigma)))

        # Enregistrer la participation
        cur.execute(
            "INSERT INTO Participations (joueur_id, tournoi_id, score) VALUES (%s, %s, %s)",
            (joueur_id, tournoi_id, score)
        )

    # Trier les joueurs par score décroissant
    sorted_players = sorted(player_ratings, key=lambda x: positions[x[0]])
    rating_groups = [[r[1]] for r in sorted_players]
    ranks = list(range(len(sorted_players)))

    new_ratings = rate(rating_groups, ranks=ranks)

    # Mettre à jour les joueurs avec leurs nouveaux ratings
    for i, (nom, _) in enumerate(sorted_players):
        new_rating = new_ratings[i][0]
        joueur_id = player_ids[nom]
        cur.execute(
            "UPDATE Joueurs SET mu = %s, sigma = %s WHERE id = %s",
            (new_rating.mu, new_rating.sigma, joueur_id)
        )
    
    # Mise à jour des tiers après mise à jour des scores TrueSkill
    cur.execute("SELECT id, score_trueskill FROM Joueurs WHERE score_trueskill IS NOT NULL")
    joueurs = cur.fetchall()

    if joueurs:
        scores = [score for (_, score) in joueurs]
        q1 = np.percentile(scores, 25)
        q2 = np.percentile(scores, 50)
        q3 = np.percentile(scores, 75)

        for joueur_id, score in joueurs:
            if score >= q3:
                tier = 'S'
            elif score >= q2:
                tier = 'A'
            elif score >= q1:
                tier = 'B'
            else:
                tier = 'C'
            cur.execute("UPDATE Joueurs SET tier = %s WHERE id = %s", (tier, joueur_id))

    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"status": "success"})

@app.route('/admin-auth', methods=['POST'])
def admin_auth():
    data = request.get_json()
    password = data.get('password', '')
    
    # Vérifier un mot de passe administrateur (à définir dans config.py)
    if password == "admin_password":  # À remplacer par un mot de passe sécurisé
        return jsonify({"status": "success", "token": ADMIN_TOKEN})
    else:
        return jsonify({"status": "error", "message": "Mot de passe incorrect"}), 401

@app.route('/joueurs')
def liste_joueurs():
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("SELECT nom FROM Joueurs ORDER BY nom")
    joueurs = [j[0] for j in cur.fetchall()]
    
    cur.close()
    conn.close()
    
    return jsonify(joueurs)

@app.route('/stats/joueurs-avances')
def stats_joueurs_avances():
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Récupérer tous les joueurs avec leurs stats
    cur.execute("""
        SELECT 
            j.id, 
            j.nom, 
            j.score_trueskill, 
            j.tier,
            COUNT(p.tournoi_id) as nombre_tournois,
            AVG(p.score) as score_moyen,
            MAX(p.score) as meilleur_score,
            COUNT(CASE WHEN p.score = (
                SELECT MAX(score) FROM Participations WHERE tournoi_id = p.tournoi_id
            ) THEN 1 END) as victoires
        FROM 
            Joueurs j
        LEFT JOIN 
            Participations p ON j.id = p.joueur_id
        GROUP BY 
            j.id, j.nom, j.score_trueskill, j.tier
        ORDER BY 
            j.score_trueskill DESC NULLS LAST
    """)
    
    joueurs_data = cur.fetchall()
    
    # Calculer les statistiques globales pour les percentiles
    scores_trueskill = [j[2] for j in joueurs_data if j[2] is not None]
    scores_moyens = [j[5] for j in joueurs_data if j[5] is not None]
    
    joueurs = []
    for joueur in joueurs_data:
        joueur_id, nom, score_trueskill, tier, nb_tournois, score_moyen, meilleur_score, victoires = joueur
        
        # Calculer les percentiles pour ce joueur
        percentile_trueskill = 0
        if score_trueskill is not None and scores_trueskill:
            percentile_trueskill = sum(1 for s in scores_trueskill if s <= score_trueskill) / len(scores_trueskill) * 100
        
        percentile_score_moyen = 0
        if score_moyen is not None and scores_moyens:
            percentile_score_moyen = sum(1 for s in scores_moyens if s <= score_moyen) / len(scores_moyens) * 100
        
        # Calculer le ratio victoires/tournois
        ratio_victoires = 0
        if nb_tournois > 0:
            ratio_victoires = victoires / nb_tournois
            
        # Calculer la progression récente (derniers 3 tournois vs précédents)
        progression_recente = None
        if nb_tournois >= 3:
            cur.execute("""
                WITH TournoisJoueur AS (
                    SELECT 
                        p.tournoi_id, 
                        p.score, 
                        t.date,
                        ROW_NUMBER() OVER (ORDER BY t.date DESC) as rang
                    FROM 
                        Participations p
                    JOIN 
                        Tournois t ON p.tournoi_id = t.id
                    WHERE 
                        p.joueur_id = %s
                    ORDER BY 
                        t.date DESC
                )
                SELECT 
                    AVG(CASE WHEN rang <= 3 THEN score ELSE NULL END) as score_recent,
                    AVG(CASE WHEN rang > 3 THEN score ELSE NULL END) as score_ancien
                FROM 
                    TournoisJoueur
            """, (joueur_id,))
            
            score_data = cur.fetchone()
            if score_data[0] is not None and score_data[1] is not None:
                progression_recente = float(score_data[0] - score_data[1])
        
        joueurs.append({
            "nom": nom,
            "score_trueskill": float(score_trueskill) if score_trueskill else 0,
            "tier": tier,
            "nombre_tournois": nb_tournois,
            "score_moyen": float(score_moyen) if score_moyen else 0,
            "meilleur_score": meilleur_score if meilleur_score else 0,
            "victoires": victoires,
            "percentile_trueskill": round(percentile_trueskill, 1),
            "percentile_score_moyen": round(percentile_score_moyen, 1),
            "ratio_victoires": round(ratio_victoires * 100, 1),
            "progression_recente": round(progression_recente, 1) if progression_recente is not None else 0,
        })
    
    cur.close()
    conn.close()
    
    return jsonify(joueurs)


@app.route('/stats/joueur/<nom>')
def stats_joueur(nom):
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Récupérer l'ID du joueur
    cur.execute("SELECT id FROM Joueurs WHERE nom = %s", (nom,))
    joueur_id_result = cur.fetchone()
    
    if not joueur_id_result:
        return jsonify({"error": "Joueur non trouvé"}), 404
        
    joueur_id = joueur_id_result[0]
    
    # Statistiques générales
    cur.execute("""
        SELECT 
            COUNT(p.tournoi_id) as nombre_tournois,
            COALESCE(AVG(p.score), 0) as score_moyen,
            COALESCE(MAX(p.score), 0) as meilleur_score,
            COUNT(CASE WHEN p.score = (
                SELECT MAX(score) FROM Participations WHERE tournoi_id = p.tournoi_id
            ) THEN 1 END) as victoires,
            COALESCE(j.score_trueskill, 0) as score_trueskill,
            COALESCE(j.tier, 'N/A') as tier,
            COALESCE(STDDEV(p.score), 0) as ecart_type_scores
        FROM 
            Joueurs j
        LEFT JOIN 
            Participations p ON p.joueur_id = j.id
        WHERE 
            j.id = %s
        GROUP BY 
            j.score_trueskill, j.tier
    """, (joueur_id,))
    
    stats_result = cur.fetchone()
    
    if not stats_result:
        stats = {
            "nombre_tournois": 0,
            "score_moyen": 0,
            "meilleur_score": 0,
            "victoires": 0,
            "score_trueskill": 0,
            "tier": "N/A",
            "ecart_type_scores": 0
        }
    else:
        stats = {
            "nombre_tournois": stats_result[0],
            "score_moyen": float(stats_result[1]) if stats_result[1] else 0,
            "meilleur_score": stats_result[2] if stats_result[2] else 0,
            "victoires": stats_result[3] if stats_result[3] else 0,
            "score_trueskill": float(stats_result[4]) if stats_result[4] else 0,
            "tier": stats_result[5],
            "ecart_type_scores": float(stats_result[6]) if stats_result[6] else 0
        }
    
    # Calculer la progression récente (derniers 3 tournois vs précédents)
    if stats["nombre_tournois"] >= 3:
        cur.execute("""
            WITH TournoisJoueur AS (
                SELECT 
                    p.tournoi_id, 
                    p.score, 
                    t.date,
                    ROW_NUMBER() OVER (ORDER BY t.date DESC) as rang
                FROM 
                    Participations p
                JOIN 
                    Tournois t ON p.tournoi_id = t.id
                WHERE 
                    p.joueur_id = %s
                ORDER BY 
                    t.date DESC
            )
            SELECT 
                COALESCE(AVG(CASE WHEN rang <= 3 THEN score ELSE NULL END), 0) as score_recent,
                COALESCE(AVG(CASE WHEN rang > 3 THEN score ELSE NULL END), 0) as score_ancien
            FROM 
                TournoisJoueur
        """, (joueur_id,))
        
        score_data = cur.fetchone()
        if score_data[0] and score_data[1]:
            stats["progression_recente"] = float(score_data[0] - score_data[1])
        else:
            stats["progression_recente"] = 0
    else:
        stats["progression_recente"] = 0
    
    # Historique des tournois
    cur.execute("""
        SELECT 
            t.date, 
            p.score,
            (SELECT COUNT(*) + 1 FROM Participations p2 
             WHERE p2.tournoi_id = p.tournoi_id AND p2.score > p.score) as position
        FROM 
            Participations p
        JOIN 
            Tournois t ON p.tournoi_id = t.id
        WHERE 
            p.joueur_id = %s
        ORDER BY 
            t.date DESC
    """, (joueur_id,))
    
    historique = []
    positions = []
    for date, score, position in cur.fetchall():
        historique.append({
            "date": date.strftime('%Y-%m-%d'),
            "score": score,
            "position": position
        })
        positions.append(position)
    
    # Calculer la position moyenne
    if positions:
        stats["position_moyenne"] = float(sum(positions) / len(positions))
    else:
        stats["position_moyenne"] = 0
    
    cur.close()
    conn.close()
    
    return jsonify({"stats": stats, "historique": historique})

@app.route('/stats/tournois')
def stats_tournois():
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Liste des tournois avec le vainqueur (joueur avec le score max)
    cur.execute("""
        SELECT 
            t.id, 
            t.date, 
            COUNT(p.joueur_id) as nb_joueurs,
            MAX(p.score) as score_max,
            (SELECT j.nom FROM Joueurs j 
             JOIN Participations p2 ON j.id = p2.joueur_id 
             WHERE p2.tournoi_id = t.id 
             ORDER BY p2.score DESC LIMIT 1) as vainqueur
        FROM 
            Tournois t
        LEFT JOIN 
            Participations p ON t.id = p.tournoi_id
        GROUP BY 
            t.id, t.date
        ORDER BY 
            t.date DESC
    """)
    
    tournois = []
    for id, date, nb_joueurs, score_max, vainqueur in cur.fetchall():
        tournois.append({
            "id": id,
            "date": date.strftime('%Y-%m-%d'),
            "nb_joueurs": nb_joueurs,
            "score_max": score_max,
            "vainqueur": vainqueur if vainqueur else "Inconnu"
        })
    
    cur.close()
    conn.close()
    
    return jsonify(tournois)

@app.route('/stats/tournoi/<int:tournoi_id>')
def stats_tournoi(tournoi_id):
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Info du tournoi
    cur.execute("SELECT date FROM Tournois WHERE id = %s", (tournoi_id,))
    tournoi_result = cur.fetchone()
    
    if not tournoi_result:
        return jsonify({"error": "Tournoi non trouvé"}), 404
    
    date = tournoi_result[0].strftime('%Y-%m-%d')
    
    # Résultats du tournoi
    cur.execute("""
        SELECT 
            j.nom, 
            p.score,
            j.tier
        FROM 
            Participations p
        JOIN 
            Joueurs j ON p.joueur_id = j.id
        WHERE 
            p.tournoi_id = %s
        ORDER BY 
            p.score DESC
    """, (tournoi_id,))
    
    resultats = []
    for nom, score, tier in cur.fetchall():
        resultats.append({
            "nom": nom,
            "score": score,
            "tier": tier
        })
    
    cur.close()
    conn.close()
    
    return jsonify({"date": date, "resultats": resultats})

@app.route('/stats/tendances')
def stats_tendances():
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Joueurs les plus améliorés (par rapport à leur premier score TrueSkill)
    cur.execute("""
        WITH JoueurEvolution AS (
            SELECT 
                j.id,
                j.nom,
                j.score_trueskill - 25.0 as progression,
                j.tier
            FROM 
                Joueurs j
            WHERE 
                j.score_trueskill IS NOT NULL
        )
        SELECT 
            nom, 
            progression,
            tier
        FROM 
            JoueurEvolution
        ORDER BY 
            progression DESC
        LIMIT 10
    """)
    
    progressions = []
    for nom, progression, tier in cur.fetchall():
        progressions.append({
            "nom": nom,
            "progression": float(progression),
            "tier": tier
        })
    
    # Distribution des tiers
    cur.execute("""
        SELECT 
            tier, 
            COUNT(*) as nombre
        FROM 
            Joueurs
        WHERE 
            tier IS NOT NULL
        GROUP BY 
            tier
        ORDER BY 
            CASE 
                WHEN tier = 'S' THEN 1
                WHEN tier = 'A' THEN 2
                WHEN tier = 'B' THEN 3
                WHEN tier = 'C' THEN 4
                ELSE 5
            END
    """)
    
    distribution_tiers = {}
    for tier, nombre in cur.fetchall():
        distribution_tiers[tier] = nombre
    
    cur.close()
    conn.close()
    
    return jsonify({
        "progressions": progressions,
        "distribution_tiers": distribution_tiers
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)