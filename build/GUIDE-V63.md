# Construction V63 — Petit nuage de poussière

Exécutable : `Construction-V63-Poussiere.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Ce qui change

Quand on pose ou déplace un objet, un petit nuage de poussière s'élève à son pied, dans le même dessin que la fumée des pneus de la camionnette de livraison.

- **Quand** :
  - un objet acheté est posé (y compris un objet commandé qui attend sa livraison) ;
  - un objet est déplacé, en le faisant glisser ou avec « Déplacer » ;
  - le livreur installe un objet (en plus du petit cœur).
- **Rotation** : tourner un objet sur place ne soulève que quelques éclats, encore plus discrets.
- **Le dessin** :
  - les nuages viennent des coins de l'objet, plus le milieu des grands côtés pour un canapé ou un lit ;
  - ils sont plus petits que ceux des pneus : seulement les étapes « pouf », petite bouffée, volutes et derniers éclats ;
  - ils s'écartent un peu vers l'extérieur et montent de quelques pixels, puis s'effacent en environ une demi-seconde.
- **La place des nuages** : ceux de l'arrière passent derrière l'objet, ceux de l'avant devant lui. Les couleurs pastel restent nettes, sans brume floue.
- **Le timing** : l'animation suit le temps réel. Elle joue donc aussi quand le jeu est en pause, pendant qu'on aménage, et un redessin du bâtiment ne la coupe pas.
- Les personnages engagés n'en font pas : seuls les objets.

## Vérifié par les tests

- Poser un objet fait des nuages à l'avant et à l'arrière.
- Un redessin du bâtiment ne coupe pas le nuage.
- Tout a disparu en moins d'une seconde, sans rien laisser derrière.
- Un déplacement refait un nuage ; une rotation ne fait que quelques éclats.
- Toutes les autres suites passent toujours : modèle, art, scène, nuit simulée, livraisons, interface en vraie fenêtre.

## Aperçus (`Apercus-V63/`)

- `poussiere-pose.gif` : un canapé posé (en attente de livraison) et une plante déplacée, avec leur petit nuage.
- `poussiere-pose.png` : le nuage à son plus haut.
