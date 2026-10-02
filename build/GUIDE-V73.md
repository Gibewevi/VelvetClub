# Construction V73 — Bouts de mur

Exécutable : `Construction-V73-Bouts-de-mur.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Plus aucun pilier sur les murs hauts

Il restait des piliers dans certains angles en V72. C'était là où un mur haut s'arrête contre un mur coupé (bas), par exemple :

- à l'angle arrière droit d'une pièce dont le mur de droite donne sur l'extérieur : les murs de droite et de devant sont toujours coupés pour la vue ;
- là où le mur entre deux pièces arrive sur la façade.

À ces endroits, le bout du mur haut est réellement visible. Je le fermais avec un poteau : un objet à part, un peu plus large que le mur, avec son propre chapeau et un contour, qu'on lisait comme un pilier planté dans l'angle.

**Désormais, il n'y a plus de poteau du tout sur les murs hauts.**

- **Où des murs hauts se rejoignent** (angle, T, croix), ils se raccordent d'eux-mêmes, chapeaux en onglet.
- **Où un mur haut s'arrête**, son dernier mètre est dessiné avec sa vraie fin : la face de bout en brique (ou papier peint, carrelage…), éclairée comme le reste, avec le chapeau au ras du mur. Le mur s'arrête net, comme une coupe, sans pilier.
- **Le muret coupé qui passe là** est dessiné devant le bout du mur haut, avec son chapeau continu.
- **Les murets** (murs coupés) gardent leurs poteaux sombres aux coins, aux bouts et aux passages de porte, comme sur la référence d'origine.
- **Seule exception** : une porte ou une fenêtre placée tout au bout d'un mur haut garde un poteau pour fermer ce bout.

Les doubles portes battantes de la V72 restent inchangées.

## Vérifié par les tests

- **Scène** (trois chambres côte à côte, dont une cloisonnée) :
  - aucun poteau sur les murs hauts ;
  - le mur entre deux chambres et le mur du fond qui s'arrêtent sur un mur coupé utilisent leur vraie fin ;
  - là où des murs hauts se rejoignent, ils se raccordent sans fin dessinée ;
  - la façade coupée passe devant le bout du mur entre deux chambres ;
  - aucun poteau aux bords d'une porte de mur haut ;
  - les coins et les passages des murets gardent leurs poteaux.
- **Art** : les nouvelles fins de mur (début, fin, les deux) existent pour chaque revêtement et chaque sens.
- Toutes les autres suites passent toujours.

## Aperçus (`Apercus-V73/`)

- `club-avant-apres.png` : ton club, avec les poteaux en bout de mur (V72) puis les murs qui s'arrêtent net (V73).
- `chambres-avant-apres.png` : trois chambres côte à côte, V72 puis V73.
- `local-de-depart.png` : le local de départ.
- `doubles-portes.png` : la scène des doubles portes avec les nouveaux bouts de mur.
