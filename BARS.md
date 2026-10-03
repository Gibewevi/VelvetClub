# Bars et alcool

Dans **Mobilier → Espace public**, choisir un comptoir droit, un module néon, un comptoir arrondi aux extrémités, le petit L Grenat ou le Prestige. Les modules juxtaposés peuvent partager un barman proche. Il n'y a pas de bar en U.

Placer un meuble à bouteilles dans la même salle, à moins de 6 m du comptoir, et laisser accessibles son devant et le poste du barman.

| Meuble | Capacité | Prix |
|---|---:|---:|
| Meuble compact | 4 bouteilles | 480 $ |
| Double arche Rubis | 5 bouteilles | 900 $ |
| Arche Cœur | 10 bouteilles | 1 650 $ |
| Bibliothèque Prestige | 12 bouteilles | 2 400 $ |

Les nouveaux meubles arrivent **vides**. Sélectionner le comptoir ou l'étagère, puis **Commander un carton · 96 $**. Placer ce carton dans une **Réserve** reliée par une porte ; la camionnette habituelle le livre. Chaque carton contient 12 bouteilles, soit 48 verres. Une bouteille fournit quatre consommations et disparaît quand elle est vide. La verrerie reste en place.

Lorsque le stock descend à 25 % ou moins, le barman quitte son poste, va chercher un carton, le porte au meuble, le pose et installe les bouteilles une par une. Pendant ce trajet il ne sert pas. Sans étagère approvisionnée, barman présent ou accès à la réserve, aucune boisson alcoolisée n'est vendue. Le personnel planifié peut réapprovisionner pendant la fermeture.

Les comptoirs supérieurs attirent davantage de commandes et favorisent les alcools premium, facturés à **+65 %** du tarif de boisson choisi dans **Tarifs**. Les clients respectent leur budget. La sélection du bar affiche les verres restants et les ruptures ; la fiche du client indique sa dernière commande. Les achats d'alcool figurent séparément dans le bilan financier.

Les quantités sont sauvegardées. Annuler/rétablir une construction ne recrée pas de bouteilles consommées. Lors d'un chargement, le contenu d'un carton encore transporté retourne en réserve. Les anciennes étagères sans quantité sauvegardée reçoivent un stock initial une seule fois.

Les bouteilles des étagères ont désormais un gabarit proche de celles des comptoirs : col, épaules et étiquette large, sans petits reflets dispersés. Les tablettes sont moins nombreuses et plus espacées. Une bouteille visible correspond toujours à quatre consommations. Un petit meuble ne prend que la partie d'un carton qui tient dedans ; le reste demeure en réserve. Au chargement d'une ancienne partie, le stock qui dépasse la nouvelle capacité est remboursé une seule fois au prix d'achat (8 $ par bouteille, au prorata des consommations restantes), dans « Reventes et remboursements ».

## Sources visuelles

Les huit meubles ont été préparés avec le skill **imagegen**, via l'outil intégré, à partir des références du joueur et de gabarits isométriques en quatre orientations. Les [prompts](tools/pixelart/sources/bars/prompts.json), les peintures approuvées et leurs versions natives se trouvent dans `tools/pixelart/sources/bars/`. `prepare_bars.py` les adapte à la grille native ; `pa_bars.py` compose les bouteilles et les variantes de stock. Les sprites du jeu sont dans `pixel/art/furniture/`.

Les versions finales privilégient les aplats et des groupes de pixels francs, avec une palette commune de 30 couleurs. Les petites textures, veinures et reflets dispersés ont été supprimés. Les bouteilles utilisent des tons regroupés et des étiquettes sobres ; les néons ont un éclairage constant et un halo doux, sans animation de scintillement.

La finition V92 conserve ces peintures et leurs accessoires. `pa_bar_polish.py` régularise uniquement les portions droites du liseré du plateau, retire les petits fragments détachés et aligne les bouteilles sur les tablettes peintes. Les bouteilles ont une silhouette simple, sans reflets dispersés. Les formes, arches, cœurs, plantes, lampes, dimensions et points d'ancrage restent ceux des modèles validés ; aucune peinture de remplacement n'est utilisée.

Captures de contrôle : `--capture=<png> --setup=bars --focus=0,-3 --zoom=2 --pause` ; pour le réapprovisionnement, `--setup=bar-fill --stock-state=stock_carry` ou `stock_fill`.
