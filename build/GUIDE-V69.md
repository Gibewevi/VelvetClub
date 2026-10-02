# Construction V69 — Portes

Exécutable : `Construction-V69-Portes.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Sélectionner une porte pour la reboucher

Il était difficile de sélectionner une porte pour la reboucher :

- **murs coupés** : une porte dans un muret n'a pas de dessin, seulement un passage entre deux poteaux ; le clic ne trouvait rien ;
- **murs hauts** : le dessin du mur a un trou à l'endroit de la porte, et le clic sur le battant passait au travers, jusqu'à la pièce derrière.

Désormais :

- **Un clic sur le battant** d'une porte (ou sur la vitre d'une fenêtre) la sélectionne. Quand des murs se superposent, c'est celui de devant qui est pris.
- **Un clic près du passage** sélectionne la porte, même sans dessin : à moins de 35 cm de la porte au sol, entre ses deux poteaux. Cela vaut aussi pour une fenêtre, et pour une porte cachée derrière un mur.
- **Au survol**, en mode Sélection, la porte, la fenêtre ou la cloison visée s'éclaire en jaune avec « Porte · cliquer pour sélectionner ». On voit ce qu'on va prendre avant de cliquer.
- **Avec l'outil Porte (P)** ou **Fenêtre (F)**, cliquer une porte ou une fenêtre déjà en place la sélectionne. Le panneau propose alors « Reboucher » (ou Suppr). Au survol, l'infobulle l'annonce.

## Vérifié par les tests

- **Scène** :
  - murs hauts, un clic sur le battant de la porte du mur du fond la sélectionne ;
  - une porte dans un mur coupé est prise par un clic près de son passage ;
  - murs coupés, le survol l'annonce, le panneau propose « Reboucher », et la porte disparaît ;
  - l'outil Porte sur une porte existante la sélectionne sans rien changer.
- Toutes les autres suites passent toujours : modèle, recrutement, nuit simulée, interface en vraie fenêtre…

## Aperçus (`Apercus-V69/`)

- `survol-porte.png` : murs coupés, la souris près de la porte de la chambre. La porte s'éclaire et l'infobulle propose de la sélectionner.
- `porte-selectionnee.png` : la même porte sélectionnée, avec « Reboucher ».
