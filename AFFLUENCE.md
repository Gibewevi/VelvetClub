# Affluence et gestion du club

Ouvrez **Personnel → Gestion** pour suivre la fréquentation et préparer vos équipes. Les autres onglets sont **Équipe**, avec les employés et leurs plannings, et **Recrutement**, avec les candidats disponibles.

## Ce qui attire les clients

La réputation est le facteur principal : chaque hausse de note augmente progressivement la demande. À heure, météo et tarifs identiques, un club à 5 étoiles attire environ **8,5 fois** plus de visiteurs qu'un club à 1 étoile.

Exemple à 22 h un samedi, par temps sec, avec une entrée à 20 $ et une boisson à 12 $ :

| Note | Arrivées attendues par heure |
|---|---:|
| 1 étoile | 9 |
| 2 étoiles | 18 |
| 3 étoiles | 31 |
| 4 étoiles | 51 |
| 5 étoiles | 78 |

Les arrivées restent aléatoires. Le soir et la nuit attirent davantage de monde, avec un supplément le vendredi et le samedi, prolongé après minuit. Les prix ont un effet secondaire. Les averses sont rares et courtes ; elles réduisent temporairement la demande, au maximum de 30 %. Une partie des clients utilise un parapluie dehors et le ferme en entrant.

## Capacité et file extérieure

La capacité dépend de la surface accessible de l'accueil et du salon, après prise en compte des obstacles et des pièces en chantier : environ un client pour 2,5 m² de sol public utilisable, avec une limite de 48 personnes. Une pièce inaccessible ne l'augmente pas.

Quand le club est complet ou que l'accueil est occupé, les clients attendent devant l'entrée puis sur le trottoir. La file avance lorsqu'une place et un poste d'accueil se libèrent. Une place est réservée pendant le déplacement vers la réception pour éviter de dépasser la capacité.

Chaque client a sa propre patience. Les plus impatients quittent la file et leur départ est comptabilisé. La file comporte jusqu'à 24 positions accessibles ; si elle est entièrement occupée, les visiteurs supplémentaires renoncent et apparaissent dans les statistiques de demande perdue.

## Lire les statistiques

- **Arrivées** : clients réellement apparus dans la scène.
- **Entrées** : clients admis après passage à la réception.
- **Abandons** : clients ayant quitté la file après avoir attendu.
- **Renoncements avant la file** : demande qui n'a pas pu rejoindre une file accessible, notamment lorsqu'elle est complète.
- **Occupation** : part de la capacité utilisée pendant les heures d'ouverture, pondérée par le temps de jeu.
- **Attente moyenne** : attente réelle des clients finalement admis.

Les graphiques montrent les arrivées et entrées par heure, l'occupation par heure et les totaux des sept derniers jours. Le sélecteur permet de consulter les bilans journaliers des **28 derniers jours**. L'historique est enregistré avec la partie ; il commence au moment où cette fonctionnalité est utilisée. Les heures inconnues sont marquées d'un tiret, et l'heure en cours reste partielle.

La **prévision des prochaines 24 heures** utilise la note et les tarifs actuels, les variations horaires et les jours de la semaine. Elle tient compte des horaires automatiques ; en ouverture manuelle, elle suppose le club ouvert. Elle ne prédit pas la pluie. Comparez-la à l'historique pour planifier l'accueil avant la pointe, puis le bar et le ménage pendant les heures chargées. Si l'occupation atteint régulièrement 100 %, agrandissez également l'espace public.

## Vérification

Les tests `pixel/tests/traffic_test.gd` couvrent la demande, les admissions, la file pleine, les différences de patience, les parapluies, la rareté des averses, les statistiques, leur sauvegarde et les quatre graphiques. Ils sont inclus dans `Build.ps1`. La simulation d'une nuit vérifie également que l'accueil continue de servir pendant une pointe et que les abandons observés correspondent aux statistiques.
