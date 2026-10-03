# Construction V79 — Déchets

Exécutable : `Construction-V79-Dechets.exe`. Il utilise la même sauvegarde que les versions précédentes.

Cette version réunit deux chantiers menés en parallèle : les déchets, la tenue des escorts et les flaques (ce guide), et la refonte de l'affluence du club (réputation, file extérieure, onglet Personnel → Gestion), décrite dans `AFFLUENCE.md`.

## Moins de flaques sous la pluie

Les flaques sont maintenant rares et éparses : une quarantaine d'emplacements possibles sur tout le terrain, contre 260 avant.

- La plupart restent petites : chaque flaque a sa taille maximale, et seules quelques-unes grandissent vraiment.
- Elles apparaissent une à une au fil de l'averse et sèchent comme avant.
- Sous les toits et sous les objets, il n'y en a toujours pas.

## La gestion des déchets

Les **poubelles** (30 $, rayon Mobilier) deviennent utiles.

- **Les clients ont des choses à jeter.**
  - Après un verre au bar : un verre vide, une fois sur deux environ.
  - En sortant des toilettes : des mouchoirs, une fois sur trois.
  - Après le salon, la piste ou la scène : un papier, de temps en temps.
- **Avec une poubelle à moins de 9 m** dans la salle, l'accueil ou les toilettes, le client va y jeter son déchet, puis reprend sa soirée.
- **Sans poubelle à portée, ou si elles sont pleines**, le déchet finit par terre.
  - Il reste où il est tombé : verre renversé, mouchoirs, papiers.
  - Il gâche un peu l'ambiance de la pièce, moitié moins qu'un vrai tas d'ordures.
  - Les techniciens et les femmes de ménage le ramassent en deux minutes environ.
  - Un conseil s'affiche pour vous le signaler.
- **Les poubelles se remplissent** : 10 déchets chacune. On voit le niveau sur la poubelle, de vide à débordante. Sélectionnée, elle indique « Poubelle : 7 / 10 · à vider ».
- **Les femmes de ménage les vident.**
  - Dès qu'une poubelle atteint 7 déchets, une femme de ménage vient nouer le sac.
  - Elle le porte à la main jusqu'aux conteneurs verts près de la rue et l'y jette, puis reprend son travail.
  - Si elle est appelée ailleurs en chemin, le sac retourne dans la poubelle.
  - Les techniciens laissent les poubelles aux femmes de ménage.
- **En chambre**, les mouchoirs après une prestation vont dans la poubelle de la chambre s'il y en a une ; sinon ils restent par terre, comme avant.
- Le contenu des poubelles est enregistré avec la partie.

## Les escorts se changent dans la chambre

Pour une prestation au lit (classique ou complète) :

- **En arrivant dans la chambre**, l'escort s'arrête au pied du lit et se met en sous-vêtements :
  - une petite pirouette, deux tours sur elle-même en un peu plus d'une seconde ;
  - à mi-tour, un petit nuage à ses pieds, et la voilà en string et soutien-gorge de couleur ;
  - un cœur pour finir.
  - La couleur change d'une fois à l'autre et se distingue toujours de sa tenue habituelle.
- Elle s'assoit ensuite sur le lit et danse pour le client dans cette tenue.
- **Après la prestation**, elle passe à la douche s'il y en a une dans la chambre. **En sortant de la douche**, même pirouette en sens inverse : elle retrouve sa tenue, avec une étoile.
- Sans douche, elle se rhabille au pied du lit.
- Elle se rhabille aussi d'elle-même :
  - si la prestation est annulée ;
  - à la fin de son service ;
  - si elle tombe malade.
- La prestation rapide se fait toujours habillée.

## Vérifié

- **Nouveau test « déchets et tenue »** (75 contrôles) :
  - proportion des déchets ;
  - trajet jusqu'à la poubelle, remplissage et débordement par terre ;
  - ramassage, vidage par la femme de ménage jusqu'au conteneur dehors ;
  - sac remis en place si elle est interrompue ;
  - poubelle de chambre ;
  - sauvegarde ;
  - pirouette (quatre orientations, changement à mi-tour) ;
  - prestations complètes avec et sans douche.
- **Test de scène** : image et panneau d'une poubelle selon son remplissage.
- **Toutes les autres suites passent**, y compris le nouveau test d'affluence.
- **Filmé dans le jeu** :
  - la pirouette image par image, déshabillage puis rhabillage ;
  - les poubelles et la femme de ménage portant son sac vers le conteneur ;
  - les flaques avant et après, sol détrempé au maximum.

## Aperçus (`Apercus-V79/`)

- `flaques-avant-apres.png` : terrain détrempé au maximum, V78 à gauche, V79 à droite.
- `poubelles-et-dechets.png` : quatre poubelles de vide à pleine, des déchets par terre, une femme de ménage qui sort le sac.
- `sac-et-poubelles.png` : le même, de près.
- `tenue-escort.gif` : la pirouette filmée, déshabillage puis rhabillage.
- `tenue-escort-images.png` : la même, image par image.
