# Construction V14 — Personnage HD

Lancer **Construction-V14-PersonnageHD.exe**. Le jeu fonctionne localement sous Windows, sans installation de Godot.

Nouveauté de cette version : le modèle 3D de l’escort a été entièrement refait d’après la planche de référence.

- **Corps d’un seul tenant** : la peau ne forme plus qu’une surface, sans tubes emboîtés ni coutures aux épaules, aux hanches ou au cou. Environ 90 000 à 140 000 triangles selon la tenue, contre moins de 80 000 auparavant.
- **Silhouette stylisée** : jambes longues, taille fine, hanches et fessiers galbés, poitrine haute, cou fin, mains détendues le long des cuisses.
- **Visage** : grands yeux avec iris, paupières, eye-liner et cils, sourcils dessinés, nez fin, lèvres et pommettes.
- **Lingerie** : soutien-gorge à bonnets moulés et bretelles, culotte échancrée, porte-jarretelles à quatre attaches, bas voile à revers de dentelle, escarpins noirs à plateforme, talon aiguille et bride de cheville.
- **Cheveux** : mèches drapées sur la tête et les épaules. Cheveux longs avec raie sur le côté et mèche balayée, carré, ou chignon.

Une escort adulte de référence est présente dans la salle principale. Cliquez-la puis **Personnaliser…** : couleurs, visage, coiffure, tenue (lingerie, body, robe simple) et silhouette disposent d’un aperçu animé. Un nouveau réglage demande environ une seconde de calcul ; les apparences déjà vues sont réutilisées aussitôt. **Appliquer** valide, **Annuler** abandonne.

Pour créer des variantes, utilisez **Copier**, ou **Mobilier → Personnages → Escort · référence**. Chaque exemplaire peut être personnalisé indépendamment. Déplacement, rotation, suppression, sauvegarde et annulation fonctionnent comme pour le mobilier.

**B** : mobilier. **2** : pièce par clic-glisser. **3 / 4** : porte / fenêtre. **R** : tourner. **Suppr** : supprimer. **Ctrl + Z / Y** : annuler / rétablir. **Échap** : quitter l’outil. **Molette** : zoom. **Clic droit + glisser** : caméra. **Q / E** : rotation. **F1** : aide complète.

La sauvegarde est automatique dans `%APPDATA%\Godot\app_userdata\Construction\building.json`. Les parties existantes sont reprises telles quelles : les personnages déjà placés adoptent le nouveau modèle en gardant leurs réglages. **Menu → Nouveau local à rénover** permet de recommencer.

Le dossier **Personnage-Escort** contient les exports réutilisables `.tscn` et `.glb`, avec 56 os et six animations. Le dossier **Apercus-V14** montre le personnage de face, de trois quarts, de profil et de dos, ainsi que ses variantes et ses poses.

Limites connues : pas de simulation de tissu ni de cheveux ; dans les poses amples, la jupe de la robe ou les cheveux longs peuvent traverser les jambes ou les bras.

Windows 64 bits, rendu Vulkan. Les licences du moteur et des ressources sont incluses.
