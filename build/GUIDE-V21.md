# Construction V21 — Escorts et standings

Exécutable : `Construction-V21-Escorts.exe`.

## Tests (temporaire)

- **Budget de départ : 1 000 000 $**, pour tout essayer librement. Cette valeur sera rééquilibrée plus tard (constante `ClubSim.START_MONEY` dans `pixel/scripts/sim.gd`).
- **F8** donne une étoile de réputation de plus, **Maj + F8** une de moins. Cela permet d'essayer les standings d'escorts sans jouer des heures.

## Personnages

- **Un peu plus petits** : 2 px de moins, soit 40-41 px de haut au lieu de 42-43. Le buste et les jambes raccourcissent, la tête garde sa taille : l'allure est plus mignonne et caricaturale.
- **Jambes redessinées** : plus de coutures ni de cassures pendant les mouvements.
  - Chaque jambe est tracée ligne par ligne avec une épaisseur fixe, calée au pixel près : elle garde exactement la même forme d'une frame à l'autre.
  - Les plis sombres entre les hanches et les cuisses ont disparu.
  - Les jupes passent bien devant la jambe avant.
  - Les chaussures sont de petits motifs dessinés au pixel.
  - Le nouveau cycle de marche en 4 temps (appui, passage, appui, passage) ne croise plus les jambes.
  - Un test vérifie chaque frame de chaque tenue : un seul morceau, pieds au sol, jambes de taille constante pendant la marche.

## Escorts

- **Silhouette plus sexy et caricaturale**, dessinée à la main pixel par pixel :
  - poitrine généreuse, décolleté marqué, taille fine, hanches rondes ;
  - pose mains sur les hanches au repos ;
  - rouge à lèvres propre à chaque tenue.
  - Aucune nudité : le style pixel art reste mignon.
- **8 tenues**, deux par standing :

| Standing | Réputation | Salaire | Tenues |
|---|---|---|---|
| Débutante | dès le départ | 15 $/h | Lingerie (soutien-gorge pigeonnant, porte-jarretelles, bas) · Bandeau & mini-jupe vinyle, résille |
| Confirmée | 2 étoiles | 24 $/h | Body en dentelle plongeant, bas · Robe moulante au décolleté profond |
| Élégante | 3 étoiles | 38 $/h | Corset satin lacé d'or, bas, gants longs · Robe de cocktail en satin, pendentif |
| Prestige | 4 étoiles | 60 $/h | Robe du soir dos nu, fendue, ceinture dorée, gants · Robe à sequins scintillante |

- **Nouveaux looks** : coiffures « boucles glamour » et « queue-de-cheval », visage « glamour » (eye-liner de chat, lèvres pleines, grain de beauté).
- **Recrutement** : chaque escort embauchée reçoit un look tiré au hasard dans son standing. Dans « Personnaliser… », elle ne peut porter que les tenues de son standing.
- **Au travail** :
  - les escorts s'installent au salon (canapés, fauteuils, y compris ceux de récupération) et tiennent compagnie aux clients assis ;
  - plus le standing est élevé, plus les clients sont ravis ;
  - leur présence rend aussi la pièce plus agréable.
  - Salons privés, scène et bar restent en pause.
