# Construction V27 — Chambres vivantes (corrections)

Exécutable : `Construction-V27-ChambresVivantes.exe`.

## Bugs corrigés

- **Sortie de douche par la rue** : en quittant un endroit bloqué (douche, lit), un personnage cherchait la case libre la plus proche dans n'importe quelle pièce. Derrière un mur, c'était la rue. Il cherche maintenant d'abord **dans la même pièce**.
- **Couple qui sort du lit de l'autre côté du mur** : même correction. En descendant d'un lit collé au mur, le client et l'escort restent dans la chambre.
- **Vêtements dehors** : ils sont posés sur une case libre du **sol de la chambre**, du côté du lit qui reste visible à l'écran.
- **Femme de ménage indiscrète** :
  - elle n'entre plus dans une chambre où se trouve un couple (qui arrive, est au lit ou prend sa douche après) ;
  - si un couple arrive pendant qu'elle y travaille, elle interrompt sa tâche et retourne à son poste.

Un test vérifie chacun de ces points. Depuis le lit ou la douche, le premier pas se fait dans la chambre et le chemin ne passe jamais par la rue.

## En chambre : on voit enfin quelque chose

1. **Flirt** : ils sont assis au bord du lit, avec des cœurs (4 min de jeu).
2. **Danse privée** : l'escort se lève et danse devant le lit pour le client assis. Des cœurs et des « $ » s'affichent, et un **pourboire** est encaissé à la fin. La durée dépend de la prestation : 6, 10 ou 14 min.
3. **Sous la couette** : les vêtements sont au sol, les formes bougent, le lit tremble, et les bulles comiques suivent le script de chaque prestation (sueur / cœurs / « BOUM ! », étoiles, « Zzz »).
4. Ils se relèvent **dans la chambre**, la douche puis le ménage suivent.

## Vérifié par les tests

Le test de simulation vérifie :

- que la danse a bien lieu ;
- que personne ne passe par l'extérieur pendant une prestation ;
- que les vêtements restent dans la chambre ;
- que la femme de ménage ne reste jamais dans la chambre occupée (au plus le temps d'y réagir).

Sur une soirée : 19 prestations (10 rapides, 8 classiques, 1 complète) pour 6 132 $, pourboires compris.

Aperçus : `Apercus-V27/00-chambre-flirt-danse-couette.png`, `Apercus-V27/chambre-animation-x3.gif`.
