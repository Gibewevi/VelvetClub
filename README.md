# Construction — V39 pixel art

Jeu natif Windows de gestion d'un club, en isométrique et en vrai pixel art rétro. Développé avec Godot 4.5.1, avec le moteur et les ressources intégrés à l'exécutable : rien à installer pour jouer.

Le projet `pixel/` est un jeu 2D. Tout le graphisme est dessiné pixel par pixel à sa résolution finale, puis seulement agrandi par un facteur entier en plus-proche-voisin. L'interface reprend le style rétro des premières versions (fenêtres à barre de titre, dock, icônes 10 × 10), redessiné en pixel art.

## Jouer

Lancer `build/Construction-V39-Camion-Polish.exe`.

**V39 — Camion retravaillé.** Le camion de livraison reprend plus précisément le modèle de référence : cabine profilée, vitrage et rétroviseurs, roues et passages de roue, châssis, panneaux ivoire, emblème de colis, bandes réfléchissantes et feux. L'arrière détaille les portes, leurs charnières et verrouillages, la soute et le hayon rainuré. Le dessin reste sur la grille native du jeu, avec contours nets et agrandissement sans lissage. Les achats, les commandes en cours et les sauvegardes conservent leur fonctionnement. Aperçus dans `build/Apercus-V39/`.

**V38 — Commandes et livraisons physiques.** Achetez et placez un meuble normalement : son fantôme bleu semi-transparent réserve l'emplacement, sans fonctionner ni éclairer. Les achats se regroupent automatiquement jusqu'à l'arrêt du prochain camion. Après environ 18 secondes à vitesse normale, un camion ivoire arrive par la route, se gare en warnings, ouvre ses portes et son hayon. Deux livreurs en uniforme bleu récupèrent les colis : petit carton porté à la main, colis moyens ou gros sur diable/chariot. Ils traversent les portes, déballent à côté du fantôme et installent l'objet réel. Le camion se vide, referme ses portes et repart. Les achats effectués pendant le déchargement attendent le camion suivant.

Le bouton **Livraisons** sous l'horloge donne le délai, les colis et leur état. Cliquer un objet dans cette liste retrouve son fantôme. On peut le déplacer ou annuler l'achat avec remboursement. Un accès bloqué garde le colis en attente et déclenche un nouvel essai ; un livreur empêché de ressortir attend la réouverture du passage. La pause et l'accélération s'appliquent aux livraisons. La sauvegarde conserve commandes, camion, livreurs et progression ; annuler une modification ne remet pas un objet livré à l'état de fantôme. Les meubles des anciennes parties et le recrutement du personnel restent disponibles immédiatement. Aperçus dans `build/Apercus-V38/`.

**V37 — Parking modulaire.** Dans Construire → Places (K), un clic pose une place de **2,5 × 5 m** ; un glisser compose une rangée côte à côte ; **R** tourne les places. L'orientation reste fixe pendant l'agrandissement. Les ajouts s'alignent aux extrémités et les rangées compatibles se réunissent. Sélectionner une rangée donne aussi deux boutons **+1 place**. Construire → Allée permet de tracer librement le passage devant les places et jusqu'à la rue. Les surfaces se raccordent sans bordure intérieure. Une place sur terrain neuf coûte **375 $** ; le bitume d'une allée déjà payée est réutilisé sans double facturation. Les anciennes zones deviennent automatiquement une rangée et de l'allée, sans perdre de surface ni de valeur. Aperçu dans `build/Apercus-V37/`.

**V35 — Parkings redessinés.** Bitume anthracite violacé à grain fin, grandes fissures irrégulières et zones effritées, lignes ivoire écaillées, butées en béton gris et bordures patinées. Terre, mousse et touffes d'herbe s'accumulent dans les joints et certaines fissures. La texture reste continue jusqu'à l'entrée. Les parkings déjà enregistrés prennent automatiquement ce nouveau rendu ; les dimensions, prix et trajets sont conservés. Aperçus dans `build/Apercus-V35/`.

