# Construction V61 — Extensions automatiques

Exécutable : `Construction-V61-Extensions.exe`. Il utilise la même sauvegarde que la version précédente.

## Le point de départ décide

Avec l'outil **Pièce**, on ne choisit rien : le jeu comprend l'intention à partir de l'endroit où commence le tracé.

- **Départ sur le terrain libre** : c'est une **nouvelle pièce**, du type choisi dans Construire. C'est vrai même si le tracé finit collé à une pièce existante : les deux restent séparées par un mur.
- **Départ sur un mur d'une pièce, ou juste à côté** (moins de 30 cm) : c'est un **agrandissement**. La surface tracée de l'autre côté du mur rejoint la pièce.
- **Départ sur le sol d'une pièce** : c'est aussi un agrandissement. On « tire » la pièce jusqu'où l'on veut.
  - Seule la surface au-delà de ses murs compte.
  - Un tracé qui déborde en diagonale contourne l'angle : on obtient une pièce en L.

## Ce que l'on voit

**Avant de cliquer**, au survol :
- « Nouvelle pièce : Réserve » sur le terrain libre ;
- « Agrandir : Chambre (depuis ce mur) » près d'un mur, avec la case de départ en vert et le contour de la pièce en rose.

**Pendant le tracé** :
- la surface ajoutée est en vert (en rouge si elle est refusée), et la pièce agrandie reste entourée ;
- le message indique la surface et le prix, par exemple « Agrandir : Chambre · +12 m² · 976 $ · Relâchez pour valider ».

## Les travaux

- L'agrandissement est un **chantier** comme en V60 : balisage, ouvriers, dalle, murs en parpaings sur les côtés neufs, peinture, sol.
- Il prend automatiquement le **type et les revêtements** de la pièce agrandie.
- Pendant les travaux, la pièce reste utilisable et garde son mur. Seule la surface neuve est facturée.
- **À la fin des travaux, le mur entre les deux tombe** et les surfaces fusionnent en une seule pièce. Le message dit par exemple « Agrandissement terminé : Chambre, 32 m² d'un seul tenant ».
- La pièce agrandie (L, T…) fonctionne comme les autres :
  - mobilier posé à cheval sur l'ancien mur ;
  - clients et personnel qui passent là où il était ;
  - revêtements et valeur calculés sur la nouvelle surface ;
  - contour de sélection qui suit la nouvelle forme.
- On peut l'agrandir encore en traçant depuis un de ses murs.

## Pourquoi ce choix

Agrandir à la fin des travaux plutôt qu'immédiatement :
- la pièce existante continue de servir pendant le chantier ;
- les clients n'entrent pas dans la poussière ;
- l'agrandissement reste un chantier visible du début à la fin.

Accepter aussi un départ depuis le sol de la pièce rend le geste encore plus naturel : on part de la pièce et on tire jusqu'où on veut qu'elle aille.

## Règles

- **Annuler** un agrandissement en cours le retire et le rembourse.
- Une fois l'extension terminée et fusionnée, Annuler / Rétablir ne sépare plus jamais la pièce.
- Supprimer une pièce supprime aussi ses agrandissements encore en chantier.
- Une pièce déjà agrandie n'a plus de poignées, puisqu'elle n'est plus un rectangle. Une pièce rectangulaire garde ses poignées.
- Un agrandissement ne peut pas chevaucher une autre pièce, un parking ni la rue. Il peut ne faire qu'un mètre de large.

## Vérifié par les tests

- **Modèle** (360 contrôles), notamment :
  - extension depuis un mur ou depuis l'intérieur ;
  - surface au-delà des murs uniquement ;
  - refus d'un tracé qui reste dans la pièce ou qui chevauche une autre pièce ;
  - fusion, mur supprimé, contour, périmètre et surface ;
  - mobilier à cheval sur l'ancien mur, passage des personnages ;
  - pièce en L agrandie deux fois ;
  - chantier en L ;
  - sauvegarde et données abîmées ;
  - suppression en cascade.
- **Scène** : départ près d'un mur, sur le sol ou sur le terrain libre ; tracé réel jusqu'à l'extension, puis équipe d'ouvriers, mur conservé pendant les travaux, fusion à la fin, mur disparu, passage et mobilier.
  - Annuler ne sépare pas la pièce.
  - Un tracé parti du terrain libre et fini contre une pièce reste une pièce séparée.
- Les autres suites (art, simulation d'une nuit, livraisons, interface en vraie fenêtre…) passent toujours.

## Aperçus (`Apercus-V61/`)

- `extension-1-survol.png` : survol près d'un mur, « Agrandir : Chambre (depuis ce mur) ».
- `extension-2-trace.png` : tracé depuis le sol de la chambre, extension en L en vert.
- `extension-3-travaux.png` : le chantier de l'extension, la chambre garde son mur.
- `extension-4-fusion.png` : travaux finis, une seule chambre de 32 m².
- `extension-5-nouvelle-piece.png` : tracé parti du terrain libre et fini contre la chambre, c'est une pièce séparée.
