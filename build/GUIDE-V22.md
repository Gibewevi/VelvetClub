# Construction V22 — Accueil, file d'attente et bar

Exécutable : `Construction-V22-Accueil.exe`.

## Nouveaux métiers

Le **réceptionniste** (14 $/h) et le **barman** (16 $/h) s'embauchent désormais dans Personnel. Ils étaient en pause depuis la V19. Seul l'agent de sécurité reste « bientôt ».

## L'entrée se paie à l'accueil

- **Personne n'entre sans avoir payé.** À l'ouverture, les clients font la queue **dehors**, sur le tapis rouge devant la porte, puis le long de la façade.
- **Pour payer, il faut un comptoir d'accueil (Mobilier, 1 200 $) et un(e) réceptionniste à son poste derrière.**
  1. La première personne de la file entre jusqu'au comptoir.
  2. Elle paie l'entrée au réceptionniste (« $ » au-dessus de la tête).
  3. Elle peut alors aller au salon ou au bar.
- **Sans comptoir ou sans personne derrière, la file ne bouge pas.**
  - Elle grandit devant le club, jusqu'à 12 personnes ; au-delà, les passants renoncent.
  - Les clients s'impatientent : leur satisfaction baisse et un « ? » apparaît au-dessus de leur tête.
  - Au bout de leur patience, ils partent mécontents, ce qui fait baisser la réputation.
  - Un message explique ce qui manque (comptoir, ou réceptionniste absent).
- Le compteur en haut à droite montre les **clients à l'intérieur** (ceux qui ont payé) et, à côté du sablier, la **file d'attente**. Le chiffre de la file passe en rouge à partir de 4 personnes.
- Si le réceptionniste est renvoyé pendant qu'un client paie, le client attend au comptoir et finit par partir.

## Bar

- Un **comptoir de bar** (Mobilier, 1 800 $, tabourets en option) dans une salle, avec un **barman**, vend des boissons aux clients : de l'argent en plus et des clients plus contents.
- Sans barman, les clients qui vont au bar repartent déçus.

## Vérifié par le test de simulation

1. Club ouvert sans accueil : une file de 7 personnes se forme dehors, personne n'entre ni ne paie, 27 clients partent de dépit et la réputation baisse.
2. Comptoir sans réceptionniste : toujours aucune entrée.
3. Avec le réceptionniste, le barman et une escort :
   - 49 clients arrivent et un seul part de dépit ;
   - 1 000 $ d'entrées, plus de 1 000 $ au bar ;
   - la réputation monte à 3,8 étoiles.
