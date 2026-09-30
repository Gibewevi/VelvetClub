# Maison Velours — prototype PC V1

Jeu de construction et d'aménagement isométrique, natif Windows, développé avec Godot 4.5.1. Le jeu s'exécute hors ligne. Les ressources et le moteur sont intégrés à l'exécutable ; aucune installation de Godot n'est nécessaire pour jouer.

## Jouer

Ouvrir `build/MaisonVelours-V1.exe`. La scène démarre directement sur un établissement de **6 pièces, 218 m² et 47 objets**, entièrement modifiable. Un bouton `?` et la touche **F1** affichent toutes les commandes.

| Action | Commande |
|---|---|
| Sélectionner | `1`, puis cliquer le sol, un meuble ou une ouverture |
| Créer une pièce | `2`, choisir le type à gauche et cliquer-glisser sur le terrain |
| Redimensionner | Sélectionner la pièce, puis tirer une de ses quatre poignées dorées |
| Changer le type | Menu de la pièce sélectionnée, à droite |
| Installer une porte / fenêtre | `3` / `4`, puis cliquer un mur |
| Placer un meuble | Cliquer sa vignette dans la bibliothèque, puis dans une pièce |
| Déplacer un meuble | En sélection, glisser le meuble |
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

## Sauvegarde

Le jeu recharge automatiquement le dernier aménagement depuis :

`%APPDATA%\Godot\app_userdata\Maison Velours\maison_velours.json`

Un fichier `.bak` conserve la version précédente. L'écriture passe par un fichier temporaire. Une sauvegarde invalide ne remplace pas le modèle en mémoire. Le bouton de restauration du bâtiment initial demande confirmation et reste annulable pendant la session. L'historique d'annulation est conservé en mémoire uniquement.

## Contenu et limites de cette V1

- Les cinq fonctions : espace public, chambre, toilettes, réserve et personnel.
- Bibliothèque de 29 modèles procéduraux originaux : mobilier, décoration, éclairages et trois silhouettes adultes habillées, statiques et sans simulation.
- Caméra orthographique, trois modes de murs, éclairage jour / nuit et vignettes 3D du mobilier.
- Un étage, pièces rectangulaires, pas de toits ni de simulation économique, sociale ou d'exploitation.
- Portes et fenêtres occupent un segment de 1 m ; les meubles utilisent des empreintes rectangulaires. Les lampes de chevet sont des ensembles autonomes avec support ; les objets ne se superposent pas.
- Le terrain périphérique reste volontairement sobre. Les éclairages n'utilisent pas de ray tracing ni d'effets lourds.
- Le prototype est une base desktop autonome ; la publication Steam, Steamworks, les succès et Steam Cloud ne sont pas intégrés.

## Sources et architecture

Ouvrir `game/project.godot` avec Godot **4.5.1**.

| Fichier | Responsabilité |
|---|---|
| `game/scripts/model.gd` | Données, contraintes de construction, murs uniques, sauvegardes validées et bâtiment de départ |
| `game/scripts/catalog.gd` | Types de pièces, catalogue, dimensions et filtres |
| `game/scripts/assets.gd` | Géométrie low-poly originale, matériaux et éclairages réutilisables |
| `game/scripts/world.gd` | Scène 3D, sélection, caméra, murs en coupe et aperçus |
| `game/scripts/main.gd` | Interface native, commandes, historique et fichiers locaux |
| `game/tests/model_test.gd` | Tests des règles, sérialisation et catalogue |

Le bâtiment initial utilise exclusivement les mêmes méthodes d'ajout que l'éditeur. Le modèle de données n'est pas lié au rendu ; il peut évoluer vers un système de commandes plus complet, une interface différente ou une simulation future. Aucune dépendance web, aucun serveur et aucune bibliothèque d'assets externe.

## Construire et vérifier

Les outils de développement téléchargés sont locaux à `.tools/`. Le script `Build.ps1` utilise le moteur et les modèles d'export présents dans ce dossier. Sur un autre poste, installer Godot 4.5.1 et ses modèles Windows, puis renseigner les chemins de modèles personnalisés dans `game/export_presets.cfg`, ou retirer ces chemins pour utiliser les modèles installés par Godot.

```powershell
.\Build.ps1
```

Ce script exécute les tests du modèle, le test de sauvegarde/annulation de la scène, puis exporte `build/MaisonVelours-V1.exe` avec ses ressources embarquées. Les journaux de développement vont dans `tests/artifacts/`. Les tests emploient un répertoire de données séparé et ne modifient pas la sauvegarde du joueur.

Windows 64 bits et une carte compatible OpenGL 3.3 sont requis. Le rendu a été vérifié sur le poste de développement avec une NVIDIA RTX 3090 ; aucune performance minimale sur d'autres machines n'est garantie à ce stade.

## Crédits

Code et modèles procéduraux créés pour ce projet. L'image fournie sert de référence artistique, sans être embarquée. Moteur Godot sous licence MIT ; voir `build/LICENCES.txt` et https://godotengine.org/license/.