**Le départ (V20).** Le joueur reprend un **petit local vétuste presque vide** de quatre pièces : une salle sur rue de 7 × 6 m, des WC, une réserve et **une seule chambre**.
- **Les lieux** : murs rouges décrépis et plâtre à nu, plancher taché, faïence encrassée dans les WC. La chambre a une **vieille tapisserie déchirée** (lés arrachés, plâtre à nu, auréoles) et une **moquette usagée** (zones pelées, taches, brûlures).
- **Le mobilier récupéré** : vieux canapé, vieux lit au matelas taché, lampe de chevet, vieux fauteuil, tapis élimé, armoire à la porte entrouverte, table, frigo, étagère rouillée, WC et lavabo défraîchis, pilier, affiches, fenêtre condamnée.
- **Les déchets** : papiers, bouteilles, planches, cartons, sacs poubelle et gravats de plâtre jonchent le sol.
- **Dehors** : l'enseigne néon, le tapis rouge usé et des bennes. Devant le terrain passe une **rue fixe** à l'échelle réelle (V34) : deux voies de 3,5 m en bitume fissuré, marquages usés, trottoirs en dalles de 2,5 m avec bordures, herbes folles, grilles d'égout, lampadaires et arbres. On ne construit pas sur le trottoir ni sur la rue.

Le joueur démarre avec une réputation d'une étoile et aucun employé. **Pour les tests, le budget de départ est provisoirement de 1 000 000 $** (`ClubSim.START_MONEY`, à rééquilibrer). **F8 / Maj + F8** ajoutent ou retirent une étoile (outil de test temporaire).

- **Rénover** :
  - chaque revêtement neuf se paie au m² de sol ou au mètre de mur (tarifs affichés dans la fenêtre Revêtements) ;
  - les meubles neufs s'achètent dans Mobilier ;
  - une pièce se construit à 40 $ le m².
  - Le mobilier récupéré se garde, se déplace ou se jette **gratuitement**. Il ne se revend pas et n'est pas vendu en boutique.
- **Escorts et standings** : quatre standings, liés à la réputation du club.
  - **Débutante** (dès le départ, 15 $/h) : lingerie, bandeau et mini-jupe avec résille, ou soutien-gorge et string.
  - **Confirmée** (2 étoiles, 24 $/h) : body en dentelle, robe moulante, ou balconnet avec résille et jarretelles.
  - **Élégante** (3 étoiles, 38 $/h) : corset et bas, robe de cocktail, ou nuisette transparente.
  - **Prestige** (4 étoiles, 60 $/h) : robe du soir fendue, robe à sequins, ou lingerie bijou à chaînes d'or.
  - Chaque recrue reçoit un look tiré au hasard dans son standing, avec l'une des trois silhouettes : galbée, très généreuse (poitrine très forte, caricaturale) ou fine. Toutes les tenues d'escort existent dans les trois silhouettes.
  - Les escorts s'installent au salon et tiennent compagnie aux clients assis. Plus leur standing est élevé, plus les clients sont satisfaits, et leur présence embellit la pièce.
- **Piste de danse** :
  - elle est animée (dalles et néon) et se personnalise avec 5 palettes ;
  - les escorts y dansent et les clients généreux leur laissent des pourboires ;
  - un client généreux peut emmener l'escort en chambre directement depuis la piste.
- **Scène & barre** :
  - le tour de la scène s'anime (LED en chenillard, anneaux néon, faisceau tournant, anneaux qui montent le long de la barre) et se personnalise avec les 5 mêmes palettes que la piste ;
  - une escort libre y fait un show à la barre, et les clients viennent alors bien plus souvent la regarder ;
  - les clients généreux de la pièce (au pied de la scène, au bar ou au salon) laissent des pourboires, et l'un d'eux peut emmener la danseuse en chambre directement depuis la scène.
- **Parkings (V37)** : Construire → Places (K), puis clic ou glisser. Chaque place est entière ; la profondeur reste de 5 m et la rangée s'allonge par pas de 2,5 m. L'outil reste actif pour ajouter facilement des places. Construire → Allée dessine le bitume libre sur une grille de 0,5 m ; tarif du terrain neuf : 30 $/m².
  - Vert : le module tient, ses entrées restent dégagées et le budget suffit. Rouge : hors terrain, bâtiment, chevauchement de places, accès bloqué ou budget insuffisant. Relâcher en rouge ne construit rien et ne coûte rien.
  - Les places peuvent être installées avant leur allée. Garder 6 m libres devant elles pour manœuvrer ; deux rangées face à face partagent ce dégagement. Cette surface libre n'est payée que lorsqu'on y trace une allée. Les rangées accolées dos à dos sont possibles ; les places empilées qui se bloquent sont refusées.
  - Le prototype de circulation de la V34 reste séparé dans `Street.traffic_layout()` ; les nouveaux modules ne simulent pas encore de voitures.
