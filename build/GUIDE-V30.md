# Construction V30 — Piste de danse et plantes

Exécutable : `Construction-V30-PisteEtPlantes.exe`.

## Piste de danse

- **Animée** : les dalles s'allument à tour de rôle sur une boucle de 4 images, un **néon** court tout autour de la piste, et la lueur au sol change de couleur au même rythme.
- **Personnalisable** : sélectionnez la piste, puis choisissez sa palette dans « COULEURS » (gratuit, annulable) :
  - **Arc-en-ciel**
  - **Rose & violet**
  - **Bleu glacier**
  - **Or & rouge**
  - **Vert acide**
- **Les escorts y dansent** : une escort libre va danser sur la piste. Les clients viennent alors plus volontiers danser, et ceux qui dansent près d'elle sont plus contents.
- **Pourboires** : les **clients généreux** autour de la piste glissent des pourboires à l'escort qui danse (« $ »).
  - Le pourboire vaut de 10 à 50 $ environ selon le standing de l'escort, et il est pris sur le budget du client.
  - Il y a plus de clients généreux quand la réputation monte.
- **Rendez-vous direct** : un client généreux qui danse avec une escort peut l'emmener **directement en chambre**, sans passer par la discussion, avec de meilleures chances d'accord.

## Plantes

Un nouveau filtre **« Plantes »** apparaît dans le Mobilier :

| Plante | Prix |
|---|---|
| Fougère en pot | 45 $ |
| Cactus fleuri | 40 $ |
| Aloé | 35 $ |
| Monstera | 90 $ |
| Oiseau de paradis | 110 $ |
| Petit palmier | 70 $ |
| **Petit palmier lumineux** | 160 $ |

- Le monstera a de grandes feuilles découpées.
- L'oiseau de paradis a des fleurs orange et bleu sur de hautes tiges.
- Le petit palmier lumineux porte des guirlandes d'ampoules (blanc chaud, rose, bleu) qui scintillent dans les palmes et autour du tronc, avec un halo doré.
- Les deux palmiers déjà existants sont aussi rangés dans ce filtre.

## Vérifié par les tests

Sur une soirée du test de simulation, avec une seule escort de prestige et une piste de danse :

- 433 $ de pourboires ;
- 3 rendez-vous pris directement sur la piste.

Les tests vérifient aussi :

- que chaque image animée existe (5 palettes × 4 images, et les 3 images du palmier) ;
- que la palette de la piste est conservée dans la sauvegarde ;
- que les plantes sont bien en vente.

Aperçus :

- `Apercus-V30/piste-et-palmier-animes-x2.gif` : les 5 palettes et le palmier lumineux ;
- `Apercus-V30/sprites-plantes-x3.png`.
