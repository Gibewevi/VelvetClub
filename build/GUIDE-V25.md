# Construction V25 — Rencontres, chambres et hygiène

Exécutable : `Construction-V25-Chambres.exe`.

Une prestation n'a lieu que si l'escort et le client **se rencontrent**, **discutent**, puis **s'accordent**. Tout se passe hors de la vue : le jeu suggère sans rien montrer d'explicite.

## 1. Rencontre dans la salle publique

- Les clients boivent au bar ou sur un tabouret, s'assoient sur une chaise ou un canapé, **dansent sur la nouvelle piste de danse** (Mobilier, 1 500 $), ou font le tour de la salle.
- Une escort libre repère un client occupé et vient se placer à côté de lui : le tabouret voisin, l'autre place du canapé, une chaise proche, ou la piste de danse s'il danse.
- **Plus la salle compte de bar, tabourets, chaises, tables, canapés, fauteuils et piste de danse, plus les rencontres sont fréquentes**, et mieux les discussions se passent.
- Pendant quelques minutes, ils discutent (bulles « … ») ; le client reste le temps de la conversation.

## 2. L'accord

L'accord n'a lieu que si les quatre conditions sont réunies (sinon croix rouge) :

- **Le client est intéressé** : satisfaction assez haute ; les chances augmentent avec le standing de l'escort et l'aménagement de la salle.
- **Il peut payer** au moins une prestation. Son budget augmente avec la réputation du club, et son détail s'affiche quand on sélectionne le client.
- **L'escort accepte** : elle refuse les clients trop mécontents.
- **Une chambre est libre** : un lit dans une pièce de type Chambre. Sinon, un message le signale.

## 3. Les prestations

| Prestation | Prix de base | Durée |
|---|---|---|
| Rapide | 80 $ | ~14 min |
| Classique | 150 $ | ~26 min |
| Complète (combinaison) | 260 $ | ~40 min |

- Les prix sont multipliés selon le standing : ×1 débutante, ×1,3 confirmée, ×1,7 élégante, ×2,2 prestige.
- Les tarifs de chaque escort s'affichent quand on la sélectionne.
- Le client prend la meilleure prestation que son budget permet, ou une autre au hasard.

## 4. En chambre

1. Le couple monte : la porte s'ouvre à leur passage.
2. **Douche (Mobilier, 650 $, facultative)** : s'il y en a une dans la chambre, le client se lave avant. On voit des gouttes au-dessus de la douche.
3. **Sur le lit**, les deux personnages disparaissent sous la couette : on ne voit que deux têtes sur l'oreiller et deux formes sous le drap, avec des cœurs au-dessus du lit. La somme est encaissée (« $ »).
4. Après :
   - le **lit reste défait** jusqu'à ce que la **femme de ménage** le refasse ; elle s'occupe des lits en priorité, le technicien des déchets en priorité ;
   - des **mouchoirs et serviettes usagés** traînent parfois au pied du lit, à ramasser ;
   - l'escort **se douche après** s'il y a une douche, puis retourne en salle.

## 5. Hygiène et maladies

Le risque de transmission à chaque prestation vaut 2 %, plus :

| Facteur | Risque ajouté |
|---|---|
| Client qui n'a pas pu se doucher | + 7 % |
| Lit laissé défait depuis la fois précédente | + 6 % |
| Déchet dans la chambre (jusqu'à 3) | + 3 % chacun |
| Escort sans douche après | + 5 % (pour elle) |
| Escort qui se douche après | risque réduit de 40 % |

Conséquences :

- **Client malade** : il repart très mécontent, ce qui fait baisser la réputation. Un message rappelle les bonnes pratiques.
- **Escort malade** : sa santé baisse (affichée quand on la sélectionne). Sous 55 %, elle **arrête de travailler pendant une dizaine d'heures** pour se reposer, puis reprend.
- Un lit défait ou des déchets rendent aussi la chambre moins agréable.

## Vérifié par le test de simulation

Avec une escort de prestige, une douche et la femme de ménage, sur une soirée :

- 19 rencontres, 17 accords, 2 refus ;
- 17 prestations (9 rapides, 7 classiques, 1 complète) pour 4 466 $ ;
- 33 douches, 16 lits refaits, aucune maladie.

Le test vérifie aussi :

- qu'une escort rendue malade arrête de travailler puis guérit ;
- qu'à la fermeture, personne ne reste caché dans un lit.
