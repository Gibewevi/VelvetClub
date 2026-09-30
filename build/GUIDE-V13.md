# Construction V13 — Personnages

Lancer **Construction-V13-Personnages.exe**. Le jeu fonctionne localement sous Windows, sans installation de Godot.

Une escort adulte de référence est présente dans la salle principale. Cliquez-la puis **Personnaliser…** : couleurs, visage, coiffure, tenue et silhouette disposent d’un aperçu animé. Faites défiler les réglages de droite pour accéder au ventre, aux hanches et aux jambes. **Appliquer** valide, **Annuler** abandonne. Le menu Animation montre six clips de démonstration ; la scène conserve une animation de repos.

Pour créer des variantes, utilisez **Copier**, ou **Mobilier → Personnages → Escort · référence**. Chaque exemplaire peut être personnalisé indépendamment. Déplacement, rotation, suppression, sauvegarde et annulation fonctionnent comme pour le mobilier.

L’intérieur est en briques rouges, avec le plancher habituel. Les pièces restent libres et entièrement modifiables. **Revêtements…**, dans la fiche d’une pièce, change les matériaux et couleurs. Une ancienne partie conserve son aménagement ; la référence adulte est ajoutée une seule fois dans un espace libre, si possible.

**B** : mobilier. **2** : pièce par clic-glisser. **3 / 4** : porte / fenêtre. **R** : tourner. **Suppr** : supprimer. **Ctrl + Z / Y** : annuler / rétablir. **Échap** : quitter l’outil. **Molette** : zoom. **Clic droit + glisser** : caméra. **Q / E** : rotation. **F1** : aide complète.

La sauvegarde est automatique dans `%APPDATA%\Godot\app_userdata\Construction\building.json`. **Menu → Nouveau local à rénover** permet de recommencer.

Le dossier **Personnage-Escort** contient les exports réutilisables `.tscn` et `.glb`, avec 56 os et six animations. Les morphologies restent paramétriques dans les sources du jeu ; le GLB représente le profil de référence. Les animations sont des démonstrations, sans navigation ni interaction automatique avec le mobilier.

Windows 64 bits, rendu Vulkan. Les licences du moteur et des ressources sont incluses.
