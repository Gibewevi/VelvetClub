# Construction V86 — Pièces

Exécutable : `Construction-V86-Pieces.exe`. Il utilise la même sauvegarde que les versions précédentes. Il contient aussi les saisons de la V85.

## Chaque meuble dans sa pièce

- Les meubles se posent dans le type de pièce qui leur correspond : pas de comptoir d'accueil dans les toilettes, pas de WC à la réception, pas de lit dans un salon meublé.
- Au survol, le fantôme passe en rouge et une bulle dit où va l'objet, par exemple « WC : à placer dans Toilettes, pas dans Espace public ».
- Certains objets vont dans plusieurs pièces :

  | Objet | Pièces |
  |---|---|
  | Fauteuil, vieille lampe | salon, chambre, personnel, réception |
  | Armoire | chambre, personnel, réception |
  | Canapés, tables | salon, personnel, réception |
  | Douche | chambre ou toilettes |
  | Réfrigérateur | salon, réserve, personnel |
  | Cordon velours | salon ou réception |

- La décoration, les lumières, les plantes et le personnel vont partout.
- Changer le type d'une pièce à la main est refusé si un meuble n'y a plus sa place : déplacez-le d'abord.
- Une partie déjà commencée se charge toujours, même avec des meubles mal placés.

## Une pièce vide prend le type de son premier meuble

- Dans une pièce neuve ou sans meuble, le premier objet posé décide du type. Un WC posé dans une pièce vide en fait des toilettes.
- Les plantes, la décoration et le personnel ne comptent pas.
- Au survol : « La pièce deviendra : Toilettes ». Après le clic : « La pièce devient : Toilettes ».
- Cela marche aussi en déplaçant un objet.

## Le prix des travaux sur le plan

- En traçant une pièce, une étiquette s'affiche au milieu de la zone : ses dimensions et sa surface, puis le prix en gros, en or, ou en rouge si l'argent manque.
- Pour un redimensionnement, l'étiquette affiche le supplément ou la somme rendue. Pour un agrandissement, la surface ajoutée et son prix.
- Avant de glisser, la bulle donne le prix approximatif du m², finitions comprises.

## Couper une pièce en deux avec une cloison

- Une cloison qui ferme entièrement une partie d'une pièce, seule ou avec d'autres cloisons, en fait une nouvelle pièce.
  - Elle garde le même type et les mêmes finitions.
  - La cloison devient le mur entre les deux pièces.
- Cliquez la nouvelle pièce pour changer son type, comme n'importe quelle pièce.
- Une porte posée sur ce mur relie les deux pièces.
- Fermer un coin donne une petite pièce, et le reste devient une pièce en L.
- Le prix est celui de la cloison (60 $ le mètre), sans supplément.
- Une cloison qui s'arrête avant le mur ne coupe rien : la pièce reste entière.

## Des priorités pour le personnel

- En sélectionnant un employé, une section **PRIORITÉ** permet de choisir ce qu'il fait en premier :
  - **femme de ménage** et employé polyvalent : Sanitaires, Lits, Poubelles, Sols mouillés, Déchets au sol ;
  - **technicien** : Réparations, Sanitaires, Sols mouillés, Déchets au sol.
- Dès qu'il est libre, l'employé fait d'abord ce travail, puis reprend l'ordre habituel.
  - Exemple : avec « Sanitaires », l'eau par terre dans les toilettes, puis les WC, lavabos et douches sales passent avant tout le reste.
- La priorité est enregistrée avec la partie et s'affiche dans l'onglet Équipe.

## Vérifié

- Nouveaux tests :
  - mobilier par type de pièce et conversion des pièces vides (17 contrôles) ;
  - priorités du personnel (13 contrôles).
- Le test du modèle couvre la coupe d'une pièce : deux moitiés, coin et pièce en L, prix, porte entre les pièces, sauvegarde.
- Le test de scène trace une cloison d'un mur à l'autre, sélectionne la nouvelle pièce d'un clic et change son type.
- Toutes les suites passent.
- Contrôlé dans le jeu sur captures.

## Aperçus (`Apercus-V86/`)

- `prix-sur-le-plan.png` : l'étiquette de prix en traçant une pièce.
- `wc-piece-vide.png` : un WC au-dessus d'une pièce vide, qui deviendra des toilettes.
- `wc-refuse.png` : un WC refusé dans le salon meublé.
- `priorite-femme-de-menage.png` : la section Priorité d'une femme de ménage.
- `piece-coupee.png` : une chambre coupée par une cloison, la nouvelle pièce sélectionnée.
