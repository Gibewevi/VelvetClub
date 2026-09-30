# Construction V17 — Refonte en pixel art

La V17 abandonne complètement la 3D. Le jeu devient un **jeu de gestion isométrique en vrai pixel art**, calqué sur l'artwork de référence : rendu, proportions, personnages, décors, éclairage, couleurs et lisibilité.

Exécutable : `Construction-V17-PixelArt.exe`, seul, sans installation.

## Ce qui change à l'écran

- **Grille pixel unique** : tuiles de sol de 32 × 16 px (1 m), personnages en frames de 32 × 48 px, mobilier dimensionné sur la même grille.
- **Dessiné à la taille réelle** : chaque sprite est dessiné directement à cette résolution, puis seulement agrandi ×2 (par défaut), ×3 ou ×4 en plus-proche-voisin. Rien n'est calculé en grand puis réduit, rien n'est filtré ni flouté.
- **Murs en coupe comme sur l'artwork** : murs du fond en briques avec capuchons crème, murs de devant coupés bas avec poteaux sombres. `W` abaisse tous les murs.
- **Ambiance de nuit** : appliques, lampes de chevet, bougies, néons en cœurs et scène rose éclairent le club par des halos pixel art. Dehors, la rue sombre est bordée de lampadaires, d'arbres, de bacs, de potelets et d'un tapis rouge avec cordons devant l'entrée.
- **Personnages** : escorts en lingerie, body ou robe ; réceptionniste en tailleur ; barman en gilet ; agent de sécurité avec casquette à visière et lunettes noires ; agent d'entretien en combinaison et casquette ; femme de ménage en tenue de soubrette ; clients variés. Tous marchent, s'assoient, dansent, servent ou passent la serpillière, de face comme de dos.
- **Interface calquée sur l'artwork** :
  - en haut à gauche : argent, heure et étoiles de réputation ;
  - en haut à droite : clients présents, salons privés occupés et satisfaction ;
  - en bas : Construire, Pièces, Personnel, Clients, Décoration, Services, Rapports ;
  - en bas à droite : vue d'ensemble, aide et options.

## Réception et urinoirs (demande précédente, intégrée)

- **Réception de 15 m²** directement sur la rue. Elle sert de caisse (droit d'entrée), de contrôle d'accès (agent de sécurité) et de vestiaire (portant et casiers). Elle comprend un comptoir avec sa chaise, un miroir, une plante et une porte donnant directement sur le salon-bar.
- **Urinoirs** : trois dans les WC, avec parois de séparation, à côté des deux WC et du lavabo. Ils sont aussi disponibles dans Décoration → WC.

## Le club vit

Le club ouvre de 20:00 à 04:00.

- Les clients font la queue dehors, paient à la réception, puis vont au bar, au salon, devant la scène, aux WC ou en salon privé avec une escort.
- Au-dessus des têtes, `$` signale une dépense et un cœur un moment au salon ou en privé.
- Le barman, la réceptionniste, la sécurité et le ménage suivent chacun leur rôle.
- Le **Rapport de la nuit** donne les recettes, les salaires, la satisfaction et la réputation.
- **Services** règle les tarifs ; **Personnel** embauche et personnalise ; **Clients** suit chaque client.

## Conservé de la version 3D

- tracé des pièces et poignées de redimensionnement ;
- portes et fenêtres sur les segments de mur ;
- mobilier au pas de 25 cm, rotation, déplacement, copie, suppression ;
- revêtements de sol et de murs, avec une couleur libre ;
- personnalisation des personnages (peau, cheveux, tenue, coiffure, visage ou barbe, lunettes) ;
- annulation et rétablissement, sauvegarde automatique.

**Options → Importer le bâtiment 3D** reprend l'aménagement de la version précédente.

## Aperçus (dossier `Apercus-V17`)

| Fichier | Contenu |
|---|---|
| `01-club-vue-x2.png` | Vue d'ensemble ×2 pendant une soirée |
| `02-salon-bar-x3.png`, `06-gros-plan-x4.png` | Salon, bar et scène de près |
| `03-reception-entree-x3.png` | Réception, file d'attente et tapis rouge |
| `04-chambres-x3.png` | Salons privés occupés |
| `05-wc-reserve-x3.png` | WC avec urinoirs, réserve, pièce du personnel |
| `07-murs-coupes-x2.png` | Mode murs coupés (`W`) |
| `sprites-*.png` | Sprites natifs agrandis en nearest : personnages 32 × 48, équipe ×6, mobilier ×3, sols 32 × 16 ×4 |
| `ui-*.png` | Panneaux de l'interface, éditeurs, sélection |

## Limites connues

- Un seul étage.
- Simulation volontairement simple : pas de compétences d'employés, d'événements ni de son.
- Les personnages n'ont que deux vues dessinées (face et dos), les deux autres étant obtenues en miroir.
- Les murs hauts du fond peuvent masquer un personnage placé juste derrière : `W` les abaisse.
