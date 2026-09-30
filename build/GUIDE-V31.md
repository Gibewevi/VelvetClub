# Construction V31 — Scène et barre

Exécutable : `Construction-V31-SceneEtBarre.exe`.

## La scène s'anime

L'objet **« Scène & barre »** (Mobilier, 2 400 $) tourne en boucle sur 4 images :

- **Le tour circulaire** : une rangée de LED de couleur fait le tour de la scène (chenillard), avec une seconde ligne de LED blanches qui tourne en sens inverse.
- **Le plateau** : deux anneaux néon changent de couleur à chaque image, et un faisceau de lumière balaie la piste en tournant.
- **La barre** : des anneaux lumineux montent le long de la barre chromée, et le socle et le sommet s'allument.
- **La lueur au sol** autour de la scène change de couleur au même rythme.

## Personnalisable

Sélectionnez la scène, puis choisissez sa palette dans **« COULEURS »** (gratuit, annulable, conservé dans la sauvegarde). Ce sont les mêmes palettes que la piste de danse :

- **Arc-en-ciel**
- **Rose & violet**
- **Bleu glacier**
- **Or & rouge**
- **Vert acide**

Une scène et une piste peuvent avoir des couleurs différentes.

## Le show à la barre

- **La scène est réactivée** : une escort libre monte volontiers faire un show à la barre (« Show à la barre » dans le Personnel). Si la scène est occupée, elle va plutôt danser sur la piste.
- **Tout le monde regarde** : pendant un show, les clients se dirigent bien plus souvent vers la scène.
- **Pourboires** : les **clients généreux** glissent des pourboires à la danseuse (« $ »).
  - Ceux qui sont au pied de la scène donnent le plus souvent.
  - Ceux qui regardent depuis le bar ou le salon de la même pièce donnent aussi, moins souvent.
  - Le pourboire vaut de 10 à 70 $ environ selon le standing de l'escort, et il est pris sur le budget du client.
- **Rendez-vous direct** : un client généreux qui regarde le show (devant la scène, au bar ou au salon de la pièce) peut emmener la danseuse **directement en chambre**, avec de meilleures chances d'accord que par une simple discussion.
- **Rapport de nuit** : la ligne **« Scène »** compte désormais les pourboires de la scène et de la piste.

## Vérifié par les tests

Sur une soirée du test de simulation (une seule escort de prestige, une scène dans la salle du bar et une piste dans la grande salle) :

- 434 $ de pourboires, dont 394 $ à la barre ;
- 3 rendez-vous pris directement depuis la scène, et 2 depuis la piste.

Les tests vérifient aussi :

- que les 20 images de la scène existent (5 palettes × 4 images) ;
- que la palette de la scène se nomme et se conserve correctement.

Aperçus :

- `Apercus-V31/scene-animee-5-couleurs-x2.gif` : la scène animée dans les 5 palettes ;
- `Apercus-V31/00-club-scene.png` et `00-scene-zoom.png` : un show en cours, en jeu.
