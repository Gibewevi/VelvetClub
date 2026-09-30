# Construction V45 — Prestations visibles

Exécutable : `Construction-V45-Prestations-Visibles.exe`. Il utilise la même sauvegarde que la version précédente.

## Ce qui n'allait pas

Une nuit simulée a été rejouée pour mesurer le problème :
- les prestations rapides ont bien lieu (7 sur 16) et vont toutes jusqu'au bout, les deux personnages visibles ;
- mais elles ne duraient que 16 minutes de jeu, soit environ 6 secondes à vitesse normale et 2 secondes en accéléré ;
- le paiement était encaissé dès le début, avec une simple bulle « $ » au-dessus du lit, alors que la prestation rapide se passe ailleurs dans la chambre ;
- à la fin, rien ne s'affichait.

## Ce qui change

- **Prestation rapide plus longue** : 20 minutes au lieu de 14. La mise en place passe de 2 à 3 minutes, et une courte fin de 3 minutes est ajoutée.
- **Déroulé** :
  1. les deux personnages rejoignent leur place, avec un cœur à leur arrivée ;
  2. la pose, avec un cœur toutes les 3 minutes ;
  3. l'escort se relève, et tous deux échangent un cœur ;
  4. le client paie, puis ils se séparent.
  Il faut compter environ 10 secondes à vitesse normale.
- **Paiement à la fin, et visible** : pour toutes les prestations (rapide, classique, complète), le client paie à la fin. Le montant s'élève au-dessus de lui, par exemple « Prestation rapide +176 $ », et le compteur d'argent augmente au même moment.
- **Pourboire visible** : celui de la danse en chambre s'affiche aussi (« Pourboire +66 $ »).
- **Prestation interrompue** : si elle est coupée avant la fin (fermeture, changement du plan de la chambre…), rien n'est payé et le jeu affiche « Interrompue · non payée ».

## Vérifié par les tests

- Rien n'est encaissé avant la fin de la prestation rapide.
- L'escort se relève avant le paiement.
- Le montant exact est encaissé une seule fois, à la fin.
- Le montant payé s'affiche au-dessus du client.

La nuit simulée complète passe toujours.

## Aperçu

`Apercus-V45/paiement-prestation.png` : une prestation qui se termine, avec son prix affiché au-dessus du couple.
