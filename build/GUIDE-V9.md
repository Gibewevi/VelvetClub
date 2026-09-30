# Construction — prototype PC V9 — Ombrage lissé

Jeu de construction et d'aménagement isométrique, natif Windows, développé avec Godot 4.5.1. Le jeu s'exécute hors ligne. Les ressources et le moteur sont intégrés à l'exécutable ; aucune installation de Godot n'est nécessaire pour jouer.

## Jouer

Ouvrir `build/Construction-V9-Lisse.exe` depuis le projet, ou `Construction-V9-Lisse.exe` dans le dossier de l'archive Windows extraite. La scène démarre directement sur un établissement de **6 pièces, 218 m² et 47 objets**, entièrement modifiable. Si une sauvegarde existe, le jeu reprend cet aménagement. Le menu et la touche **F1** affichent toutes les commandes.

| Action | Commande |
|---|---|
| Sélectionner | `1`, puis cliquer le sol, un meuble ou une ouverture |
| Créer une pièce | `2`, choisir le type à gauche et cliquer-glisser sur le terrain |
| Redimensionner | Sélectionner la pièce, puis tirer une de ses quatre poignées roses |
| Changer le type | Menu de la pièce sélectionnée, à droite |
| Installer une porte / fenêtre | `3` / `4`, puis cliquer un mur |
| Placer un meuble | `B`, choisir sa vignette, puis cliquer dans une pièce ; maintenir `Maj` pour répéter |
| Déplacer un meuble | En sélection, glisser le meuble ou cliquer Déplacer dans sa fiche |
| Dupliquer un meuble | `Ctrl + D` ou Copier dans sa fiche |
| Ouvrir le plan / les options de vue | `P` / `V` |
| Tourner le meuble | `R`, avant placement ou sur le meuble sélectionné |
| Supprimer / reboucher | `Suppr` sur la sélection |
| Annuler / rétablir | `Ctrl + Z` / `Ctrl + Y` |
| Quitter le placement | `Échap` |
| Zoomer | Molette |
| Déplacer la caméra | Clic droit ou milieu + glisser |
| Tourner la caméra | `Q` / `E` ou boutons Vue |
| Recentrer | `Origine` ou bouton Centrer |
| Grille | `G` |
| Plein écran | `F11` |
| Enregistrer | `Ctrl + S` ; sauvegarde automatique après modification |

Les pièces se raccordent bord à bord. Un segment de mur partagé n'est créé qu'une seule fois, même lorsqu'une ouverture y est installée. La grille architecturale fait 1 m ; les meubles se déplacent par pas de 25 cm. Les pièces mesurent au minimum 2 × 2 m sur un terrain de 48 × 48 m.

Un aperçu vert valide un placement ; rouge signale un obstacle. Les meubles doivent tenir entièrement dans une pièce et ne pas se chevaucher. Une réduction de pièce est refusée si elle empiète sur un meuble. La suppression d'une pièce retire son mobilier, et les ouvertures sans mur sont nettoyées ; l'annulation restaure l'ensemble.

## Ombrage lissé V9

Les surfaces courbes utilisent désormais un ombrage lissé : pots, bouteilles, vasques, pieds profilés et anneaux ne présentent plus de bandes d'éclairage distinctes entre chaque face. Les feuilles sont lissées dans le sens de leur longueur, en conservant leur nervure. Les coussins et volumes rembourrés disposaient déjà de normales lissées.

Le lissage conserve les arêtes franches, les surfaces planes et les ruptures de forme marquées. Il agit sur les normales d'éclairage : les positions, les dimensions et le nombre de triangles des modèles V8 restent identiques. Il s'applique au mobilier déjà placé et aux vignettes de la bibliothèque. Les matériaux restent mats et l'éclairage diffus.

## Mobilier low-poly

Les objets gagnent en volume et en finition : arêtes chanfreinées, assises rembourrées, dossiers travaillés, tables profilées et bar détaillé. Les chambres disposent d'un lit capitonné, d'un matelas épais, de coussins arrondis et de meubles à tiroirs. Les WC et lavabos ont de vrais creux ; les lampes des abat-jour ouverts. Portes, poignées, étagères et planches rendent les rangements plus crédibles. Les plantes ont des feuilles courbées et nervurées ; les silhouettes humaines sont mieux articulées et proportionnées.

Ces détails restent géométriques et stylisés. Les gabarits de placement sont conservés : les objets déjà sauvegardés bénéficient des nouveaux modèles sans changer d'emplacement. L'interface, les matériaux mats et l'éclairage diffus de la V7 sont conservés.

