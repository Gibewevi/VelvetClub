# Construction V15 — Personnel

Lancer **Construction-V15-Personnel.exe**. Le jeu fonctionne localement sous Windows, sans installation de Godot.

Nouveauté de cette version : deux membres du personnel rejoignent l’escort, avec une silhouette masculine générée par le même système (peau d’un seul tenant, 56 os, six animations).

- **Agent de sécurité** :
  - t-shirt noir ajusté avec « SECURITY » imprimé dans le dos et un petit lettrage sur la poitrine ;
  - pantalon cargo, ceinture avec étui et radio, gants et rangers ;
  - dégradé avec houppe, barbe taillée, lunettes de soleil.
- **Agent d’entretien** :
  - chemise et pantalon de travail bleu marine avec poches, bretelles jaunes ;
  - ceinture avec pochette à outils, gants gris, chaussures de travail ;
  - casquette et lunettes de vue.

Une nouvelle partie place l’escort dans la salle principale, l’agent de sécurité le long du mur ouest et l’agent d’entretien dans la pièce du personnel. Une partie existante reçoit les deux agents une seule fois, là où il reste de la place ; s’ils sont supprimés, ils ne reviennent pas.

D’autres exemplaires se placent depuis **Mobilier → Personnages** : **Escort · référence**, **Agent de sécurité**, **Agent d’entretien**. Cliquez un personnage puis **Personnaliser…**. Pour les agents, la fenêtre propose :
- **Coiffure** : dégradé, casquette ou rasée ;
- **Barbe** : complète, courte ou rasé de près ;
- **Lunettes** : aucune, solaires ou de vue ;
- **Tenue** : sécurité, entretien ou décontractée (t-shirt et jean) ;
- les couleurs et les sept réglages de silhouette, dont « Pectoraux ».

L’escort garde ses options ; son réglage **Visage** (traits doux, fins ou affirmés) fonctionne de nouveau.

Un nouveau réglage demande environ une seconde de calcul ; les apparences déjà vues sont réutilisées aussitôt. **Appliquer** valide, **Annuler** abandonne.

**B** : mobilier. **2** : pièce par clic-glisser. **3 / 4** : porte / fenêtre. **R** : tourner. **Suppr** : supprimer. **Ctrl + Z / Y** : annuler / rétablir. **Échap** : quitter l’outil. **Molette** : zoom. **Clic droit + glisser** : caméra. **Q / E** : rotation. **F1** : aide complète.

La sauvegarde est automatique dans `%APPDATA%\Godot\app_userdata\Construction\building.json`. **Menu → Nouveau local à rénover** permet de recommencer.

Les dossiers **Personnage-Escort**, **Personnage-Securite** et **Personnage-Entretien** contiennent les exports réutilisables `.tscn` et `.glb`. Le dossier **Apercus-V15** montre les agents de face, de profil et de dos, leurs visages, leurs poses et une planche récapitulative.

Limites connues : pas de simulation de tissu ; le balai de la planche de référence n’est pas inclus ; dans les poses amples, certains vêtements ou cheveux peuvent traverser les membres.

Windows 64 bits, rendu Vulkan. Les licences du moteur et des ressources sont incluses.
