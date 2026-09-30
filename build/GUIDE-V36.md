# Construction V36 — Placement des parkings corrigé

Lancer `Construction-V36-Parking-Placement.exe`. La sauvegarde existante reste compatible et le pixel art de la V35 est conservé.

## Construire une place

Choisir **Construire → Parking**, ou **K**, puis tracer une zone contre le trottoir.

| Zone sur la grille | Résultat |
| --- | --- |
| 2 × 5 m | Rouge : trop étroit |
| 3 × 4 m | Rouge : une place entière ne tient pas |
| 3 × 5 m | Vert : 1 place |
| 5 × 3 m | Vert : 1 place tournée |
| 5 × 5 m | Vert : 2 places |
| 10 × 5 m | Vert : 4 places |

Les places font toujours **2,5 × 5 m**. Le tracé suit la grille de 1 m, ce qui explique le minimum de 3 × 5 cases. Le jeu compare les orientations des rangées et utilise aussi une bande restante si une rangée tournée y tient. Les places ne dépassent pas la zone et ne se chevauchent pas.

La prévisualisation et la pose utilisent le même plan. En rouge, le message précise la raison ; si la surface est trop petite, le contour montre l'emprise de la place entière. Relâcher en rouge ne construit rien et ne débite rien. L'outil fonctionne dans les deux sens du glisser-déposer.

Le prix reste de **30 $ par m² de zone** : 450 $ pour une zone de 3 × 5 m. Annuler rend cette somme.

## Cause corrigée

La V35 réservait une allée de 6 m, exigeait au moins deux places et supprimait celles qui ne passaient pas ses tests de braquage. La V36 calcule les places selon leur emprise au sol. Le prototype de trajets reste séparé du placement ; il ne détermine plus le nombre de places peintes. Les anciens parkings gardent leur zone et reçoivent le nouveau calcul.

Les règles de terrain restent actives : contact avec le trottoir, respect des limites, pas de chevauchement avec une pièce ou un autre parking.

## Vérifié

- 401 contrôles spécifiques de dimensions, capacité, emprise, coût et sauvegarde ;
- 304 contrôles du modèle, dont les trajets du prototype séparé ;
- test de scène réussi ;
- test d'interface avec vrais événements de souris : rouge/vert, pose, refus, tracé inverse et annulation.

Aperçus : `Apercus-V36/parking-rouge.png`, `parking-vert.png`, `parking-une-place.png`.
