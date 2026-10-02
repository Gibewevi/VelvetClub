# Construction — club en pixel art

Jeu natif Windows de gestion d'un club, en isométrique et en vrai pixel art rétro. Il est développé avec Godot 4.5.1. Le moteur et les ressources sont intégrés à l'exécutable : rien à installer pour jouer.

## Jouer

Téléchargez la dernière version dans les **[Releases](https://github.com/Gibewevi/VelvetClub/releases)** : elle contient l'archive Windows, avec l'exécutable et son guide. Chaque version y a ses notes : ce qui change, comment s'en servir, ce qui a été vérifié. **L'historique des versions se trouve uniquement là.**

La partie est enregistrée dans `%APPDATA%\Godot\app_userdata\Construction\pixel_club.json`, avec une copie de secours `.bak`. Le jeu note aussi sa fluidité dans `perf.log`, au même endroit.

## En bref

- On reprend un petit local vétuste, que l'on rénove et agrandit.
- On trace des pièces : elles se construisent sur un chantier avec des ouvriers. Tracer depuis le mur ou le sol d'une pièce l'agrandit.
- On meuble les pièces (orientation automatique, livraison par camionnette), puis on embauche le personnel (accueil, bar, ménage, technique, escorts).
- On ouvre le club. Les clients font la queue, paient à l'accueil, boivent, dansent, rencontrent les escorts et ont des besoins sanitaires. Leur satisfaction fait la réputation.
- Météo, plannings, parkings et fiches de personnages complètent la gestion.

| Action | Commande |
|---|---|
| Dock | Sélection, Construire, Mobilier, Personnel, Clients, Menu |
| Ouvrir / fermer le club | Bouton sous l'horloge ou `O` |
| Temps | `Espace` pause · `1` normal · `2` accéléré |
| Pièce | `T`, puis glisser (depuis un mur ou le sol d'une pièce : agrandissement) |
| Porte / fenêtre | `P` / `F`, puis cliquer un mur |
| Parking | `K` : places · Construire → Allée |
| Mobilier | `B` · `Maj` + clic : en série · `R` tourner à la main · `A` orientation automatique |
| Déplacer / copier / supprimer | Glisser · `Ctrl + D` · `Suppr` |
| Annuler / rétablir | `Ctrl + Z` / `Ctrl + Y` (l'argent suit) |
| Vue | Molette : zoom · clic droit ou milieu + glisser · `W` murs · `G` grille · `F11` plein écran |
| Enregistrer / aide | `Ctrl + S` / `F1` |

## Développement

Ouvrir `pixel/project.godot` dans Godot 4.5.1 (Godot et les modèles d'export sont attendus dans `.tools/`).

`./Build.ps1` effectue, dans l'ordre :

1. **Art** : régénère tout le pixel art (`tools/pixelart/build_art.py`, avec Python, numpy et Pillow).
2. **Import** : importe le projet.
3. **Tests** :
   - les scripts de `pixel/tests/` (modèle, art, parkings, lits, livraisons, calendrier, météo, besoins, sanitaires, plomberie, prestations, profils…) ;
   - la scène (`--smoke-test`) et une nuit simulée (`--sim-test`) ;
   - l'interface dans une vraie fenêtre (`--ui-test`). Ce dernier test se perturbe si la souris bouge pendant qu'il tourne.
4. **Export** : produit l'exécutable dans `build/`.

Les journaux de tests sont dans `tests/artifacts/`.

Outils, à passer après `--` sur la ligne de commande :

- `--capture=<png> --zoom=3 --focus=x,z --sim-seconds=N --pause` : capture reproductible, sans lire ni écrire de sauvegarde. Il existe des mises en scène `--setup=…`, par exemple `site`, `extension`, `dust`, `parking`, `depth`.
- `--profile-save=<copie d'une sauvegarde> --profile-seconds=N [--profile-drawers] [--profile-rain=1.0] [--profile-hour=20] [--profile-trace=<fichier>]` : rejoue une partie sans l'écrire et mesure chaque système toutes les 5 s.

### Sources principales

| Source | Rôle |
|---|---|
| `pixel/scripts/model.gd`, `room_shape.gd` | Pièces (y compris agrandies en L ou en T), objets, ouvertures, parkings, règles, coût, sauvegarde |
| `pixel/scripts/sim.gd`, `nav.gd` | Simulation du club ; navigation par les portes, zones accessibles |
| `pixel/scripts/world_view.gd` | Rendu : sols, murs, tri de profondeur, rue, pluie, petits objets, poussière de pose |
| `pixel/scripts/site_plan.gd`, `construction.gd`, `site_worker.gd` | Chantiers : progression logique, affichage, ouvriers |
| `pixel/scripts/deliveries.gd` et `delivery_*.gd` | Commandes, camionnette, livreurs, fumée des pneus |
| `pixel/scripts/hud.gd`, `ui_kit.gd`, `editors.gd` | Interface rétro pixel art |
| `pixel/scripts/main.gd`, `prof.gd` | Caméra, outils, historique, sauvegarde, garde-fou de fluidité, tests intégrés, profilage |
| `tools/pixelart/` | Génération de tout le pixel art à la résolution native (personnages, mobilier, tuiles, rue, livraison, chantier, interface) |

## Du vrai pixel art

- **Grille** : une case de 1 m mesure 32 × 16 px, et 1 m de hauteur vaut 24 px.
- **Personnages** : frames de 32 × 48 px.
- **Dessin et affichage** : tout est dessiné à la résolution finale, puis agrandi ×1 à ×4 en plus-proche-voisin, sans filtrage ni flou.
- **Couleurs** : sols, murs et personnages stockent des index de palette, recolorés en direct.

## Crédits

Le code, les sprites, les tuiles et l'interface ont été créés pour le projet. L'artwork de référence n'est pas embarqué. Godot est sous licence MIT (`build/LICENCES.txt`, `build/GODOT-TIERS.txt`) et Pixelify Sans sous SIL OFL (`build/PIXELIFY-OFL.txt`). Le jeu ne télécharge aucune ressource.
