# Construction V71 — Piliers

Exécutable : `Construction-V71-Piliers.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Les piliers des jonctions en T sont entiers

Là où un mur pleine hauteur rejoint la façade coupée (le mur entre deux chambres, ou une cloison), un pilier coiffe le bout du mur. Côté extérieur, on n'en voyait qu'une partie : le muret de façade qui part vers la droite (ou vers l'avant) était dessiné par-dessus sa moitié basse, et son chapeau beige traversait le pilier.

- **Cause** :
  - le jeu ordonne l'affichage d'après la position au sol ;
  - un pilier n'est qu'un point, au même endroit que le début du muret suivant ;
  - il était donc jugé « derrière » ce muret et dessiné avant lui.
- **Correction** :
  - un pilier est maintenant toujours dessiné après les murs dont il coiffe l'extrémité ;
  - il apparaît en entier, et les murets viennent s'appuyer contre lui.

## Plus de traits noirs verticaux sur les murs

Certains murs pleine hauteur portaient un trait noir vertical, de part et d'autre de leurs portes.

- **Cause** :
  - le jeu posait un poteau à chaque bord de porte, même dans un mur haut ;
  - le mur le recouvrait presque entièrement : il ne restait que le trait noir de son contour, un « pilier invisible ».
- **Correction** :
  - dans un mur haut, la porte a son propre cadre et le mur continue autour : plus de poteau à ses bords ;
  - les poteaux restent là où ils servent : coins, jonctions en T, bouts de muret, passages de porte dans un mur coupé, changements de hauteur.

## Vérifié par les tests

- **Scène** :
  - trois chambres côte à côte, dont une cloisonnée, avec des portes dans les murs hauts ;
  - le pilier entre deux chambres passe devant les trois murs qui s'y rejoignent ;
  - aucun poteau au bord d'une porte dans un mur haut ;
  - un passage dans un muret coupé garde ses deux poteaux.
- Les contrôles de profondeur existants (meubles et personnages dans leurs quatre orientations) passent toujours, comme toutes les autres suites.

## Aperçus (`Apercus-V71/`)

- `piliers-avant-apres.png` : trois piliers de près, avant et après.
- `portes-murs-hauts.png` : les portes des murs hauts, avec les poteaux inutiles puis sans.
- `chambres.png` : trois chambres côte à côte, dont une cloisonnée, avec leurs portes, vues de la rue.
