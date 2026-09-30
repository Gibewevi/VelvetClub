# V7 — comparaison avec l'artwork de référence

La V6 était lisible et mate, mais son éclairage général dominait les sources locales. La V7 conserve la simplicité low-poly et l'interface existante, tout en donnant davantage de rôle aux lampes et aux néons. Les ajustements ci-dessous s'appliquent également aux aménagements sauvegardés.

| Aspect | Limite observée en V6 | Lecture de la référence | Ajustement réalisé en V7 |
|---|---|---|---|
| Fenêtres | Montants métalliques sur toute la hauteur du mur, meneau central très présent. | Ouvertures immédiatement lisibles au sein de murs simples. | Suppression des colonnes métalliques et du meneau ; encadrement fin anthracite limité au vitrage, allège et linteau en maçonnerie. Aucune dorure. |
| Éclairage | Lumière assez uniforme ; bougies peu perceptibles et sources colorées parfois gênées par leur propre géométrie. | Alternance de lumière ambre près des lampes et rose près du bar ou des néons, sur un fond violet diffus. | Lumière principale réduite de 1,10 à 0,88 et remplissage de 0,30 à 0,25, ambiance maintenue à 0,65. Bougies portées de 0,2 à 2,4 et lampes de 1,8 à 4,0 avant le facteur commun de 0,85 ; bar et néons renforcés. Les meshes émissifs ne projettent plus d'ombre ; la lumière de la piste est déplacée hors du poteau. |
| Ombres | Les objets semblaient parfois peu ancrés ; les tubes pouvaient masquer leur propre lumière. | Ombres de contact visibles sous le mobilier, transitions douces ailleurs. | Occlusion ambiante plus resserrée : rayon 0,50 → 0,38, intensité 0,55 → 0,80. Ombres architecturales conservées, sources émissives exclues de la projection d'ombres. |
| Reflets | Sol déjà mat depuis la V6. | Quelques rehauts brillants dans l'artwork, secondaires face aux couleurs et aux volumes. | Sol toujours sans reflets : SSR désactivé, spécularité nulle et rugosité maximale. Les rehauts de la référence ne sont volontairement pas reproduits, conformément à la demande d'un éclairage diffus. |
| Contrastes | Piste rose très uniforme ; répartition des valeurs peu hiérarchisée. | Surfaces calmes autour de points lumineux distincts, avec des noirs colorés plutôt que des zones illisibles. | Plateau de piste assombri, éclairage local mieux différencié, fond extérieur légèrement éclairci. L'ambiance générale reste suffisante pour lire les pièces sans lampe. |
| Matériaux | Matières cohérentes mais sol public parcouru de lignes régulières très visibles. | Grandes surfaces simples et faibles variations de teinte, qui laissent lire les modèles low-poly. | Dalles carrées aux nuances discrètes dans l'espace public ; joints moins contrastés ailleurs. Les matériaux restent mats, sans textures photoréalistes. |
| Ambiance | Aspect de maquette assez uniforme, peu de chaleur localisée. | Mélange de prune, ambre et rose, soutenu par de nombreuses lampes et une décoration dense. | Rééquilibrage des seules sources existantes et halos modérés. Aucun changement de l'agencement, de l'UI, des règles de construction ou de la sauvegarde. |

Les valeurs d'éclairage sont des réglages du moteur, pas des mesures photométriques. Le traitement de luminosité et la proximité des objets influencent leur effet à l'écran.

## Écarts qui restent

L'artwork comporte davantage d'appliques murales, de décoration, de détails de mobilier et une composition différente. Le bâtiment de départ n'a pas été réaménagé et les sauvegardes du joueur ne reçoivent aucun nouvel objet imposé. L'éclairage seul ne peut donc pas reproduire exactement la densité ni tous les accents lumineux de la référence.

Les fenêtres restent volontairement plus sobres que certaines ouvertures de l'artwork. Les reflets du sol et les ornements dorés sont exclus pour respecter la direction retenue. La cible est une ambiance plus proche et cohérente avec les modèles existants, pas une reproduction à l'identique.

## Comparer les captures

Le rendu de départ se trouve dans `Apercus-V6/01-interface.png` et le rendu V7 dans `Apercus-V7/01-interface.png`, depuis le dossier `build` du projet. Comparer le même cadrage et le même mode nuit. Les captures des autres panneaux permettent aussi de vérifier que l'interface reste lisible.

Le contrôle `python tests/render_test.py build/Apercus-V7` vérifie l'absence de blocs de pixels et la différence jour / nuit ; il ne remplace pas la comparaison visuelle des ambiances.
