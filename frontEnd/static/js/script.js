/* static/js/scripts.js */
let joueurCount = 1;

function ajouterJoueur() {
    if (joueurCount >= 12) {
        alert("Vous ne pouvez pas ajouter plus de 12 joueurs.");
        return;
    }
    joueurCount++;
    const joueursContainer = document.getElementById('joueursContainer');
    const newJoueurDiv = document.createElement('div');
    newJoueurDiv.className = 'box joueur';
    newJoueurDiv.innerHTML = `
        <div class="field">
            <label class="label" for="nom${joueurCount}">Nom du joueur ${joueurCount}:</label>
            <div class="control has-icons-left">
                <input type="text" id="nom${joueurCount}" name="nom${joueurCount}" class="input" required>
                <span class="icon is-small is-left">
                    <i class="fas fa-user"></i>
                </span>
            </div>
        </div>
        <div class="field">
            <label class="label" for="score${joueurCount}">Score du joueur ${joueurCount}:</label>
            <div class="control has-icons-left">
                <input type="number" id="score${joueurCount}" name="score${joueurCount}" class="input" required>
                <span class="icon is-small is-left">
                    <i class="fas fa-star"></i>
                </span>
            </div>
        </div>
        <button type="button" class="button is-danger is-small remove-joueur" onclick="supprimerJoueur(this)">
            <span class="icon">
                <i class="fas fa-trash"></i>
            </span>
            <span>Supprimer</span>
        </button>    `;
    joueursContainer.appendChild(newJoueurDiv);
}

function supprimerJoueur(button) {
    const joueurDiv = button.parentElement;
    joueurDiv.remove();
    joueurCount--;
    renumeroterJoueurs();
}

function renumeroterJoueurs() {
    const joueursContainer = document.getElementById('joueursContainer');
    const joueurs = joueursContainer.getElementsByClassName('joueur');
    for (let i = 0; i < joueurs.length; i++) {
        const joueur = joueurs[i];
        joueur.querySelector('label[for^="nom"]').setAttribute('for', `nom${i + 1}`);
        joueur.querySelector('label[for^="nom"]').textContent = `Nom du joueur ${i + 1}:`;
        joueur.querySelector('input[id^="nom"]').setAttribute('id', `nom${i + 1}`);
        joueur.querySelector('input[id^="nom"]').setAttribute('name', `nom${i + 1}`);

        joueur.querySelector('label[for^="score"]').setAttribute('for', `score${i + 1}`);
        joueur.querySelector('label[for^="score"]').textContent = `Score du joueur ${i + 1}:`;
        joueur.querySelector('input[id^="score"]').setAttribute('id', `score${i + 1}`);
        joueur.querySelector('input[id^="score"]').setAttribute('name', `score${i + 1}`);
    }
}

