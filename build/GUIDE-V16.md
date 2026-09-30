# Construction V16 — Visages

Lancer **Construction-V16-Visages.exe**. Le jeu fonctionne localement sous Windows, sans installation de Godot.

Nouveauté de cette version : les visages de l'escort, de l'agent de sécurité et de l'agent d'entretien ont été repris en détail.

- **Deux fois plus de résolution sur la tête** : 128 sommets par tour au lieu de 64, rangées resserrées autour des yeux, du nez et de la bouche.
- **Forme de tête lisse** : plus de plis sur la mâchoire. L'escort a une mâchoire plus fine, en V ; les hommes un menton moins proéminent.
- **Nez** : un seul volume, avec arête, pointe arrondie, ailes fondues et narines placées dessous. La barre sombre sous le nez a disparu.
- **Bouche** : contour net des lèvres, arc de Cupidon, philtrum, commissures et sillon sous la lèvre.
- **Yeux** : pli de paupière, coin interne rosé, blanc de l'œil adouci.
- **Sourcils** : de vrais poils, orientés dans le sens de la pousse.
- **Oreilles** : rebord et creux de l'oreille.
- **Barbe et dégradé** : bord de joue organique, grain de poils, dégradé plus naturel.
- **Ombrage des creux** : narines, commissures, orbites, oreilles et plis du corps sont légèrement assombris.

Le réglage **Visage** de l'escort (traits doux, fins ou affirmés) modifie aussi le nez et les lèvres. Un personnage demande environ 1,5 seconde de calcul à la première apparition ; les apparences déjà vues sont réutilisées aussitôt.

Les personnages se placent depuis **Mobilier → Personnages** et se personnalisent avec **Personnaliser…**. Les dossiers **Personnage-Escort**, **Personnage-Securite** et **Personnage-Entretien** contiennent les exports `.tscn` et `.glb`. Le dossier **Apercus-V16** montre les trois visages de face, de trois quarts, de profil et en fil de fer.

**B** : mobilier. **2** : pièce par clic-glisser. **3 / 4** : porte / fenêtre. **R** : tourner. **Suppr** : supprimer. **Ctrl + Z / Y** : annuler / rétablir. **Échap** : quitter l'outil. **F1** : aide complète.

La sauvegarde est automatique dans `%APPDATA%\Godot\app_userdata\Construction\building.json`.

Windows 64 bits, rendu Vulkan. Les licences du moteur et des ressources sont incluses.