Les **29 modèles** sont contrôlés automatiquement. Un exemplaire de chacun représente au total **70 220 triangles et 598 instances de maillage** ; il s'agit d'un inventaire du catalogue, pas du nombre d'appels de rendu d'une scène ni d'une garantie de performance. Les maillages identiques sont partagés en mémoire. Les chanfreins simples utilisent 44 triangles par volume et les biseaux rembourrés 300 ; les objets arrondis et creux utilisent des profils tournés avec un nombre de segments maîtrisé.

La planche de détails est disponible dans `build/Apercus-V9/10-mobilier-lisse.png`.

## Rendu et ambiance

La pixelisation est temporairement désactivée, y compris lorsqu'un ancien réglage V3 est enregistré. Le shader reste dans les sources pour pouvoir le retravailler ultérieurement. La scène et les vignettes sont rendues en 3D nette, avec anticrénelage.

Les fenêtres retrouvent une construction simple : allège et linteau de maçonnerie, vitrage uni et cadre fin anthracite limité à l'ouverture. Les montants métalliques décoratifs sur toute la hauteur et le meneau central sont supprimés. Le vitrage disparaît naturellement lorsque le mur est coupé sous l'allège.

L'éclairage général est moins dominant pour laisser davantage de place aux lumières locales : bougies ambrées, lampes chaudes, bar et néons roses. L'ambiance diffuse reste présente dans les pièces sans luminaire. Les éléments émissifs ne projettent plus d'ombre sur leur propre source ; les murs et le mobilier continuent de recevoir et de projeter leurs ombres. La lumière de la piste est décalée hors du poteau, et son plateau rose est moins lumineux. Les ombres de contact sont resserrées pour mieux ancrer les objets sans noircir l'ensemble.

Les sols, murs et meubles restent mats : rugosité maximale, aucun reflet spéculaire et aucun reflet d'écran (SSR). Le sol public utilise de grandes dalles aux nuances discrètes, avec des joints sobres. Les miroirs restent des éléments stylisés. Les émissions sont plafonnées et la lueur est limitée aux sources lumineuses ; aucun bloom général n'est ajouté. Le mode jour reste disponible.

Ces changements s'appliquent aussi aux fenêtres, pièces et meubles déjà sauvegardés, sans modifier leur emplacement. L'organisation de l'UI est conservée, avec sa palette prune / rose, ses contours fins et sa typographie lissée. Les sauvegardes des versions précédentes restent compatibles.

**Vue → Ambiance → Halos discrets** permet d'activer ou de désactiver la légère lueur autour des luminaires pendant la session. L'option de reflets a été retirée pour conserver la direction artistique mate.

L'artwork guide les proportions, la palette et l'ambiance ; son agencement et sa densité décorative ne sont pas reproduits à l'identique. Tous les objets restent librement modifiables dans l'éditeur.

## Interface

La scène est dégagée au lancement. La barre inférieure ouvre un seul panneau à la fois : Construire, Mobilier, Plan, Vue ou Menu. La fiche contextuelle apparaît uniquement pour la sélection active. Le filtre Cibler distingue objets, pièces et ouvertures ; le survol indique la cible.

La bibliothèque propose une recherche, des filtres et des vignettes. Elle se ferme au choix d'un objet. Le placement est unique par défaut ; Maj permet de placer en série. Échap annule le placement, libère la recherche et ferme les panneaux. Les notifications disparaissent après quelques secondes. Relâcher un déplacement au-dessus de l'interface annule le geste.

## Sauvegarde

Le jeu recharge automatiquement le dernier aménagement depuis :

`%APPDATA%\Godot\app_userdata\Construction\building.json`

Au premier lancement, une sauvegarde de la V1 est reprise si aucune sauvegarde V2 n'existe. Le fichier V1 reste intact.

Un fichier `.bak` conserve la version précédente. L'écriture passe par un fichier temporaire. Une sauvegarde invalide ne remplace pas le modèle en mémoire. Le bouton de restauration du bâtiment initial demande confirmation et reste annulable pendant la session. L'historique d'annulation est conservé en mémoire uniquement.

## Contenu et limites du périmètre construction V1

