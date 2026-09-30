# Construction V42 — Orientation automatique

Exécutable : `Construction-V42-Orientation-Auto.exe`. Il utilise la même sauvegarde que la V41.

## Les meubles se tournent tout seuls

Pendant la pose d'un meuble, qu'il soit neuf, déplacé ou dupliqué, le jeu examine ce qui l'entoure. Il essaie les quatre orientations possibles et garde celle qui correspond le mieux. L'aperçu fantôme montre directement l'objet dans le bon sens.

| Meuble | Ce qu'il cherche |
|---|---|
| Canapé, vieux canapé | Dos au mur, face à une table basse, une table ou la scène |
| Fauteuil, vieux fauteuil | Face à une table basse ou une table (dos au mur à défaut) |
| Chaise | Face à sa table (ou un bureau, une table basse) |
| Tabouret | Face au bar |
| Lit, vieux lit | Tête de lit contre le mur |
| Arrière-bar | Dos au mur, face au bar |
| Bar, comptoir d'accueil | Tourné vers la salle, avec une bande libre derrière (de 0,6 à 2,6 m) pour le barman ou la réceptionniste, jamais collé au mur |
| Douche | Dos au mur ; la porte s'ouvre toujours sur la pièce |
| Armoire, étagères, casiers, frigo, vitrine, bureau, vestiaire, porte-manteau, WC, urinoir, lavabo, miroir, néon, applique, tableau, affiches | Dos au mur |

- **Portes** : rien ne s'adosse contre une porte (un canapé devant une porte se tourne autrement).
- **Sans raison claire** : au milieu d'une pièce vide, par exemple, le jeu ne décide rien et garde l'orientation actuelle.
- **Personnel, plantes, lampes, tapis** : ils ne sont pas concernés.

## Garder la main

- **`R`** tourne l'objet d'un quart de tour à partir de l'orientation affichée. L'orientation devient **manuelle** : le jeu ne la change plus pendant cette pose.
- **`A`** rend l'orientation au jeu.
- **Rappel** : la barre du haut indique « orientation auto » ou « orientation manuelle ».
- **Réinitialisation** : choisir un autre objet dans le catalogue repasse automatiquement en orientation auto.
- **Objet déjà posé** : le bouton « Tourner » de son panneau le tourne toujours d'un quart de tour, comme avant.

## Vérifié par les tests

- **Au mur** : un canapé contre un mur lui tourne le dos, quel que soit le mur ; un lit met sa tête de lit contre le mur.
- **Face à quelque chose** : une chaise fait face à sa table (vérifié de deux côtés), un tabouret fait face au bar.
- **Comptoir** : il fait face à la salle en gardant la place derrière, et n'est jamais plaqué contre le mur.
- **Portes** : un canapé ne s'adosse pas à une porte.
- **Pièce vide** : au milieu, rien n'est décidé.
- **En jeu** : la pose démarre en orientation automatique, `R` passe en manuel et le jeu ne la change plus, `A` revient à l'automatique.

## Aperçu

`Apercus-V42/orientation-auto.png` : une pièce meublée uniquement avec l'orientation automatique, sans aucune rotation à la main.
