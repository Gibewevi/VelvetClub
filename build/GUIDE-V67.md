# Construction V67 — Cloisons et recrutement

Exécutable : `Construction-V67-Cloisons-Recrutement.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Les cloisons

On peut maintenant monter des murs à l'intérieur d'une pièce existante.

- **Outil** : Construire › **Cloison**, ou la touche **C**.
- **Tracé** :
  - glissez le long du quadrillage, à l'intérieur d'une pièce ;
  - la cloison part du point de grille le plus proche et reste droite, dans le sens où la souris va le plus ;
  - pendant le geste, la ligne s'affiche en vert (ou en rouge, avec la raison) avec sa longueur et son prix.
- **Prix** : 60 $ le mètre. L'outil reste actif pour enchaîner les cloisons.
- **Comme un vrai mur** :
  - personne ne la traverse ;
  - on peut y placer une porte (P) ou une fenêtre (F) ;
  - si la cloison ferme un espace sans porte, un message le signale.
- **Mobilier** :
  - aucun meuble ne peut être posé à cheval sur une cloison ;
  - on ne monte pas une cloison à travers un meuble : il faut d'abord le déplacer.
- **La pièce reste la même** : même type, mêmes revêtements. La cloison prend la couleur de ses murs.
- **Hauteur** :
  - dans un espace public, la cloison reste basse, comme les murs entre deux espaces publics, pour garder la vue sur la salle ;
  - dans les autres pièces, elle est pleine hauteur (W pour couper les murs).
- **Démolir** :
  - cliquez la cloison pour la sélectionner : le panneau indique « Cloison · 4 m » et sa valeur ;
  - « Démolir la cloison » l'enlève en entier, ses portes avec, et la rembourse ;
  - Ctrl + Z la remet.
- Réduire une pièce retire les cloisons qui se retrouvent dehors.
- La cloison est montée tout de suite, sans chantier. Si vous préférez que les ouvriers la construisent, dites-le-moi.

## Personnel : l'équipe d'un côté, les candidats de l'autre

Le tiroir Personnel a maintenant deux onglets.

- **Équipe (N)** :
  - l'heure et le total des salaires en cours, et le bouton « Horaires du club » ;
  - une carte par employé : portrait, nom, poste, ce qu'il fait en ce moment, son salaire, ses deux compétences ;
  - sur chaque carte, « Fiche » et « Planning ». Cliquer la carte sélectionne l'employé dans le club.
- **Recrutement** :
  - une rangée de portraits, un par poste ; l'infobulle donne le rôle, le salaire moyen et les étoiles demandées ;
  - en dessous, les trois candidats du jour pour le poste choisi.

## Le recrutement : trois candidats par poste

- **Chaque jour de jeu**, trois candidats se présentent pour chaque poste. Ils ont toujours trois profils différents, parmi : Débutant, Rapide mais brouillon, Lent mais soigné, Solide, Expérimenté.
- **Deux compétences**, notées de 1 à 5 carrés (3 carrés = un employé ordinaire) :
  - la **rapidité** (l'**énergie** pour les escorts) ;
  - la **qualité**, nommée selon le poste : Accueil, Service, Soin ou Charme.
- **Le salaire** suit le niveau, d'environ 0,6 à 1,5 fois le salaire moyen du poste, avec un écart de quelques dollars :
  - « **Bonne affaire** » en vert quand le candidat demande moins que son niveau ;
  - « **Exigeant** » en rouge quand il demande plus.
- **Embaucher** :
  - « Embaucher », puis cliquez dans une pièce pour son poste ;
  - un candidat, une personne : pas de série avec Maj, pas de copie avec Ctrl + D ;
  - il garde son nom et son âge dans sa fiche ;
  - sa carte affiche « Déjà embauché ». Annuler l'embauche (Ctrl + Z) le remet sur la liste ; renvoyé le jour même, il ne se représente pas.
- **Passer une annonce** (100 $) : trois nouveaux candidats pour chaque poste, tout de suite.
- **Le personnel déjà embauché** avant cette version travaille comme avant : 3 carrés partout et son salaire habituel.

### Ce que changent les compétences

| Poste | Rapidité | Qualité |
| --- | --- | --- |
| Réceptionniste | encaisse plus vite, la file avance | satisfaction à l'arrivée, de −2,5 à +3 |
| Barman | sert plus souvent une deuxième tournée (30 % à 52 % des commandes, 40 % pour un barman ordinaire) | satisfaction au bar, de −2,5 à +3 |
| Technicien d'entretien, femme de ménage | nettoie et répare plus vite | un employé brouillon laisse jusqu'à 30 % de saleté, donc les sanitaires sont à refaire plus tôt ; un employé soigneux les laisse propres plus longtemps (ils se salissent jusqu'à 30 % moins vite) |
| Escorts | va plus vite vers les clients, en cherche plus souvent | plaisir des clients en sa compagnie, chances d'accord pour un rendez-vous, pourboires |

- Un employé rapide marche aussi un peu plus vite.
- Chaque employé est payé son propre salaire.

## Menu

L'option « Importer le bâtiment 3D » est retirée.

## Vérifié par les tests

- **Nouveau test du recrutement** (26 contrôles) :
  - trois candidats aux profils différents, les mêmes après un rechargement, nouveaux le lendemain ou après une annonce ;
  - salaires qui suivent les compétences, le meilleur candidat presque toujours plus cher ;
  - escorts habillées selon leur standing, personnel en uniforme mais chacun avec son visage ;
  - nom, âge, salaire et vitesse de marche gardés à l'embauche ;
  - effets au bar, salaires de chacun, sanitaires soignés ;
  - sauvegarde, et refus des données abîmées.
- **Modèle** : 22 contrôles sur les cloisons :
  - tracé, prix, refus sur les murs de la pièce, dehors ou sur un chantier ;
  - passage bloqué sans porte, chemin par la porte ;
  - mobilier, sauvegarde, démolition remboursée, pièce réduite.
- **Scène** :
  - l'outil Cloison à la souris : mur dessiné, payé, fermé, puis ouvert par une porte, sélectionné, démoli et rétabli ;
  - l'embauche depuis l'onglet Recrutement : le bon candidat placé, sa carte « Déjà embauché », pas de copie, l'onglet Équipe à jour, l'annulation.
- Toutes les autres suites passent toujours : nuit simulée, interface en vraie fenêtre, vestiaire, livraisons…

## Aperçus (`Apercus-V67/`)

- `cloisons.png` : un salon divisé en trois coins par deux cloisons, une porte dans chacune, une cloison sélectionnée.
- `equipe.png` : l'onglet Équipe avec trois employés recrutés.
- `recrutement.png` : l'onglet Recrutement, les candidats barman du jour, dont un déjà embauché.
