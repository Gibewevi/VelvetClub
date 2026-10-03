# Construction V90 — Bilan financier

Exécutable : `Construction-V90-Bilan.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Les comptes du club

Le club tient maintenant ses comptes jour par jour. Tout l'argent qui entre ou qui sort est classé. Les comptes sont enregistrés avec la partie et commencent au premier lancement de cette version.

**Recettes**

- Entrées.
- Boissons et alcools.
- Spectacle sur scène.
- Prestations en chambre.
- Pourboires des prestations.
- Pourboires sur scène.
- Pourboires sur la piste.
- Reventes et remboursements : un meuble revendu, un achat annulé.

**Dépenses**

- Salaires, détaillés par poste : réceptionniste, escorts par standing, femme de ménage, barman, technicien…
- Annonces de recrutement.
- Travaux : pièces, cloisons, finitions.
- Mobilier et équipements, avec les améliorations sanitaires.
- Parkings.

## Où le voir

- **Personnel → Gestion** : une ligne « FINANCES » résume la journée (recettes, dépenses, résultat), avec le bouton **Bilan financier**.
- **Rapports** : le même bouton en haut.

## La fenêtre Bilan financier

- **Période** : Aujourd'hui, Hier, 7 jours, 30 jours ou Depuis le début.
- **À gauche** : toutes les recettes, puis toutes les dépenses ligne par ligne, avec les salaires par poste, du plus coûteux au moins coûteux. Chaque bloc a son total.
- **À droite** :
  - le résultat (recettes − dépenses) en grand, en vert ou en rouge ;
  - la marge en pourcentage des recettes ;
  - la trésorerie actuelle ;
  - un graphique jour par jour des recettes (vert) et des dépenses (rose), sur deux semaines au plus.
- Les travaux et achats comptent le jour de la commande. Les salaires courent à l'heure, club ouvert ou fermé.

## Vérifié

- Nouveau test des comptes (17 contrôles) :
  - journées, périodes, salaires par poste ;
  - travaux et achats par type, reventes ;
  - conservation de 60 jours, sauvegarde ;
  - sauvegarde abîmée ;
  - branchement sur le club : entrées, boissons, scène, salaires, annonces.
- Test de scène : le résumé dans Gestion, le bouton, la fenêtre avec ses sections, les salaires par poste, le changement de période.
- Rejoué sur une copie de votre partie, environ cinq heures de jeu : 6 006 $ de recettes, 739 $ de salaires, +5 267 $ de résultat.
- Toutes les suites passent.

## Aperçu (`Apercus-V90/`)

- `bilan-financier.png` : le bilan de la journée sur votre partie rejouée.
