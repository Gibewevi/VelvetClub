# Construction V62 — Fluidité

Exécutable : `Construction-V62-Fluidite.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Le problème

Parfois, le jeu ralentissait jusqu'à figer l'écran et il fallait forcer le redémarrage du PC. Windows confirme ces redémarrages forcés : le 30/09 à deux reprises, et le 01/10 à 21 h 47 et à 23 h 46. Aucun écran bleu, aucune mémoire épuisée : c'était le jeu qui s'effondrait sur lui-même.

Votre sauvegarde a été rejouée (une copie, l'originale n'a pas été touchée) en accéléré. Le jeu était mesuré image par image et surveillé par un garde-fou externe.

1. **Chaque petit déchet redessinait tout le bâtiment.** Un mouchoir laissé après une prestation, ou un déchet ramassé, déclenchait une reconstruction complète de l'affichage, d'environ 255 ms. Il y en avait 178 en 10 minutes de jeu accéléré.
2. **Le calcul du sol mouillé par la pluie** représentait à lui seul 175 ms de chaque reconstruction, même par temps sec : environ 1 200 points testés contre chaque pièce et chaque objet.
3. **Le cercle vicieux.** Plus une image était lente, plus la simulation avançait pendant l'image suivante, donc plus il y avait de déchets, donc de reconstructions. En ×3, avec 40 clients, le jeu pouvait s'enfoncer jusqu'à ne plus répondre du tout.
4. **Les agents d'entretien recalculaient un trajet complet vers chaque flaque, à chaque image** (jusqu'à 63 trajets par image).
5. **Une erreur répétée en boucle** (allée de parking étroite) remplissait le journal à chaque reconstruction.
6. **Les panneaux Clients et Personnel** étaient reconstruits deux fois par seconde.

## Ce qui change

- Les mouchoirs et déchets apparaissent et disparaissent **sans redessiner le bâtiment**.
- Plusieurs changements dans la même image ne déclenchent **qu'un seul** redessin.
- Le sol mouillé utilise une grille spatiale : **3 ms au lieu de 175**. Une reconstruction complète (après une action du joueur) coûte 80 ms au lieu de 255.
- **Le temps simulé par image est plafonné.** Si l'ordinateur ne suit plus, le jeu ralentit au lieu de s'emballer.
- La question « ce personnage peut-il aller là ? » se calcule une seule fois à chaque changement de plan. Elle devient instantanée, avec exactement les mêmes réponses, vérifiées sur 300 trajets.
- L'erreur du parking étroit est corrigée.
- Les panneaux Clients, Personnel, Rapports et Livraisons se rafraîchissent toutes les 2 secondes au lieu de 2 fois par seconde.
- **Garde-fou** : si les images restent lentes plus de 2 secondes en accéléré, le jeu repasse à ×1 avec un message. Si c'est encore trop lent à ×1, il se met en pause. Il garde toujours la main.
- **Journal de performances** : le jeu note toutes les 30 secondes sa fluidité et sa mémoire, ainsi que chaque image anormalement lente avec sa cause, dans `%APPDATA%\Godot\app_userdata\Construction\perf.log`. Si un blocage revenait, ce fichier dirait ce qui se passait.

## Mesures sur votre sauvegarde (5 minutes en ×3, jusqu'à 41 clients)

| | Avant | Après |
|---|---|---|
| Appels de plus de 50 ms | 368 | 5 |
| Reconstructions complètes de l'affichage | 178 (en 10 min) | 1 |
| Pire image | 290 ms | 51 ms |
| Simulation, par image | jusqu'à 30 ms | 4 à 11 ms |
| Mémoire | monte de 68 à 130 Mo | stable vers 95 Mo |
| Erreurs dans le journal | 888 | 0 |

## Vérifié par les tests

- Toutes les suites existantes passent : modèle, art, scène, nuit simulée, livraisons, interface dans une vraie fenêtre…
- Nouveau test : les zones accessibles donnent les mêmes réponses qu'une recherche de chemin complète, sur 300 trajets au hasard, y compris vers une pièce fermée.
