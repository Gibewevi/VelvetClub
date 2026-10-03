# Construction V77 — Personnel

Exécutable : `Construction-V77-Personnel.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Les onglets Équipe et Recrutement ont la même largeur

Le tiroir Personnel changeait de largeur selon l'onglet : environ 455 pixels pour Équipe, 660 pour Recrutement. Les deux font maintenant exactement la même largeur, environ 535 pixels : Équipe s'élargit un peu et Recrutement se réduit nettement.

- Le contenu des deux onglets reçoit une largeur commune : le tiroir ne saute plus quand on passe de l'un à l'autre.
- Dans Recrutement, la rangée des huit postes utilise des boutons portrait plus compacts, centrés, qui tiennent dans cette largeur.
- Les autres tiroirs (Construire, Mobilier, Clients…) gardent leur largeur habituelle.

## Vérifié

- Mesuré sur captures : la barre de titre du tiroir s'arrête au même pixel pour les deux onglets.
- Test de scène (embauche depuis l'onglet Recrutement, liste de l'équipe) et toutes les autres suites passent.

## Aperçu (`Apercus-V77/`)

- `personnel-meme-largeur.png` : les deux onglets côte à côte, à la même largeur.
