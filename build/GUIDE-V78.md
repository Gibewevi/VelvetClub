# Construction V78 — Cadres de porte

Exécutable : `Construction-V78-Cadres-de-porte.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Un encadrement de la largeur du mur, partout et tout le temps

En V76, le cadre traversait bien les 25 cm du mur, mais on ne le voyait pas :

- en vue isométrique, on ne voit la profondeur de l'ouverture que d'un côté, à gauche ;
- à droite et en haut, il ne restait que la face avant du chambranle, 6 cm, soit un pixel ;
- porte ouverte, le battant venait se placer exactement devant ce côté gauche, et l'encadrement disparaissait.

J'ai comparé trois solutions sur maquettes, fermées et ouvertes : le cadre épais tout autour, le battant qui s'ouvre vers l'arrière, et l'actuel. Le cadre épais est la seule qui montre la largeur du mur dans tous les cas.

- **Le cadre** : montants et linteau font 22 cm de large en façade, soit la largeur du mur, sur les trois côtés et dans toute l'épaisseur.
  - On le lit comme la coupe du mur autour de la porte, fermée comme ouverte.
  - Le linteau monte jusqu'au chapeau du mur.
- **Le battant** reste posé au fond, contre la face arrière. Il est un peu plus étroit (56 cm), avec sa vitre, ses moulures et sa poignée.
- **Doubles portes** : même cadre. Le linteau de 2 m est maintenant d'un seul tenant, sans coupure au milieu entre les deux vantaux.

## Animation testée image par image

Un personnage traverse quatre portes, filmées dans le jeu :

- une porte simple et une double porte sur un mur dans un sens ;
- une porte simple et une double porte sur un mur dans l'autre sens.

Chaque fois, la porte passe de fermée à entrouverte, ouverte pendant le passage, puis refermée. Pas de saut, pas de clignotement, pas de morceau qui disparaît, et le cadre reste visible.

## Vérifié par les tests

- **Art** : les images d'ouverture de chaque porte partagent un même cadre (contrôle de la V75).
- **Scène** : doubles portes (appariement, ouverture en deux temps), sélection d'une porte par un clic au milieu du battant.
- Toutes les autres suites passent.

## Aperçus (`Apercus-V78/`)

- `cadres-fermes.png` : les portes fermées dans leur cadre, sur les deux sens de mur.
- `traversees-portes.gif` : les quatre traversées filmées.
- `porte-simple-mur-x.png`, `double-porte-mur-x.png`, `porte-simple-mur-z.png`, `double-porte-mur-z.png` : les mêmes, image par image.
- `maquettes.png` : les trois solutions comparées, fermées et ouvertes.
