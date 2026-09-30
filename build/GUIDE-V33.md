# Construction V33 — Profondeur et douche

Exécutable : `Construction-V33-ProfondeurEtDouche.exe`. Il utilise la même sauvegarde que la V32 et reprend tout son contenu.

## Qui passe devant quoi

L'ordre d'affichage a été refait entièrement. Le décor, les meubles et les personnages sont triés **ensemble, à chaque image**, selon leur position au sol : un élément est dessiné avant un autre quand leurs images se recouvrent et qu'il se trouve derrière.

Les meubles où l'on s'assoit, se couche, danse ou se lave sont maintenant découpés en **parties**, chacune triée selon sa propre emprise :

| Meuble | Parties |
|---|---|
| Canapés, fauteuils (neufs et récupérés) | assise, dossier, deux accoudoirs |
| Chaise | assise, dossier |
| Lits (neuf et vieux, aussi occupé ou défait) | lit, tête de lit |
| Scène & barre | plateau, barre |
| Douche | bac, deux murs carrelés, paroi vitrée, traverse, porte |

Ce que cela change à l'écran :

- **Canapé face au joueur** : les trois places sont devant le canapé. Avant, la place de gauche passait derrière (voir `canape-avant-apres.png`).
- **Canapé, fauteuil ou chaise tourné dos au joueur** : le dossier cache le dos de la personne assise, et sa tête dépasse.
- **Accoudoirs** : celui du côté du joueur passe devant la personne, l'autre derrière.
- **Lits** : le couple est devant la tête de lit. Quand le lit est tourné, la tête de lit passe devant eux.
- **Scène** : la barre passe devant la danseuse ou derrière elle selon l'orientation de la scène.
- **Douche** : la personne à l'intérieur est devant le carrelage et derrière les vitres, dans les quatre orientations.
- **Bulles** (cœurs, étoiles, « ? »…) : toujours visibles, jamais coupées par un mur ou un dossier.
- **Ombres** : l'ombre au sol d'un personnage disparaît quand il est assis ou debout sur un meuble, puisque le meuble a déjà la sienne.
- **Contour de sélection** : il suit le meuble entier, sans trait parasite entre ses parties.

Le tri complet prend environ 1,5 ms par image, avec 270 éléments de décor et 24 personnages.

## Douche : par la porte, et seulement par la porte

- Le personnage s'arrête devant la porte vitrée. La porte s'ouvre en quatre images, il entre, elle se referme, et la vapeur apparaît. À la fin, elle s'ouvre, il sort et elle se referme.
- Si quelqu'un est appelé ailleurs pendant sa douche (fermeture du club, prestation annulée), il sort quand même par la porte.
- La charnière est du bon côté selon l'orientation, pour que la porte ouverte ne cache jamais l'entrée.
- **Placement** : la porte doit donner sur un sol libre de la même pièce, soit 60 cm devant la douche. Sinon, l'objet est refusé avec l'un de ces messages :
  - « La porte de la douche doit s'ouvrir dans la pièce. »
  - « Laissez la porte de la douche dégagée. »
  - « Cet objet bloquerait la porte de la douche. »
- **Anciennes sauvegardes** : une douche déjà posée avec la porte contre un mur est conservée, mais personne ne l'utilise. Son panneau affiche « Porte bloquée : douche inutilisable ». Il suffit de la tourner ou de la déplacer.

## Vérifié par les tests

- **Profondeur** : une galerie de 40 meubles (10 modèles × 4 orientations) avec 60 personnages assis, couchés, en train de danser ou sous la douche. Pour chaque personnage, l'ordre est vérifié contre chaque partie du meuble, plus les cas précis ci-dessus (canapé de face et de dos, chaise tournée, tête de lit, barre, murs et vitres de la douche).
- **Douche** : sur une soirée simulée, chaque entrée et chaque sortie passe par la porte, jamais par un autre côté, et jamais porte fermée. La porte passe bien par ses images d'ouverture et de fermeture.
- **Placement** : une porte bloquée ou tournée vers un mur est refusée, et une sauvegarde qui contient une telle douche se charge quand même.

## Aperçus

- `Apercus-V33/canape-avant-apres.png` : le même canapé avant et après la correction.
- `Apercus-V33/douche-porte-en-jeu.gif` : un client entre dans la douche, en jeu.
- `Apercus-V33/porte-douche-images.png` : les quatre images de la porte, dans les deux orientations face au joueur.
- `Apercus-V33/galerie-*.png` : la galerie de test (sièges, canapés, lits, scènes et douches).
