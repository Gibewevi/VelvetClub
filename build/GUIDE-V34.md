# Construction V34 — Parking

Exécutable : `Construction-V34-Parking.exe`. Il utilise la même sauvegarde que la V33.

## Une vraie rue devant le club

La rue ne suit plus les contours du bâtiment : c'est maintenant une route **fixe**, à l'échelle réelle.

- **Chaussée** : deux voies de 3,5 m (7 m en tout). On roule à droite : la voie côté club va vers l'ouest, la voie d'en face vers l'est.
- **Trottoirs** : 2,5 m en dalles de béton de chaque côté. Les lampadaires et les arbres sont sur les trottoirs.
- **Aspect** :
  - bitume fissuré (réparations, faïençage, quelques nids-de-poule) ;
  - ligne centrale en pointillés et lignes de rive, usées ;
  - bordures en granit avec des mauvaises herbes ;
  - grilles d'égout.
- **Rue latérale supprimée** : celle qui longeait le côté droit du club a disparu, pour laisser la place aux parkings.
- **Terrain constructible** : il s'arrête au trottoir. Une nouvelle pièce ne peut plus empiéter sur le trottoir ni sur la route (« Le trottoir et la rue sont publics »). Les anciennes sauvegardes se chargent telles quelles.

## L'outil Parking

**Construire → Parking**, ou la touche **K**.

- **Tracé** : cliquez-glissez une zone, comme pour une pièce. Elle doit toucher le trottoir, indiqué par une ligne verte en pointillés : c'est par là qu'entrent les voitures.
- **Prévisualisation verte** : les places, les allées et les entrées se dessinent pendant le tracé, avec la taille, le nombre de places et le prix.
- **Prévisualisation rouge** : le message dit pourquoi la zone est refusée (elle ne touche pas le trottoir, elle est trop petite, elle recouvre une pièce ou un autre parking…).
- **Prix** : 30 $ le m².
- **Sélection** : un clic sur un parking affiche sa taille, son nombre de places, son type d'allée et le bouton « Démolir le parking ». Les parkings sont aussi listés dans le panneau Construire.

### Ce que le jeu génère tout seul

- **Places** : 2,5 × 5 m.
- **Allée** : 6 m, à double sens.
- **Entrée** : 6 m de large à travers le trottoir, avec une bordure abaissée qui s'élargit à 9 m côté route.
- **Deux plans possibles**, le jeu gardant celui qui offre le plus de places :
  - **allées perpendiculaires à la rue** : des modules de 16 m (une rangée de chaque côté de l'allée) ou de 12 m (une seule rangée et une bande de 1 m) ;
  - **allée parallèle à la rue** : une rangée côté rue avec une ouverture pour l'entrée, l'allée, puis une rangée au fond. C'est le plan des zones larges et peu profondes.
- **Taille minimale** : 12 × 12 m, soit 2 places.
- **Détails** :
  - lignes blanches usées ;
  - butées de roues en béton à bandes jaunes ;
  - bordures avec mauvaises herbes tout autour (ouvertes à l'entrée) ;
  - taches d'huile ;
  - fissures ;
  - panneau P bleu près de l'entrée ;
  - lampadaires aux coins, côté trottoir.

## Prêt pour les voitures

Les dimensions sont celles d'une vraie petite voiture :
- 4,4 × 1,8 m, empattement de 2,7 m ;
- rayon de braquage de 4 à 5 m dans le parking et de 5,5 à 7 m sur la route (mesuré à l'essieu arrière).

Pour **chaque place**, le jeu calcule et vérifie un trajet complet :

1. Arrivée par une extrémité de la rue, sur la bonne voie.
2. Virage dans l'entrée.
3. Parcours de l'allée.
4. **Entrée en marche arrière** dans la place. C'est la manœuvre réaliste dans une place de 2,5 m : l'avant pivote au-dessus de l'allée, pas sur les voitures voisines. Une place sans voisine au-delà peut aussi se prendre en marche avant.
5. **Sortie en marche avant**, retour sur la route et départ par l'autre voie ou la même.

La vérification fait glisser la silhouette de la voiture tous les 35 cm le long du trajet :
- les **roues** restent sur la chaussée, l'entrée ou le parking ;
- la **carrosserie** peut passer au-dessus d'un trottoir, comme un pare-chocs au-dessus d'une bordure basse, mais jamais au-dessus d'un mur ;
- aucune autre voiture n'est touchée, **toutes les autres places étant occupées**.

Les places qu'aucune voiture ne pourrait atteindre, au fond d'une allée en impasse ou trop près de l'ouverture, ne sont pas tracées : leur surface sert d'aire de manœuvre. Par exemple, un parking de 16 × 20 m reçoit 10 places sur les 16 qu'on pourrait y peindre.

Les trajets sont prêts à servir. Pour une place et un sens de circulation, `Street.route_in(...)` et `Street.route_out(...)` renvoient la suite des positions (essieu arrière, direction, marche avant ou arrière) que les voitures n'auront qu'à suivre.

L'aperçu `voiture-test-trajet.gif` montre une voiture test : une simple boîte aux dimensions d'une voiture, qui n'existe que pour la démonstration. Elle arrive par la rue, recule dans sa place (en orange pendant les marches arrière), puis repart.

## Vérifié par les tests

- **Trajets** : tous les trajets de quatre parkings types (petit, profond, large et peu profond, en entrée comme en sortie) sont valides de bout en bout, avec toutes les autres places occupées.
- **Tailles** : 12 × 11 m est refusé, 12 × 12 m donne au moins 2 places, 16 × 20 m au moins 10, 40 × 20 m au moins 20.
- **Règles** :
  - le parking doit toucher le trottoir ;
  - il ne recouvre ni une pièce ni un autre parking ;
  - aucune pièce ne peut être construite dessus ni sur la rue ;
  - le prix est calculé au m² ;
  - les parkings sont sauvegardés et rechargés, et une sauvegarde plus ancienne se charge toujours.
- **En jeu** :
  - la ligne du trottoir s'affiche, la prévisualisation dessine les places ;
  - on peut tracer, payer, sélectionner, démolir et annuler ;
  - aucun lampadaire, arbre ou conteneur ne se retrouve sur la chaussée ni dans un parking.

## Aperçus

- `Apercus-V34/parking-vue-ensemble.png` : le club, la rue et deux parkings.
- `Apercus-V34/parking-detail.png` : bitume fissuré, lignes, butées, bordures et herbes.
- `Apercus-V34/outil-parking-valide.png` et `outil-parking-refuse.png` : l'outil pendant le tracé.
- `Apercus-V34/voiture-test-trajet.gif` : un trajet complet de la voiture test.
