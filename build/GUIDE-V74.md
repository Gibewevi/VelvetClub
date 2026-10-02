# Construction V74 — Raccords et portes

Exécutable : `Construction-V74-Raccords-Portes.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Jonctions de murs sans coupure

Aux T (et aux angles, aux croix), on voyait une jointure sur le dessus des murs : des traits sombres qui se croisaient, comme si les deux murs étaient posés l'un sur l'autre.

- **Cause** : chaque mètre de mur est dessiné seul, comme un morceau de mur droit. Celui qui arrive dans un T dépassait donc dans le chapeau du mur traversant, avec ses traits de contour.
- **Correction** :
  - pour chaque jonction (angle, T, croix, murs hauts comme murets), les chapeaux de tous les murs qui s'y rejoignent sont maintenant dessinés ensemble, d'un seul tenant ;
  - ce raccord est posé par-dessus la jonction, sur 30 cm autour d'elle, et ne touche qu'au dessus des chapeaux ;
  - un T est désormais un T, sans coupure.

## Des portes qui ont du relief et qui s'ouvrent vraiment

- **Avant** :
  - le battant faisait 4 cm, au milieu d'un mur de 25 cm : il paraissait collé au mur ;
  - à l'ouverture, il disparaissait d'un coup, et il ne restait que le cadre.
- **Maintenant** :
  - le chambranle traverse le mur et dépasse un peu de chaque côté ;
  - le battant est un vrai panneau de 13 cm, posé en retrait dans l'embrasure, dont on voit la profondeur ;
  - quand quelqu'un approche, il pivote vers la pièce de devant en trois images : fermé, entrouvert, ouvert (en 0,15 s environ). On voit alors toute son épaisseur ;
  - il se referme de la même façon une fois la personne passée ;
  - les doubles portes battantes ont les mêmes vantaux épais et la même animation.

## Corrigé au passage

Windows ne distingue pas les majuscules dans les noms de fichiers : les images des raccords sont nommées sans majuscules (`xp`, `xm`, `zp`, `zm`).

## Vérifié par les tests

- **Scène** :
  - un T de murs hauts reçoit un raccord d'un seul tenant, dessiné par-dessus les trois murs ;
  - les deux vantaux d'une double porte passent par « entrouvert » puis « ouvert » quand la femme de ménage passe ;
  - un clic au milieu du battant sélectionne toujours la porte.
- **Art** : raccords et portes contrôlés avec le reste.
- Toutes les autres suites passent toujours.

## Aperçus (`Apercus-V74/`)

- `jonctions-avant-apres.png` : trois jonctions de près, avant (en haut) et après (en bas).
- `porte-fermee-entrouverte-ouverte.png` : la porte simple dans ses trois positions, pour chaque sens de mur.
- `portes-en-relief.png` : les portes posées dans les murs, en retrait, avec leur embrasure.
- `doubles-portes.png` : la double porte du fond ouverte par la femme de ménage.
- `grand-club.png` : ton club, jonctions continues, une porte en train de s'ouvrir.
