# Construction V64 — Pluie fluide

Exécutable : `Construction-V64-Pluie-Fluide.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Ce qui restait

Les mesures de la V62 tournaient sans affichage, donc sans dessin à l'écran. Elles ont manqué un coût qui n'existe qu'avec l'affichage, et seulement **quand il pleut**, d'où le « quelquefois ».

À chaque image, pour chacune des 900 gouttes, le jeu vérifiait si elle tombait sur un toit. Il testait 8 hauteurs, et à chaque hauteur parcourait toutes les pièces : environ 144 000 tests par image. Depuis la V61, chaque test créait en plus une petite liste en mémoire.

Sur votre sauvegarde, cela coûtait **65 à 75 ms par image** rien que pour la pluie. Le jeu tombait vers 10 images par seconde dès qu'il pleuvait, même en pause, puisque la pluie était redessinée à chaque image. En ×3 avant la V62, cela suffisait à lancer l'effondrement décrit dans le guide V62.

## Ce qui change

- **Abri des gouttes** : une table des mètres couverts par un toit est calculée une fois par changement de plan. Une goutte s'y lit directement : **2,5 ms au lieu de 75**, avec exactement les mêmes gouttes abritées.
- **Pluie redessinée seulement quand il le faut** :
  - les gouttes ne changent de place que 24 fois par seconde, les éclaboussures 8 fois ;
  - elles ne sont redessinées qu'à ces moments, ou quand la caméra bouge ;
  - en pause, la pluie ne coûte plus rien.
- **Assombrissement par temps de pluie** : n'est réappliqué que quand l'intensité change, et non à chaque étape de simulation.
- **« Ce point est-il dans cette pièce ? »** : cette question, posée des milliers de fois par seconde (pluie, personnages, objets), ne crée plus rien en mémoire.

## Mesures dans le vrai rendu (avec affichage)

Mesures sur votre sauvegarde, sous une pluie maximale, en ×3 :

| Moment | Images par seconde | Pire image |
|---|---|---|
| Journée, peu de clients | 60 (limite de l'écran) | 35 à 66 ms |
| Nuit, jusqu'à 33 clients, panneaux ouverts | 40 à 60 | moins de 70 ms (179 ms une fois, à la première ouverture du panneau Personnel) |

Aucun blocage. Mémoire stable vers 70-95 Mo.

## Si un ralentissement revenait

Le journal `%APPDATA%\Godot\app_userdata\Construction\perf.log` (depuis la V62) note toutes les 30 secondes la fluidité et la mémoire, et chaque image anormalement lente avec ce qui l'a causée. Il suffit de l'envoyer.

## Vérifié par les tests

- Toutes les suites passent : modèle, art, scène, nuit simulée, météo, livraisons, interface en vraie fenêtre.
- `pixel/tests/rain_cost_probe.gd` mesure le coût d'une image de pluie sur une sauvegarde donnée : `--script res://tests/rain_cost_probe.gd -- --probe-save=<copie>`.