- **Superpositions (V33)** : chaque personnage passe devant ou derrière les meubles selon sa vraie position.
  - Assis sur un canapé, un fauteuil, une chaise ou un lit, il est toujours devant l'assise. Il est devant le dossier ou la tête de lit quand le meuble fait face au joueur, et derrière quand le meuble est tourné.
  - La danseuse passe devant ou derrière la barre selon l'orientation de la scène.
  - Dans une douche, la personne est devant le carrelage et derrière les vitres.
  - Les bulles (cœurs, étoiles…) restent toujours visibles au-dessus des murs.
- **Plantes** : fougère, cactus fleuri, aloé, monstera, oiseau de paradis, petit palmier, et petit palmier lumineux à guirlandes scintillantes (filtre « Plantes » du Mobilier).
- **Rencontres et chambres** : une prestation n'a lieu que si une escort et un client se rencontrent en salle, discutent et s'accordent.
  - Le bar, les tabourets, les chaises, les canapés et la piste de danse multiplient les rencontres.
  - L'accord dépend de l'humeur du client, de son budget, du standing de l'escort et d'une chambre libre.
  - Il y a trois prestations : rapide, classique et complète. Leur prix est multiplié selon le standing.
  - **Prestation rapide** : les deux personnages rejoignent un espace libre au sol dans la chambre. Le client reste debout et l'escort prend une pose statique à genoux, le buste droit et les mains sur les cuisses. Les personnages restent habillés et visibles, avec un espace entre eux. À la fin, ils reprennent leurs déplacements. Le lit conserve son état ; cette variante ne laisse pas de vêtements ni de mouchoirs au sol. Une chambre trop encombrée pour placer les deux personnages ne permet pas cette prestation.
  - Pour les prestations classique et complète, la scène au lit est conservée. Le couple flirte au bord du lit, puis l'escort danse pour le client assis (avec un pourboire). Les vêtements volent au sol de la chambre, puis le couple plonge sous la couette : les formes bougent et le lit tremble au rythme de la prestation.
  - Des bulles comiques ponctuent la scène : cœurs, gouttes de sueur, « BOUM ! » contre la tête de lit, étoiles, « Zzz ».
  - Après une prestation au lit, celui-ci reste défait jusqu'à ce que la femme de ménage le refasse, et des mouchoirs usagés sont parfois à ramasser.
  - Les douches (facultatives) laissent le client se laver avant et l'escort après. On y entre et on en sort **uniquement par la porte vitrée**, qui s'ouvre puis se referme. Cette porte doit donner sur un sol libre de la pièce : une douche dont la porte est bloquée n'est pas utilisée (« Porte bloquée » dans son panneau).
  - Sans douche, avec un lit défait ou une chambre sale, le risque de maladie augmente. Un client malade nuit à la réputation. Une escort malade se repose une dizaine d'heures.
- **Nettoyer** : les déchets ne se suppriment pas à la main. Il faut **embaucher un technicien d'entretien** (ou une femme de ménage) dans Personnel. Les techniciens ramassent les déchets un par un, en commençant par ceux marqués « Nettoyer en priorité ». Un déchet nettoyé disparaît définitivement, y compris de l'historique d'annulation. Le compteur en haut à droite indique ce qu'il reste.
- **Ouvrir / Fermer** : le bouton sous l'horloge (ou `O`) ouvre ou ferme le club.
  - Fermé, personne n'entre et les clients présents s'en vont. L'enseigne est éteinte.
  - Ouvert, l'enseigne s'allume et les clients arrivent de la rue. **Ils font la queue dehors** (sur le tapis rouge, puis le long de la façade) : personne n'entre sans avoir payé.
  - **L'entrée se paie à l'accueil**, à un comptoir d'accueil (Mobilier) où un(e) **réceptionniste** est à son poste. Sans comptoir ou sans personne derrière, la file grandit (jusqu'à 12 personnes) et les clients s'impatientent (« ? »), puis partent mécontents, ce qui fait baisser la réputation. Un message explique ce qui manque. Le compteur du haut distingue les clients à l'intérieur et la file (sablier).
  - Une fois entrés, les clients font le tour, boivent au **bar** si un **barman** les sert (sinon ils repartent déçus), s'assoient au salon puis repartent.
  - Leur satisfaction dépend de la propreté, de la rénovation et de la décoration, et fait évoluer la réputation, qui attire plus ou moins de monde.
