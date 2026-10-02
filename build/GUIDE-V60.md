# Construction V60 — Chantiers

Exécutable : `Construction-V60-Chantiers.exe`. Il utilise la même sauvegarde que la version précédente : les pièces déjà construites restent terminées.

## Ce qui change

Une pièce tracée avec l'outil **Pièce** n'apparaît plus d'un coup. Elle devient un **chantier** que l'on voit se construire.

1. **Dès la validation**
   - La zone est délimitée : piquets, ruban rouge et blanc, pointillés orange au sol, terre de chantier.
   - Trois ouvriers arrivent, avec casque jaune, gilet orange à bandes réfléchissantes et vêtements de travail.
   - Le matériel est installé le long des murs du fond : bétonnière orange, palette de parpaings, sacs de ciment, brouette, armatures rouillées, tréteaux et planches, seau de mortier, quelques blocs et un projecteur sur trépied allumé.
   - Les petits chantiers reçoivent moins de matériel.
2. **Dalle de béton** : le béton est coulé case par case depuis le coin du fond. Une case fraîche est sombre et humide, puis sèche et s'éclaircit. Un ouvrier charge la bétonnière à la pelle, un autre fait la navette avec la brouette pleine, le troisième étale le béton.
3. **Murs** : les parpaings sont posés rang par rang, un rang complet tout autour avant le suivant. Les murs du fond montent jusqu'en haut (14 rangs) et les murs de devant restent bas, comme dans le reste du jeu.
   - Portes et fenêtres déjà prévues gardent leur ouverture.
   - Le ruban disparaît là où le premier rang est posé.
   - La palette de parpaings se vide à mesure.
   - Un ouvrier porte les blocs, un autre les pose à la truelle, le troisième alterne mortier et pose.
4. **Peinture** : chaque pan de mur passe du parpaing brut à sa finition définitive (papier peint, peinture, carrelage…). La couleur avance par bandes verticales, sous le rouleau de deux peintres ; le troisième apporte les pots.
5. **Sol** : le revêtement choisi est posé case par case par deux ouvriers à genoux. Le troisième apporte les lames ou coupe sur les tréteaux.
6. **Finitions** : le matériel est emporté pièce par pièce, puis les ouvriers partent. La pièce devient une pièce normale, utilisable et meublable.

## Cliquer sur un chantier

La fenêtre **Chantier** affiche :
- une barre d'avancement ;
- l'**avancement en %**, recalculé plusieurs fois par seconde ;
- la **phase en cours** : dalle de béton, montée des murs, peinture des murs, pose du sol, finitions ;
- le **temps restant** en heures de jeu, avec l'équivalent en secondes à la vitesse actuelle.

Le pourcentage correspond à ce qu'on voit : il compte exactement les cases coulées, les rangs posés, les bandes peintes et les cases de sol affichées.

Le survol d'un chantier indique aussi « Chantier · Chambre · 42 % », et la liste du plan (Construire) montre l'avancement de chaque chantier.

## Modifier un chantier en cours

- **Agrandir ou étirer** : tirez les poignées de la zone sélectionnée.
  - Pendant le glisser, le coût de la différence s'affiche (« +120 $ »). Seule cette différence est facturée ; une réduction est remboursée.
  - Ce qui est construit reste en place : béton coulé, rangs de parpaings des côtés conservés, peinture, sol.
  - Les nouvelles cases rejoignent les travaux. L'équipe revient couler la dalle de ces cases, puis monte les nouveaux murs.
  - Le pourcentage et le temps restant sont recalculés aussitôt.
  - Seul le mur du côté déplacé est démonté, puisqu'il se trouverait au milieu de la pièce agrandie.
- **Type de pièce et revêtements** se changent pendant les travaux ; les peintres et les poseurs utilisent les nouveaux choix.
- **Abandonner le chantier** retire la pièce et la rembourse.

## Règles

- Personne d'autre (clients, personnel, livreurs) n'entre sur un chantier.
- On ne pose aucun meuble avant la fin des travaux (« Chantier en cours »).
- Les travaux avancent à la vitesse du jeu (pause, ×1, ×3), de jour comme de nuit. Une chambre de 4 × 4 m demande environ 2 h de jeu, soit près d'une minute à vitesse normale.
- **Annuler / Rétablir** reviennent sur le plan, jamais sur le travail déjà fait.
- L'avancement est **sauvegardé** avec la partie.

## Principe technique

- La **progression logique** (`scripts/site_plan.gd`) compte le temps, le pourcentage, les phases et le coût, élément par élément : cases de dalle, rangs de chaque mètre de mur, peinture de chaque pan, cases de sol, finitions.
- La **progression visuelle** (`scripts/construction.gd`) ne décide de rien : elle révèle les sprites des éléments terminés.
- Les ouvriers (`scripts/site_worker.gd`) jouent la phase en cours près de l'élément en travaux. Leurs gestes sont : marcher, porter un bloc, poser un bloc à la truelle, pelleter, pousser la brouette, travailler à la bétonnière, verser et étaler le béton, poser le parquet à genoux, peindre au rouleau.
- Tout le nouveau pixel art est dessiné à sa résolution native (`tools/pixelart/pa_site.py`) : murs en parpaings rang par rang, matériel, ruban, objets portés, brouette dans les quatre directions. Il s'ajoute au casque de chantier, aux gilets et aux poses « pousser » et « travailler de dos ».

## Vérifié par les tests

- **Modèle** (338 contrôles), notamment :
  - ordre des phases, coulée case par case depuis le fond, rangs posés tout autour ;
  - pourcentage et temps restant ;
  - agrandissement qui garde le travail fait ;
  - annulation qui ne défait pas les travaux ;
  - sauvegarde, et données abîmées refusées ;
  - accès et mobilier refusés pendant les travaux.
- **Scène** : trois ouvriers sur la zone, balisage immédiat, cases de béton qui apparaissent une à une, béton humide.
  - Les sprites révélés correspondent au pourcentage affiché, et le panneau montre le même chiffre.
  - Un agrandissement ne facture que la différence et garde le béton et les murs déjà faits.
  - Après une annulation, l'avancement est conservé.
  - À la fin, ouvriers et matériel partent ; la pièce est accessible et meublable.
- Les autres suites (art, simulation d'une nuit, livraisons, interface dans une vraie fenêtre…) passent toujours.

## Aperçus (`Apercus-V60/`)

- `chantier-1-balisage.png` : la zone vient d'être commandée.
- `chantier-2-dalle.png` : coulée du béton, la brouette en navette.
- `chantier-3-murs.png` : les parpaings montent.
- `chantier-4-peinture.png` : les murs passent du brut à la finition.
- `chantier-5-sol.png` : pose du sol à genoux.
- `chantier-6-finitions.png` : le matériel s'en va.
- `chantier-panneau.png` : la fenêtre Chantier (avancement, phase, temps restant, modification).
- `chantier-agrandi.png` : le même chantier agrandi pendant la montée des murs.
- `chantier-progression.gif` : tout le chantier, du balisage à la pièce terminée.
- `ouvriers.png` : les ouvriers de face et de dos (repos, marche, brouette, pelle, truelle, rouleau, à genoux).
