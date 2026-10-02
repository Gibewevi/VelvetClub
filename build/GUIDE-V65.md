# Construction V65 — Fenêtres de couleurs

Exécutable : `Construction-V65-Couleurs.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Le problème

Un joueur a vu le jeu se figer en cliquant sur une couleur de revêtement. La console affichait ensuite des messages « RID allocations … were leaked at exit ».

- **Ces messages** sont un avertissement de Godot 4.5 qui s'affiche quand le programme se ferme, même lors d'une fermeture normale. Ils ne disaient pas ce qui s'était passé.
- **La vraie cause** est une erreur de script dans les fenêtres **Revêtements** et **Personnaliser** : *« Attempt to call function 'null::null (Callable)' on a null instance »*.
  - Après chaque choix, la fenêtre devait se redessiner, mais elle appelait une fonction encore vide au moment où elle avait été préparée.
  - Lancé depuis l'éditeur Godot, le jeu s'arrête sur une erreur de script, et paraît donc figé.
  - Dans le jeu exporté, la fenêtre ne se mettait simplement pas à jour : pastille active, prix de la rénovation et aperçu du personnage restaient sur l'ancien choix.

Le défaut existait depuis longtemps dans les deux fenêtres. Il se déclenchait au moindre choix : couleur, revêtement, tenue, coiffure, silhouette…

## Ce qui change

- Les deux fenêtres se redessinent correctement après chaque choix : pastille active, prix, aperçu.
- **Sélecteur de couleur personnalisée** (le dernier carré de chaque rangée) :
  - pendant qu'on y choisit une teinte, la couleur s'applique en direct : sol ou murs du bâtiment pour un revêtement, portrait pour un personnage ;
  - la fenêtre n'est redessinée qu'une fois, à la fermeture du sélecteur.
  - Avec la correction seule, la fenêtre aurait détruit le sélecteur à chaque mouvement de souris, pendant qu'on s'en servait. C'est un vrai risque de plantage de Godot, désormais évité.
- **Bâtiment pendant le choix** : il n'est redessiné qu'une fois par image au plus.

## Vérifié par les tests

Nouveau test lancé dans une vraie fenêtre (`--finishes-test`), désormais exécuté à chaque construction :

- une pastille de couleur s'applique et la fenêtre se redessine ;
- le sélecteur de couleur reste ouvert pendant qu'on le manipule, et la fenêtre ne bouge pas ;
- le bâtiment suit la couleur en direct ;
- la fenêtre se redessine une fois à la fermeture du sélecteur ;
- dans la fenêtre Personnaliser, un choix redessine la fenêtre et une couleur de peau personnalisée met l'aperçu à jour sans fermer le sélecteur ;
- aucune erreur de script.

Toutes les autres suites passent toujours.