- **Mécaniques en pause** : saleté laissée par les clients, nuit 20:00-04:00 avec rapport, tarifs et agent de sécurité. L'accueil, le bar, la compagnie au salon, les chambres et la scène ont été réactivés et testés. Le code est conservé derrière des interrupteurs (`ClubSim.FEATURES` dans `pixel/scripts/sim.gd`), pour les réactiver et les tester une par une. En attendant, le temps s'écoule jour après jour et les salaires sont payés à l'heure.

| Action | Commande |
|---|---|
| Dock | Sélection, Construire (outils et plan des pièces), Mobilier, Personnel, Clients, Menu |
| Ouvrir / fermer | Bouton sous l'horloge ou `O` |
| Temps | `Espace` pause · `1` normal · `2` accéléré (boutons sous l'horloge) |
| Tracer une pièce | `T` ou Construire → Pièce, puis cliquer-glisser |
| Porte / fenêtre | `P` / `F`, puis cliquer un mur |
| Parking | `K` : Places · clic : une place · glisser : rangée · `R` : tourner · Construire → Allée : passage libre |
| Mobilier | `B` ; `Maj` + clic pour poser en série ; `R` pour tourner |
| Sélection | Clic sur un meuble, une personne, une ouverture ou le sol d'une pièce |
| Déplacer / copier / supprimer | Glisser · `Ctrl + D` · `Suppr` |
| Annuler / rétablir | `Ctrl + Z` / `Ctrl + Y` (l'argent suit) |
| Vue | Molette : zoom ×1 à ×4 · clic droit ou milieu + glisser · `W` murs hauts / coupés · `G` grille · `Origine` · `F11` |
| Enregistrer / aide | `Ctrl + S` / `F1` · sauvegarde automatique |

Un meuble neuf supprimé ou une action annulée est remboursé au prix d'achat.

**Menu → Importer le bâtiment 3D** reprend les pièces et le mobilier de la sauvegarde de la version 3D (`building.json`). Cet import s'annule avec `Ctrl + Z`. La partie pixel art est enregistrée à part, dans `%APPDATA%\Godot\app_userdata\Construction\pixel_club.json`. L'ancienne sauvegarde n'est jamais modifiée.

## Du vrai pixel art, pas de la 3D pixelisée

- **Grille unique** : une case de sol de 1 m mesure 32 × 16 px en isométrique 2:1 ; 1 m de hauteur vaut 24 px ; les murs du fond font 56 px et les murs coupés de l'avant 12 px.
- **Personnages** : frames de **32 × 48 px** dessinées à cette taille, en 28 poses, dont debout immobile et à genoux, de face et de dos. Les silhouettes debout mesurent 40-41 px, pour une grosse tête au style mignon et caricatural.
  - Les jambes sont tracées ligne par ligne, avec une épaisseur fixe calée au pixel : aucune couture pendant la marche (cycle appui / passage en 4 temps).
  - Les escorts ont une silhouette à part (poitrine généreuse, décolleté, taille fine, hanches), dont chaque tenue est une carte de pixels dessinée à la main. Vue de face : repos, marche, assis, danse, serpillière et travail au comptoir. Vue de dos : repos, marche, assis. Les deux diagonales restantes sont obtenues par miroir.
- **Agrandissement** : le monde est rendu dans un viewport à la résolution native, puis agrandi ×1, ×2 (par défaut), ×3 ou ×4 en plus-proche-voisin. La caméra se déplace au pixel près. Il n'y a ni filtrage, ni flou, ni anticrénelage.
- **Génération des sprites** : ils sont produits par `tools/pixelart/` (Python, numpy, Pillow). Chaque pixel est décidé une seule fois, sans jamais réduire une image haute résolution.
  - Le mobilier est lancé pixel par pixel contre de simples volumes, puis colorié avec des rampes de 6 tons à teinte décalée (ombres violettes, lumières ambrées). Viennent ensuite les contours sombres, les arêtes éclairées et les lignes de séparation.
  - Les palmiers, néons, flammes et arbres sont tracés en 2D au pixel. Les arbres de rue (statiques) ont une couronne de rosettes de feuilles au cœur vert-jaune, un tronc roux évasé aux branches en Y et une fosse carrée.
  - Les visages, barbes et lunettes sont dessinés à la main, pixel par pixel.
- **Recoloration** : sols, murs et personnages stockent des index de palette. Le jeu les recolore en direct (couleur de peau, cheveux, tenue, revêtements) sans toucher au dessin.
- **Interface rétro** : depuis la V18, l'interface reprend le style des premières versions, redessiné en pixel art ×2. Fenêtres anthracite et prune à liseré fin, barre de titre centrée avec filet rose et bouton de fermeture, déplaçables par leur barre. Boutons biseautés, ombres portées nettes, icônes monochromes 10 × 10 d'origine, dock icône + texte en bas, historique (annuler, rétablir, enregistrer) en haut à droite. La police Pixelify Sans est utilisée à 20 et 40 px : ses pixels tombent exactement sur la grille de l'interface.

## Sources

Ouvrir `pixel/project.godot` dans Godot 4.5.1.

| Source | Rôle |
|---|---|
| `pixel/scripts/model.gd` | Pièces, objets, ouvertures, règles, coût, sauvegarde, import 3D, club de départ |
| `pixel/scripts/catalog.gd`, `finishes.gd`, `characters.gd` | Catalogue et places d'usage ; revêtements ; apparences et calques des personnages |
| `pixel/scripts/world_view.gd` | Rendu : sols recolorés, murs hauts/coupés, poteaux, portes animées, tri de profondeur topologique (décor, parties de meubles et personnages dans un seul ordre, à chaque image), porte de douche, halos, rue |
| `pixel/scripts/actor.gd` | Personnage en calques 32 × 48 partageant une palette, animations, déplacements |
| `pixel/scripts/street.gd` | Rue fixe, rangées de places orientées, allées et entrées ; prototype de planification des trajets séparé du calcul de construction |
| `pixel/scripts/nav.gd`, `sim.gd` | Navigation A* par les portes ; simulation du club (clients, personnel, argent, réputation) |
| `pixel/scripts/deliveries.gd`, `delivery_courier.gd`, `delivery_prop.gd` | Regroupement des achats, file d'attente, camion, transport des colis, accès et déballage ; reprise de livraison sauvegardée |
| `pixel/scripts/hud.gd`, `ui_kit.gd`, `editors.gd` | Interface rétro pixel art : fenêtres déplaçables, dock, historique, éditeurs d'apparence et de revêtements |
| `pixel/scripts/main.gd` | Caméra au pixel, outils, historique, sauvegarde, tests intégrés |
| `pixel/shaders/palette.gdshader` | Index de palette → couleur, contour de sélection, teinte d'aperçu |
| `tools/pixelart/pa_iso.py`, `pa_furniture.py` | Peintre isométrique natif et 57 meubles, objets et déchets × 4 orientations ; sièges, lits, scène et douche exportés aussi en parties (assise, dossier, accoudoirs, tête de lit, barre, murs, vitres, porte) avec leur emprise au sol, pour le tri de profondeur |
| `tools/pixelart/pa_chars.py`, `pa_dress.py`, `pa_hair.py`, `pa_charsheet.py` | Corps, poses, jambes au pixel, visages, tenues, coiffures, planches de personnages |
| `tools/pixelart/pa_escort.py` | Tenues des escorts par standing : cartes de pixels du buste, bas, résille, gants, bijoux, jupes |
| `tools/pixelart/pa_tiles.py`, `pa_draw2d.py` | Sols (dont bitume fissuré et dalles de trottoir), murs, ouvertures, décor de rue, halos ; tracés 2D |
| `tools/pixelart/pa_street.py` | Bordures, marquages usés, butées de roues, herbes, grilles, taches d'huile, fissures, panneau P |
| `tools/pixelart/pa_delivery.py` | Camion fermé/ouvert et warnings, chargement variable, colis de trois tailles, diables/chariots et cônes à la résolution native |
| `tools/pixelart/pa_truck.py`, `pa_truck_patterns.py` | Carrosserie du camion, cabine profilée, roues, portes articulées, hayon, peinture, vitrage et points lumineux |
| `tools/pixelart/pa_parking.py` | Grande texture de parking sans raccord visible, fissures, grain fin, terre et mousse en bordure, points d'implantation des herbes dans les crevasses |
| `tools/pixelart/pa_trees.py` | Arbres de rue au pixel (3 silhouettes statiques) et fosses d'arbre |
| `tools/pixelart/pa_ui.py` | Cadres de fenêtres, boutons, icônes 10 × 10 et émotes de l'interface rétro |
| `tools/pixelart/pa_cast.py`, `make_sheets.py` | Distribution de référence et planches d'aperçu |

## Construire et vérifier

Exécuter `./Build.ps1`. Le script effectue, dans l'ordre :

1. la régénération de tout le pixel art (si Python est présent) ;
2. l'import du projet ;
3. les tests : `model_test.gd` (petit local vétuste de départ avec une seule chambre, déchets accessibles, valeur des revêtements, plan complet de démonstration avec réception et urinoirs, navigation, import 3D, validations), `art_test.gd` (grille 32 × 16, frames 32 × 48, bords nets, index de palette, chaque frame de corps d'un seul tenant avec les pieds au sol et des jambes de taille constante en marchant, calques de chaque apparence, sprites de tout le catalogue, icônes 10 × 10 et cadres de l'interface), la scène (`--smoke-test`), la simulation (`--sim-test` : club fermé sans client, techniciens qui nettoient, file d'attente dehors sans accueil avec clients impatients, aucune entrée sans réceptionniste, puis entrées payées à l'accueil, boissons servies au bar, escort au salon, départ à la fermeture) et l'interface dans une vraie fenêtre (`--ui-test`, y compris le déplacement d'une fenêtre par sa barre de titre) ;
4. l'export de `build/Construction-V39-Camion-Polish.exe`.

Le test `--delivery-test` couvre le regroupement avant arrivée, les achats de la tournée suivante, deux livreurs, les fantômes inutilisables, le paiement unique, l'annulation et le remboursement, le déplacement en cours de transport, la reprise après sauvegarde, les accès bloqués et leur rétablissement, ainsi que les anciennes parties. Le test d'interface achète aussi deux objets à la souris, ouvre le suivi, observe le transport et le déballage puis vérifie leur installation et le départ du camion.

Le test `parking_fit_test.gd` couvre les quatre orientations, une place seule et les rangées, l'alignement et la fusion, les entrées dégagées, les bordures communes, le coût, la réutilisation du bitume, les sauvegardes et leur migration. Le test d'interface vérifie avec des événements souris et clavier le clic, le glisser, la rotation, les boutons de prolongement, la pose d'une allée, le refus rouge, l'annulation et le rétablissement.

Le test `quick_service_test.gd` vérifie aussi les trajets et le placement au sol, la conservation des tenues, la pose immobile, le paiement unique, l'état du lit et la libération des personnages après une fin, une annulation ou une modification de la pièce.

Les journaux sont écrits dans `tests/artifacts/`. `-- --capture=<png> --zoom=3 --focus=x,z --sim-seconds=12 --pause` produit une capture reproductible, sans lire ni écrire de sauvegarde.

L'ancien code 3D (V16 et antérieures) a été retiré du projet en V18 ; les exécutables et guides de ces versions restent dans `build/`.

## Périmètre et crédits

Il s'agit d'un prototype sur un étage. La simulation reste volontairement lisible : pas de besoins détaillés, de recrutement avec compétences, d'événements, ni de sons. Les tenues restent suggestives, sans nudité. Le club fonctionne comme dans l'artwork : bar, salon, scène, salons privés.

Code, sprites, tuiles et interface ont été créés pour le projet. L'artwork de référence n'est pas embarqué dans le jeu. Godot est sous licence MIT : voir `build/LICENCES.txt` et `build/GODOT-TIERS.txt`. Pixelify Sans est sous SIL OFL : voir `build/PIXELIFY-OFL.txt`. Le jeu ne télécharge aucune ressource.
