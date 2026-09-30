# Construction V23 — Arbres

Exécutable : `Construction-V23-Arbres.exe`.

## Des arbres plus vivants

Les anciens arbres paraissaient rectangulaires : leur feuillage, plus large que l'image, était coupé net sur les côtés. Ils sont entièrement redessinés au pixel, dans l'esprit de l'image de référence :

- **Feuillage en boules** : plusieurs grosses masses arrondies, chacune faite de petites touffes de feuilles rondes qui se chevauchent comme des écailles.
  - Le haut de chaque touffe est éclairé et le dessous est plus sombre.
  - Des creux sombres séparent les masses.
  - Le dessous de la couronne est dans l'ombre.
- **Tronc** épais au pied évasé, avec des racines, une écorce striée et quelques nœuds. Il se divise en trois branches qui partent sous le feuillage.
- **Fosse d'arbre** carrée dans le trottoir : bordure en pierre, terre, touffes d'herbe et quelques petites fleurs jaunes.
- **Trois silhouettes** (couronne ronde, haute et étroite, basse et large), choisies selon l'emplacement.

## Animation

- Le vent fait onduler la couronne : les masses du haut bougent d'un pixel, en vague du haut vers le bas. Quelques touffes accrochent la lumière par moments, comme des feuilles qui frémissent.
- La boucle compte 8 images. Le tronc reste immobile.
- Chaque arbre a son propre rythme, pour qu'ils ne bougent pas tous ensemble.
- Aperçu animé : `Apercus-V23/arbres-vent-x3.gif`.

## Vérifications

Un test contrôle pour chaque arbre :

- que ses images sont nettes ;
- que le feuillage bouge d'une image à l'autre ;
- que le tronc reste fixe ;
- que la fosse existe.
