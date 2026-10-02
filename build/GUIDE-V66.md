# Construction V66 — Vestiaire

Exécutable : `Construction-V66-Vestiaire.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Le vestiaire

Jusqu'ici, le portant à vêtements et les casiers étaient du simple décor : le portant était toujours plein, les casiers toujours vides. Ils servent maintenant pour de vrai.

- **Les manteaux** : environ 4 clients sur 10 arrivent avec un manteau, 3 sur 4 quand il pleut.
  - Après avoir payé à l'accueil, le client va le déposer au portant ou aux casiers qui ont encore de la place, en commençant par les plus proches.
  - En partant, il passe le reprendre avant de sortir.
- **Remplissage progressif** :
  - **Portant à vêtements** (180 $) : 12 manteaux. Les cintres se garnissent peu à peu, jusqu'à 7 manteaux visibles quand il est plein.
  - **Casiers vestiaire** (420 $) : 30 manteaux, plus du double pour une place au sol plus petite. Les portes occupées perdent leur clé et prennent une étiquette rouge.
  - Comme tous les clients n'ont pas de manteau, un portant suffit pour une trentaine de clients et des casiers pour plus de 70. Inutile d'en multiplier.
- **Vestiaire plein ou absent** : le client garde son manteau et il est un peu moins satisfait (−4). Un conseil le signale, sans insister : au plus une fois toutes les quatre heures de jeu.
- **Informations** :
  - en sélectionnant un portant ou des casiers, on lit « Vestiaire : 5 / 12 manteaux », mis à jour en direct ;
  - dans le Mobilier, l'infobulle indique la capacité de chaque modèle.

## Bug corrigé : agrandissement instantané

Tirer la poignée d'une pièce terminée l'agrandissait d'un coup, sans chantier.

- Désormais, tirer une poignée **vers l'extérieur** suit le même processus que tracer depuis un mur :
  - pendant le geste, la surface ajoutée s'affiche en vert avec son prix et la mention « chantier » ;
  - à la validation, un **chantier d'extension** s'ouvre : balisage, trois ouvriers, dalle, murs, peinture, sol ;
  - à la fin des travaux, le mur entre les deux tombe et la surface rejoint la pièce.
- Tirer une poignée **vers l'intérieur** réduit toujours la pièce immédiatement, avec remboursement.
- Une pièce **encore en chantier** s'agrandit toujours directement : ses nouvelles cases rejoignent les travaux en cours.

## Vérifié par les tests

- **Nouveau test du vestiaire** (21 contrôles) :
  - part des clients avec manteau, plus grande sous la pluie ;
  - dépôt au plus proche, place gardée pendant le trajet, manteau accroché ;
  - un portant plein de 12 manteaux, puis les casiers qui prennent le relais jusqu'à 30 ;
  - vestiaire plein ou absent, avec une seule contrariété ;
  - reprise du manteau au départ, crochet libéré même si le client est renvoyé ;
  - affichage du remplissage.
- **Scène** : tirer la poignée d'une pièce terminée ouvre un chantier d'extension avec ses ouvriers, puis la surface rejoint la pièce.
- Toutes les autres suites passent toujours : modèle, art, nuit simulée, interface en vraie fenêtre…

## Aperçus (`Apercus-V66/`)

- `vestiaire.png` : un portant plein, un portant à moitié rempli et des casiers en partie occupés.
- `remplissage.png` : le portant de vide à plein, les casiers de libres à tous occupés.
