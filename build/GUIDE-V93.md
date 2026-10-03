# Construction V93 — Bouteilles

Exécutable : `Construction-V93-Bouteilles.exe`. Il utilise la même sauvegarde que les versions précédentes.

Cette version regroupe les V91 à V93, qui n'avaient pas été publiées, et un correctif du personnel. Le détail des bars est dans `BARS.md`.

## Des bars avec un vrai stock d'alcool (V91)

- **Les comptoirs** (rayon Mobilier → Espace public) : comptoir droit, module néon, comptoir arrondi, petit L Grenat ou Prestige. Des modules côte à côte peuvent partager un barman.
- **Les meubles à bouteilles** se placent dans la même salle, à moins de 6 m du comptoir. Ils arrivent **vides**.
- **Commander un carton** (96 $, depuis le comptoir ou l'étagère) : il se pose dans une Réserve reliée par une porte et la camionnette le livre.
  - Un carton contient 12 bouteilles.
  - Une bouteille fait quatre verres et disparaît une fois vide.
- **Quand le stock tombe à 25 %**, le barman va chercher un carton en réserve et remplit le meuble bouteille par bouteille. Pendant ce temps, il ne sert pas.
- **Sans bouteilles, sans barman ou sans accès à la réserve**, aucun alcool n'est vendu.
- **Les comptoirs haut de gamme** attirent plus de commandes et vendent des alcools premium, facturés 65 % plus cher.
- **Le bilan financier** affiche les achats d'alcool séparément.

## Bouteilles plus grandes, finition des bars (V92 et V93)

- Les étagères portent moins de bouteilles, mais plus grandes et mieux dessinées :

  | Meuble | Bouteilles |
  |---|---:|
  | Meuble compact | 4 |
  | Double arche Rubis | 5 |
  | Arche Cœur | 10 |
  | Bibliothèque Prestige | 12 |

- Une bouteille visible vaut toujours quatre verres. Un petit meuble ne prend que la part d'un carton qui tient dedans ; le reste reste en réserve.
- Une ancienne partie dont le stock dépasse la nouvelle capacité est remboursée une seule fois, au prix d'achat (8 $ par bouteille), dans « Reventes et remboursements ».
- Le liseré des plateaux est régularisé et les bouteilles sont posées sur les tablettes.

## Correctif : femme de ménage et technicien bloqués dans une chambre

Quand un couple occupait une chambre où se trouvait une femme de ménage ou un technicien, l'employé marchait sur place en vibrant jusqu'au départ du couple. Il hésitait à chaque image entre retourner à son poste et partir vers une autre tâche.

- Dans une chambre occupée, l'employé ne fait plus qu'en sortir. Il reprend son travail une fois dehors.
- Si son poste est dans cette chambre, il y attend sans bouger.
- Sur une copie de votre partie, les femmes de ménage les plus agitées passent de 245 à environ 30 changements de tâche sur le même rejeu.

## Vérifié

- Toutes les suites passent, avec le nouveau test « le personnel quitte une chambre occupée ».
- Le pixel art est celui du dépôt : la construction ne régénère plus les images, pour garder les retouches faites dans Aseprite.
