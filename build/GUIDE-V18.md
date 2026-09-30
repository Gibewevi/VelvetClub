# Construction V18 — Interface rétro en pixel art

Exécutable : `Construction-V18-UiRetro.exe`, seul, sans installation. Le jeu, le club et la sauvegarde sont ceux de la V17 ; seule l'interface change.

## L'interface des premières versions, redessinée en pixel art

La V18 reprend le style d'interface des versions 3D, mais dessiné au pixel près et agrandi ×2, comme le reste du jeu :

- **Fenêtres « old school »** anthracite et prune, à liseré fin, avec une barre de titre :
  - un filet rose en haut et un titre centré ;
  - un bouton de fermeture ;
  - une ombre portée pleine, sans flou ;
  - les dialogues (aide, personnalisation, revêtements, rapport de nuit, confirmation) se déplacent en tirant leur barre de titre.
- **Dock en bas de l'écran** avec icône et texte, comme avant : Sélection, Construire, Mobilier, Personnel, Clients, Services, Rapports, Menu.
- **Historique en haut à droite** : annuler, rétablir, enregistrer.
- **Fiche « Sélection »** dans une fenêtre à droite (déplacer, tourner, copier, supprimer, personnaliser).
- **Boutons biseautés** : liseré rose et fond prune quand ils sont actifs.
- **Icônes monochromes 10 × 10** : ce sont les icônes d'origine, complétées dans le même style pour les nouvelles fonctions (personnel, clients, services, rapports, argent, horloge, étoiles, salons privés, satisfaction).
- **Texte** : Pixelify Sans en 20 et 40 px, donc sur la grille de pixels de l'interface.

Le plan des pièces se trouve maintenant en bas de la fenêtre **Construire**. Les options de vue et de partie (zoom, murs, grille, plein écran, enregistrement, import 3D, nouveau club, aide, quitter) sont dans **Menu**.

## Nettoyage

L'ancien code 3D a été retiré du projet (dossier `game/` et scripts associés). Il a été envoyé dans la Corbeille de Windows et reste récupérable tant qu'elle n'est pas vidée. Les exécutables, archives et guides des versions précédentes restent dans `build/`. L'import de l'ancien bâtiment 3D reste disponible dans Menu.

## Aperçus (dossier `Apercus-V18`)

| Fichier | Contenu |
|---|---|
| `01-club-vue-x2.png` | Vue d'ensemble pendant une soirée |
| `02-salon-bar-x3.png`, `03-reception-entree-x3.png`, `04-chambres-x3.png` | Gros plans ×3 |
| `05-menu-fenetre.png` | Fenêtre Menu |
| `ui-02-panel-*.png` | Fenêtres du dock (Construire, Mobilier, Personnel, Clients, Services, Rapports, Menu) |
| `ui-02-help-window.png`, `ui-04-finishes.png`, `ui-05-appearance.png` | Dialogues déplaçables |
| `ui-03-selection.png` | Fiche de sélection |
| `sprites-*.png` | Sprites natifs agrandis en nearest |