- Les cinq fonctions : espace public, chambre, toilettes, réserve et personnel.
- Bibliothèque de 29 modèles procéduraux originaux : mobilier, décoration, éclairages et trois silhouettes adultes habillées, statiques et sans simulation.
- Caméra orthographique, trois modes de murs, éclairage jour / nuit et vignettes 3D du mobilier.
- Un étage, pièces rectangulaires, pas de toits ni de simulation économique, sociale ou d'exploitation.
- Portes et fenêtres occupent un segment de 1 m ; les meubles utilisent des empreintes rectangulaires. Les lampes de chevet sont des ensembles autonomes avec support ; les objets ne se superposent pas.
- Le terrain périphérique reste volontairement sobre. Les éclairages utilisent des effets de rendu temps réel, sans ray tracing.
- Le prototype est une base desktop autonome ; la publication Steam, Steamworks, les succès et Steam Cloud ne sont pas intégrés.

## Sources et architecture

Ouvrir `game/project.godot` avec Godot **4.5.1**.

| Fichier | Responsabilité |
|---|---|
| `game/scripts/model.gd` | Données, contraintes de construction, murs uniques, sauvegardes validées et bâtiment de départ |
| `game/scripts/catalog.gd` | Types de pièces, catalogue, dimensions et filtres |
| `game/scripts/assets.gd` | Fabrique des objets, matériaux mats et éclairages réutilisables |
| `game/scripts/asset_geometry.gd` | Chanfreins, volumes rembourrés, profils tournés, anneaux, feuilles et cache de maillages |
| `game/scripts/assets_public.gd` | Mobilier public, assises, bar, tables et piste de danse |
| `game/scripts/assets_rooms.gd` | Chambres, sanitaires, lampes et rangements |
| `game/scripts/world.gd` | Scène 3D, sélection, caméra, murs en coupe et aperçus |
| `game/scripts/main.gd` | Interface native, panneaux contextuels, commandes, historique et fichiers locaux |
| `game/scripts/editor_icons.gd` | Pictogrammes dessinés sur une grille de pixels |
| `game/scripts/retro_render.gd` | Ancien filtre rétro, temporairement suspendu |
| `game/shaders/retro_screen.gdshader` | Pixelisation, réduction des couleurs et tramage de la scène |
| `game/tests/model_test.gd` | Tests des règles, sérialisation et catalogue |
| `game/tests/assets_preview.gd` | Contrôles géométriques du catalogue et planche de détails du mobilier |

Le bâtiment initial utilise exclusivement les mêmes méthodes d'ajout que l'éditeur. Le modèle de données n'est pas lié au rendu ; il peut évoluer vers un système de commandes plus complet, une interface différente ou une simulation future. Aucune dépendance web, aucun serveur et aucune bibliothèque d'assets externe.

## Construire et vérifier

Les outils de développement téléchargés sont locaux à `.tools/`. Le script `Build.ps1` utilise le moteur et les modèles d'export présents dans ce dossier. Sur un autre poste, installer Godot 4.5.1 et ses modèles Windows, puis renseigner les chemins de modèles personnalisés dans `game/export_presets.cfg`, ou retirer ces chemins pour utiliser les modèles installés par Godot.

```powershell
.\Build.ps1
```

Ce script exécute les tests du modèle, les contrôles géométriques du catalogue sans affichage, le test de sauvegarde/annulation de la scène et les tests des panneaux, interactions, accents, suspension du filtre et contrôles d'ambiance, puis exporte `build/Construction-V9-Lisse.exe` avec ses ressources embarquées. Les journaux de développement vont dans `tests/artifacts/`. Les tests emploient un répertoire de données séparé et ne modifient pas la sauvegarde du joueur. `python tests/render_test.py build/Apercus-V9` vérifie sur les captures natives que la scène n'est plus pixelisée et que le mode jour modifie son éclairage. Cette vérification technique ne mesure pas la fidélité artistique à la référence ; les captures doivent également être examinées visuellement.

Windows 64 bits et une carte compatible Vulkan sont requis pour le rendu Forward+ utilisé par défaut. Le premier lancement peut prendre plus de temps pendant la compilation des effets. Le rendu a été vérifié sur le poste de développement avec une NVIDIA RTX 3090 ; aucune performance minimale sur d'autres machines n'est garantie à ce stade.

## Crédits

Code et modèles procéduraux créés pour ce projet. L'image fournie sert de référence artistique, sans être embarquée. Moteur Godot sous licence MIT ; voir `build/LICENCES.txt` et https://godotengine.org/license/.

Police Pixelify Sans conservée avec les sources du filtre V3 (l'UI actuelle utilise la police intégrée à Godot) : Copyright 2021 The Pixelify Sans Project Authors, sous SIL Open Font License 1.1. Licence complète dans `game/fonts/OFL.txt` et `build/PIXELIFY-OFL.txt`. Aucune police ni ressource n'est téléchargée pendant le jeu.

