# Construction V75 — Portes pleines

Exécutable : `Construction-V75-Portes-Pleines.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Des portes de l'épaisseur du mur

Le battant fait maintenant toute l'épaisseur du mur (25 cm), au ras des deux faces, encadré par le chambranle qui dépasse un peu de chaque côté. Quand il s'ouvre, on voit un vrai panneau épais pivoter. C'est valable pour les portes simples et pour les deux vantaux des doubles portes.

## Animation d'ouverture corrigée (clignotement, morceaux qui disparaissent)

J'ai filmé un personnage traversant une porte simple puis une double porte, image par image, tel que le jeu les dessine.

- **Cause** : les trois images d'une porte (fermée, entrouverte, ouverte) n'avaient pas la même taille ni le même point d'ancrage, puisque le battant ouvert dépasse du cadre. Le jeu changeait d'image sans compenser : l'image ouverte était décalée de 6 pixels, si bien que le battant sautait de côté à chaque ouverture et à chaque fermeture.
- **Correction** :
  - les trois images de chaque porte sont maintenant rendues sur un même cadre, de même taille et même ancrage : elles se superposent exactement ;
  - le tri d'affichage tient compte de tout le mouvement du battant (il ne voyait que la porte fermée) : le battant ouvert n'est plus coupé par ce qui l'entoure.
- **Résultat filmé** : fermée → entrouverte → ouverte pendant le passage → refermée, sans saut ni clignotement, pour la porte simple comme pour la double.

## Vérifié par les tests

- **Art** (nouveau contrôle) : les trois images de chaque porte, simple et double, dans les deux sens de mur, ont le même cadre.
- **Scène** : la double porte passe par « entrouverte » puis « ouverte » quand quelqu'un passe ; un clic au milieu du battant sélectionne la porte.
- Toutes les autres suites passent toujours.

## Aperçus (`Apercus-V75/`)

- `traversee-portes.gif` : l'animation complète, un personnage traverse une porte simple puis une double porte.
- `porte-simple-image-par-image.png` et `double-porte-image-par-image.png` : les mêmes traversées, image par image.
