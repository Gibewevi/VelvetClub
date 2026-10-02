# Construction V68 — Jonctions

Exécutable : `Construction-V68-Jonctions.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Plus de piliers noirs sur les jonctions en T

Un pilier noir apparaissait là où deux murs bas se rejoignent en T, par exemple :

- une cloison qui rejoint le mur de la pièce ;
- le mur entre les toilettes et la réserve, qui rejoint le mur du hall ;
- toutes les jonctions entre pièces quand les murs sont coupés (touche W).

Ce poteau sombre est fait pour finir un muret : un coin, un bout de mur, le cadre d'une porte. Sur un mur qui continue tout droit, il n'avait rien à faire.

Désormais :

- **en T ou en croix**, le mur qui arrive s'appuie simplement contre celui qui continue, sans pilier ;
- **les coins en L, les bouts de mur et les cadres de porte** gardent leur poteau ;
- là où un muret rejoint un **mur pleine hauteur**, le raccord reste à la couleur du mur.

## Vérifié par les tests

- **Scène** : murs coupés, aucun poteau là où une cloison rejoint les murs de la pièce, et toujours un poteau aux coins.
- Toutes les autres suites passent toujours : modèle, recrutement, nuit simulée, interface en vraie fenêtre…

## Aperçus (`Apercus-V68/`)

- `murs-bas.png` : le local de départ, murs coupés, avant et après. Le pilier entre les toilettes et la réserve a disparu ; ceux de la porte de la chambre restent.
- `cloisons.png` : le salon cloisonné, avant et après. Plus de pilier là où les cloisons rejoignent les murs.
