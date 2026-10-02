# Construction — V63 pixel art

Jeu natif Windows de gestion d'un club, en isométrique et en vrai pixel art rétro. Développé avec Godot 4.5.1, avec le moteur et les ressources intégrés à l'exécutable : rien à installer pour jouer.

Le projet `pixel/` est un jeu 2D. Tout le graphisme est dessiné pixel par pixel à sa résolution finale, puis seulement agrandi par un facteur entier en plus-proche-voisin. L'interface reprend le style rétro des premières versions (fenêtres à barre de titre, dock, icônes 10 × 10), redessiné en pixel art.

## Jouer

Lancer `build/Construction-V63-Poussiere.exe`.

**V63 — Petit nuage de poussière.** Poser, déplacer ou recevoir un objet soulève à son pied un petit nuage, dans le dessin de la fumée des pneus de la camionnette (en plus petit et plus bref : environ une demi-seconde). Tourner un objet ne soulève que quelques éclats. Les nuages de l'arrière passent derrière l'objet, ceux de l'avant devant ; l'animation suit le temps réel (elle joue aussi en pause) et survit aux redessins du bâtiment. Aperçus dans `build/Apercus-V63/`.

**V62 — Fluidité.** Corrige les ralentissements qui pouvaient figer l'écran. Les petits objets (mouchoirs, déchets) ne redessinent plus tout le bâtiment ; plusieurs changements dans une image donnent un seul redessin ; le sol mouillé par la pluie se calcule avec une grille (3 ms au lieu de 175) ; le temps simulé par image est plafonné (le jeu ralentit au lieu de s'emballer) ; l'accessibilité d'un point se lit dans des zones calculées une fois par plan ; les panneaux de listes se rafraîchissent toutes les 2 s. Un garde-fou repasse à ×1 puis met en pause si les images restent trop lentes, et `perf.log` (dossier de sauvegarde) garde une trace de la fluidité. Outil : `-- --profile-save=<copie d'une sauvegarde> --profile-seconds=300 [--profile-drawers] [--profile-trace=<fichier>]` rejoue une partie sans l'écrire et mesure chaque système.

**V61 — Extensions automatiques.** Avec l'outil Pièce, le point de départ du tracé décide sans rien demander : depuis le terrain libre, c'est une nouvelle pièce (même si elle finit collée à une autre) ; depuis un mur d'une pièce (ou à moins de 30 cm) ou depuis son sol, c'est un agrandissement. Le survol l'annonce (« Agrandir : Chambre (depuis ce mur) », case de départ verte), le tracé montre la surface ajoutée et son prix. L'agrandissement est un chantier qui reprend le type et les revêtements de la pièce ; à la fin des travaux le mur entre les deux tombe et les surfaces fusionnent. Les pièces peuvent donc prendre une forme en L ou en T : sols, murs, contour, navigation, mobilier, valeur et sauvegardes suivent la nouvelle forme. Aperçus dans `build/Apercus-V61/`.

**V60 — Chantiers de construction.** Une pièce tracée n'apparaît plus d'un coup : la zone est balisée aussitôt (piquets, ruban rouge et blanc, marquage au sol) et devient un chantier où trois ouvriers en casque jaune et gilet orange travaillent, avec bétonnière, palette de parpaings, sacs de ciment, brouette, armatures, tréteaux, seau et projecteur. Cinq phases se voient à l'écran : dalle de béton coulée case par case (humide puis sèche), murs en parpaings montés rang par rang tout autour, peinture des murs au rouleau par bandes, pose du revêtement de sol case par case, puis finitions où le matériel et les ouvriers s'en vont. En cliquant le chantier : avancement en %, phase, temps restant ; on peut l'agrandir avec les poignées (seule la différence est facturée, ce qui est construit reste), changer son type ou ses revêtements, ou l'abandonner. La progression logique (temps, %, phases) est séparée de l'affichage, qui ne révèle que ce qui est fait. Personne d'autre n'entre sur un chantier et on ne le meuble qu'une fois terminé. Aperçus dans `build/Apercus-V60/`.

**V59 — Histoires et profils persistants.** Chaque employé et client possède une fiche avec son nom, son âge adulte, une histoire courte et des préférences. Cliquez **Fiche et histoire** dans la sélection d'un personnage ou dans Personnel. Le **Carnet des clients connus**, dans Clients, retrouve aussi les visiteurs partis, avec recherche et filtre des clients suivis. Trois onglets : Portrait, Souvenirs, Suivi. Les fiches, objectifs, notes et souvenirs sont sauvegardés ; les anciennes parties reçoivent leurs profils automatiquement.

Les clients retrouvent leur apparence et leur personnalité lors d'une prochaine visite : activité favorite plus souvent choisie (poids ×1,7, satisfaction +2), patience propre au personnage, sensibilité à la saleté et générosité stables. Les bonnes soirées renforcent la fidélité ; trois bonnes soirées complètent l'objectif d'habitué. Le jour et l'heure préférés influencent le choix des clients qui reviennent, au maximum une visite par identité et par jour. Les employés ont un trait métier (ménage/réparation 10 % plus rapide, ou accueil/bar +1 de satisfaction), une préférence de planning indicative et un objectif de 8 heures de service, donnant un petit bonus de temps des tâches de 5 %. Les horaires du joueur restent prioritaires.

L'onglet Suivi conserve une note de direction et une marque **Client à suivre**. Il ne bloque pas l'entrée. La base de sécurité propose un registre d'incidents : type, jour, source, confirmation et coût ; un signalement peut être confirmé, sans compter deux fois le même événement. Les tendances latentes sont indépendantes de l'apparence et ne sont pas exposées comme des faits. **Les vols, agressions, contrôles du vigile et caméras ne sont pas encore activés** : leurs futurs systèmes pourront alimenter ces fiches. Aperçus dans `build/Apercus-V59/`.

**V58 — Lit Cœur capitonné.** Le Lit Cœur reprend la référence fournie : tête bordeaux rembourrée à deux lobes, capitons et boutons dorés, liseré or, grands oreillers ivoire et petits coussins rouges. La couette rouge se replie près des oreillers et retombe en plis irréguliers sur les côtés et au pied du lit ; le sommier bordeaux reçoit des bordures et pieds dorés. Les détails sont dessinés à la résolution native, sans bruit ni variation aléatoire des reflets. Le modèle conserve ses dimensions, son prix et son fonctionnement, avec ses quatre orientations et ses états existants. Les lits Cœur déjà construits utilisent automatiquement ce nouveau dessin. Aperçus : `build/Apercus-V58/`.

**V57 — Lits et pluie corrigée.** Le lit double et le vieux lit ont des oreillers bombés, des coins de matelas et de cadre arrondis, et une couette plus fine avec quelques plis discrets. Le nouveau **Lit Cœur**, disponible dans Mobilier → Chambre pour 1 200 $, reprend l'empreinte du lit double (2,2 × 2,7 m), avec une tête capitonnée en cœur rouge bordeaux. Les deux lits neufs adoptent une palette rouge profonde. Le cœur possède une surface sobre, sans succession de reflets brillants, dans les quatre orientations ; il garde son dessin dans les différents états du lit. Placement, orientation automatique, livraison, sauvegarde et ménage reconnaissent le nouveau modèle. La pluie est maintenant ancrée dans le monde : le déplacement de la caméra révèle d'autres gouttes au lieu d'emporter le rideau de pluie. Les positions, décalages, vitesses et intervalles de chute sont variés pour casser les lignes régulières. Aperçus : `build/Apercus-V57/`.

**V56 — Météo en pixel art.** Les averses dynamiques ajoutent des gouttes et de petits impacts animés au sol : éclaboussures, gouttelettes et rides en losange. Des flaques bleu-gris aux contours irréguliers se répartissent aléatoirement dans le décor extérieur, grossissent pendant l'averse puis sèchent progressivement quand elle cesse. Le sol, les parkings et les éléments extérieurs s'assombrissent légèrement ; les pièces restent abritées et conservent leur éclairage. Le rendu utilise des pixels entiers et des formes fixes, sans bruit scintillant. La pause et les vitesses du jeu s'appliquent aux effets, et la sauvegarde conserve l'accumulation d'eau. Une construction masque immédiatement les flaques sous ses nouvelles pièces. La pluie reste liée à l'affluence. Aperçus : `build/Apercus-V56/`.

**V55 — Planning, horaires et affluence.** Dans Personnel, chaque employé possède ses jours travaillés et ses heures de début/fin, avec raccourcis Nuit 19–05 et Jour 06–14. Les jours désignent le début du service : vendredi 19–05 se termine samedi à 05:00. Les employés sans planning explicite conservent leur disponibilité continue ; deux heures identiques signifient 24 h. Les horaires automatiques du club se règlent depuis Personnel ou Menu (20–04 proposés, automatisme à activer). Le bouton Ouvert/Fermé crée une dérogation jusqu'au prochain changement d'horaire. Le ménage et la maintenance travaillent pendant la fermeture selon leur planning ; les employés hors service sont absents, et une tâche engagée est terminée avant le départ. Les salaires sont calculés au prorata du temps réellement présent, y compris la fin d'une tâche après le service. Les journées tournent à minuit, enregistrent un rapport financier et laissent le ménage et les tâches en cours continuer. L'affluence combine une courbe faible en journée/forte le soir, un pic vendredi-samedi conservé après minuit, la réputation, les tarifs et la météo. La pluie apparaît en pixels à l'extérieur et réduit les arrivées de 12 à 30 % suivant son intensité ; elle évolue naturellement toutes les 2 à 6 heures. Plannings, météo, dérogation et paie en cours sont sauvegardés. Les anciennes sauvegardes gardent leur heure affichée. Aperçus : `build/Apercus-V55/`.

**V54 — Hygiène des sanitaires.** Une utilisation normale augmente progressivement la saleté sans déclencher le ménage. Les WC ont 8 % de risque d'éclaboussure par visite, les urinoirs 12 % (paramètres dans `Plumbing.URINE_CHANCE`). La saleté des WC/urinoirs augmente de 6 à 10 points par utilisation, moitié moins avec le revêtement lavable. Une flaque jaune occasionnelle ou une jauge à 100 % déclenche une intervention : nettoyage du sanitaire et de sa flaque ensemble, jauge remise à zéro. La fiche affiche une jauge de saleté actualisée et l'objet devient très sale à saturation. Les incidents persistent dans les sauvegardes ; déplacer ou vendre le sanitaire laisse son ancienne flaque à nettoyer. Les fuites restent à la charge des techniciens. Aperçu : `build/Apercus-V54/sanitaires.png`.

**V53 — Respiration naturelle.** La tête, le cou et les épaules suivent ensemble une respiration verticale très légère, sur un pixel natif. Les appuis restent fixes et les détails des cheveux restent stables pendant le mouvement. Le cycle neutre respecte la pause et la vitesse du jeu. Aperçu animé : `build/Apercus-V53/repos.gif`.

**V52 — Posture de repos animée.** La posture à genoux dispose d’un cycle neutre de quatre secondes : légère respiration des épaules et petit réajustement de la main sur la cuisse. La tête et les appuis au sol restent fixes. Les six images sont dessinées à la résolution native, de face comme de dos, avec les couches de vêtements et de cheveux synchronisées. Le cycle respecte la pause et la vitesse du jeu. Aperçu animé : `build/Apercus-V52/repos.gif`.

**V51 — Dégradation et fuites.** Les sanitaires s’encrassent visuellement par niveaux et demandent davantage de nettoyage. Les WC et urinoirs peuvent laisser des traces jaunes après usage. WC, lavabos, urinoirs et douches s’usent et peuvent fuir : gouttes bleues, icône de réparation, équipement temporairement indisponible. L’eau se propage sur le sol libre de la pièce et augmente le travail de ménage. Les techniciens réparent les fuites en priorité ; les femmes de ménage nettoient les flaques, qui restent présentes après réparation. Les pannes, l’usure et le nettoyage restant sont sauvegardés. Guide : `build/GUIDE-V51.md` ; aperçu : `build/Apercus-V51/fuites.png`.

**V50 — Files et hygiène des sanitaires.** Les clients font une file visible devant les toilettes, avancent dans l’ordre d’arrivée et signalent leur besoin par une bulle WC jaune ou rouge. Les motifs d’attente distinguent sanitaires occupés, accès bloqué et absence de WC adapté. La plupart des clients quittent le club si l’attente dure trop ; les accidents deviennent exceptionnels. Une alerte signale la saturation. Après les toilettes, les clients rejoignent un lavabo et se lavent les mains. WC, urinoirs et lavabos se salissent avec l’usage : le ménage les entretient entre deux utilisateurs, après les flaques prioritaires. Sélectionner un équipement permet d’acheter un revêtement facile à nettoyer (120 $), un distributeur de savon pour lavabo (60 $) ou du matériel de ménage amélioré pour un employé (180 $). Les améliorations, leur coût et la propreté sont sauvegardés. Guide : `build/GUIDE-V50.md` ; aperçu : `build/Apercus-V50/sanitaires.png`.

**V49 — Boissons et sanitaires.** Les boissons réellement servies au bar augmentent le besoin de toilettes et accélèrent sa progression pendant un moment. Les hommes peuvent utiliser les WC ou les urinoirs et privilégient ces derniers ; les femmes utilisent les WC, y compris les WC défraîchis du départ. Chaque client réserve son sanitaire et attend si aucun n'est disponible. Les accès bloqués, les portes et les objets encore en livraison sont pris en compte. Si le besoin devient critique sans accès à un sanitaire adapté, une flaque jaune apparaît : la satisfaction et la réputation baissent, le client part et des témoins mécontents peuvent partir aussi. Le ménage nettoie les flaques en priorité. Elles restent dans la sauvegarde jusqu'au nettoyage. La fiche d'un client affiche son besoin et ses boissons consommées ; le compteur des déchets inclut les flaques. Aperçus dans `build/Apercus-V49/`.

**V47 — Cône de signalisation.** Les cônes de livraison ont un corps orange circulaire et effilé, deux bandes blanches qui suivent son arrondi et un pied carré plat. Leur silhouette plus élancée remplace l'ancienne forme pyramidale. Aperçus dans `build/Apercus-V47/`.

**V46 — Fumée BD.** Le freinage et le démarrage font apparaître plusieurs petites bouffées rondes en pixel art, crème avec des ombres roses et mauves. Elles gonflent, se séparent en petits nuages et disparaissent rapidement, accompagnées de quelques éclats. Le freinage les émet progressivement près des roues ; le départ accentue la traînée des roues arrière. Les bouffées restent sur la route quand la fourgonnette s'éloigne, et la pause fige leur animation. Aperçus dans `build/Apercus-V46/`.

**V44 — Toit unifié.** Le toit de la fourgonnette forme une seule coque, de la cabine à la caisse. Il est plus fin, avec des épaules dont la couleur se raccorde aux flancs et deux rainures discrètes et continues. Les portes, la suspension et les livraisons conservent leur fonctionnement. Aperçus dans `build/Apercus-V44/`.

**V43 — Fourgonnette arrondie.** La carrosserie jaune devient légèrement plus large, avec des flancs galbés, un toit bombé aux quatre coins arrondis, une cabine et des pare-chocs adoucis. Deux rainures peu contrastées parcourent le toit, et les joints des panneaux restent discrets. Les portes, le marchepied et les passages de roue suivent cette nouvelle silhouette. Les poses de freinage et de démarrage sont redessinées sur la grille native, roues au sol et feux alignés. Les livraisons, commandes et sauvegardes conservent leur fonctionnement. Aperçus dans `build/Apercus-V43/`.

**V41 — Arrivées et départs animés.** La fourgonnette DLH arrive plus vivement, ralentit progressivement devant le club et s'arrête exactement à sa place. La suspension bascule légèrement au freinage puis se stabilise avant l'ouverture des portes ; de petites bouffées de poussière apparaissent près des roues. Au départ, elle accélère depuis l'arrêt avec une bascule inverse. Les effets restent sur la grille pixel art et la poussière reste ancrée à la route. La pause fige le mouvement, et une sauvegarde reprend la vitesse et la phase en cours sans répéter les effets déjà déclenchés. Les warnings conservent leur pulsation douce. Aperçus dans `build/Apercus-V41/`.

**V40 — Petite fourgonnette DLH.** Le véhicule de livraison devient une fourgonnette jaune compacte, aux formes plus rondes, avec le marquage rouge DLH. Ses portes arrière s'ouvrent sur les cartons et un petit marchepied. Les livreurs, leurs trajets et les cônes suivent les nouvelles dimensions. La carrosserie reste stable ; seuls les petits warnings pulsent doucement à l'arrêt, à un rythme indépendant de l'accélération du jeu. La pause fige aussi ces lumières. Les commandes et sauvegardes existantes restent compatibles. Aperçus dans `build/Apercus-V40/`.

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
- **Orientation automatique (V42)** : pendant la pose, un meuble se tourne tout seul selon ce qui l'entoure : dos au mur (canapé, lit, armoire, étagère, WC, lavabo, miroir, néon…), vers sa table (chaise), vers le bar (tabouret), vers une table basse (canapé, fauteuil) ; un bar ou un comptoir d'accueil laisse la place derrière pour le personnel, et rien ne s'adosse à une porte. Sans raison claire, la rotation choisie reste. `R` tourne à la main (le jeu n'y touche plus), `A` rend l'orientation au jeu.
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
- **Mécaniques en pause** : déchets aléatoires hors accidents sanitaires, nuit 20:00-04:00 avec rapport, tarifs et agent de sécurité. L'accueil, le bar, les besoins sanitaires, la compagnie au salon, les chambres et la scène sont actifs. Le code des autres mécaniques est conservé derrière des interrupteurs (`ClubSim.FEATURES` dans `pixel/scripts/sim.gd`). En attendant, le temps s'écoule jour après jour et les salaires sont payés à l'heure.

| Action | Commande |
|---|---|
| Dock | Sélection, Construire (outils et plan des pièces), Mobilier, Personnel, Clients, Menu |
| Ouvrir / fermer | Bouton sous l'horloge ou `O` |
| Temps | `Espace` pause · `1` normal · `2` accéléré (boutons sous l'horloge) |
| Tracer une pièce | `T` ou Construire → Pièce, puis cliquer-glisser |
| Porte / fenêtre | `P` / `F`, puis cliquer un mur |
| Parking | `K` : Places · clic : une place · glisser : rangée · `R` : tourner · Construire → Allée : passage libre |
| Mobilier | `B` ; `Maj` + clic pour poser en série ; orientation automatique pendant la pose ; `R` pour tourner à la main, `A` pour revenir à l'automatique |
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
| `pixel/scripts/deliveries.gd`, `delivery_courier.gd`, `delivery_prop.gd`, `delivery_dust.gd`, `delivery_smoke_art.gd` | Regroupement des achats, file d'attente, conduite et suspension de la fourgonnette, bouffées BD aux roues, transport des colis, accès et déballage ; reprise de livraison sauvegardée |
| `pixel/scripts/hud.gd`, `ui_kit.gd`, `editors.gd` | Interface rétro pixel art : fenêtres déplaçables, dock, historique, éditeurs d'apparence et de revêtements |
| `pixel/scripts/main.gd` | Caméra au pixel, outils, historique, sauvegarde, tests intégrés |
| `pixel/shaders/palette.gdshader` | Index de palette → couleur, contour de sélection, teinte d'aperçu |
| `tools/pixelart/pa_iso.py`, `pa_furniture.py` | Peintre isométrique natif et 57 meubles, objets et déchets × 4 orientations ; sièges, lits, scène et douche exportés aussi en parties (assise, dossier, accoudoirs, tête de lit, barre, murs, vitres, porte) avec leur emprise au sol, pour le tri de profondeur |
| `tools/pixelart/pa_chars.py`, `pa_dress.py`, `pa_hair.py`, `pa_charsheet.py` | Corps, poses, jambes au pixel, visages, tenues, coiffures, planches de personnages |
| `tools/pixelart/pa_escort.py` | Tenues des escorts par standing : cartes de pixels du buste, bas, résille, gants, bijoux, jupes |
| `tools/pixelart/pa_tiles.py`, `pa_draw2d.py` | Sols (dont bitume fissuré et dalles de trottoir), murs, ouvertures, décor de rue, halos ; tracés 2D |
| `tools/pixelart/pa_street.py` | Bordures, marquages usés, butées de roues, herbes, grilles, taches d'huile, fissures, panneau P |
| `tools/pixelart/pa_delivery.py` | Export de la fourgonnette fermée/ouverte, chargement variable, colis de trois tailles, diables/chariots et cônes à la résolution native |
| `tools/pixelart/pa_truck.py`, `pa_truck_patterns.py` | Fourgonnette aux volumes arrondis, toit rainuré, flancs galbés, portes, soute, poses de suspension et points lumineux ; peinture jaune et marquage DLH |
| `tools/pixelart/pa_parking.py` | Grande texture de parking sans raccord visible, fissures, grain fin, terre et mousse en bordure, points d'implantation des herbes dans les crevasses |
| `tools/pixelart/pa_trees.py` | Arbres de rue au pixel (3 silhouettes statiques) et fosses d'arbre |
| `tools/pixelart/pa_ui.py` | Cadres de fenêtres, boutons, icônes 10 × 10 et émotes de l'interface rétro |
| `tools/pixelart/pa_cast.py`, `make_sheets.py` | Distribution de référence et planches d'aperçu |

## Construire et vérifier

Exécuter `./Build.ps1`. Le script effectue, dans l'ordre :

1. la régénération de tout le pixel art (si Python est présent) ;
2. l'import du projet ;
3. les tests : `model_test.gd` (petit local vétuste de départ avec une seule chambre, déchets accessibles, valeur des revêtements, plan complet de démonstration avec réception et urinoirs, navigation, import 3D, validations), `art_test.gd` (grille 32 × 16, frames 32 × 48, bords nets, index de palette, chaque frame de corps d'un seul tenant avec les pieds au sol et des jambes de taille constante en marchant, calques de chaque apparence, sprites de tout le catalogue, icônes 10 × 10 et cadres de l'interface), la scène (`--smoke-test`), la simulation (`--sim-test` : club fermé sans client, techniciens qui nettoient, file d'attente dehors sans accueil avec clients impatients, aucune entrée sans réceptionniste, puis entrées payées à l'accueil, boissons servies au bar, escort au salon, départ à la fermeture) et l'interface dans une vraie fenêtre (`--ui-test`, y compris le déplacement d'une fenêtre par sa barre de titre) ;
4. l'export de `build/Construction-V63-Poussiere.exe`.

Le test `--delivery-test` couvre le regroupement avant arrivée, les achats de la tournée suivante, deux livreurs, les fantômes inutilisables, le paiement unique, l'annulation et le remboursement, le déplacement en cours de transport, la reprise après sauvegarde, les accès bloqués et leur rétablissement, ainsi que les anciennes parties. Le test d'interface achète aussi deux objets à la souris, ouvre le suivi, observe le transport et le déballage puis vérifie leur installation et le départ du camion.

Le test `delivery_dust_test.gd` vérifie la netteté des textures BD, l'ancrage des bouffées sous un véhicule mobile, la pause, leur expiration et la libération des sprites, y compris après plusieurs émissions rapprochées.

Le test `client_needs_test.gd` vérifie les besoins après consommation, les WC et urinoirs selon le client, les réservations et accès bloqués, les accidents et départs, le nettoyage effectif, la pause, ainsi que la sauvegarde des flaques et sa compatibilité avec les anciennes parties.

Il vérifie aussi le freinage sans dépassement, l'arrêt exact, la stabilité du trajet selon le pas de simulation, l'accélération au départ, les bascules opposées, l'ancrage de la poussière sur la route, la pause et la reprise des anciennes sauvegardes sans répéter les effets.

Le test `parking_fit_test.gd` couvre les quatre orientations, une place seule et les rangées, l'alignement et la fusion, les entrées dégagées, les bordures communes, le coût, la réutilisation du bitume, les sauvegardes et leur migration. Le test d'interface vérifie avec des événements souris et clavier le clic, le glisser, la rotation, les boutons de prolongement, la pose d'une allée, le refus rouge, l'annulation et le rétablissement.

Les chantiers sont testés dans `model_test.gd` (ordre des phases, coulée case par case, rangs de parpaings, pourcentage et temps restant, agrandissement qui garde le travail fait, annulation qui ne défait pas les travaux, sauvegarde et données abîmées, accès et mobilier refusés) et dans `--smoke-test` (trois ouvriers, balisage, sprites révélés égaux au pourcentage affiché, panneau d'avancement, différence facturée, fin du chantier et pièce utilisable). Les extensions sont testées dans `model_test.gd` (départ du mur ou de l'intérieur, surface au-delà des murs, refus, fusion, mur supprimé, contour, pièce en L agrandie deux fois, chantier en L, sauvegardes, suppression en cascade) et dans `--smoke-test` (départ près d'un mur, sur le sol ou sur le terrain libre, tracé réel, fusion à la fin, passage et mobilier, annulation sans séparation). `--setup=extension --ext-stage=hover|drag|works|done|new` photographie chaque étape.

`--setup=site --site-progress=0.4` photographie un chantier à un stade donné et `--site-sequence=12` en photographie toute la progression.

Le test `quick_service_test.gd` vérifie aussi les trajets et le placement au sol, la conservation des tenues, la pose immobile, le paiement unique, l'état du lit et la libération des personnages après une fin, une annulation ou une modification de la pièce.

Les journaux sont écrits dans `tests/artifacts/`. `-- --capture=<png> --zoom=3 --focus=x,z --sim-seconds=12 --pause` produit une capture reproductible, sans lire ni écrire de sauvegarde.

L'ancien code 3D (V16 et antérieures) a été retiré du projet en V18 ; les exécutables et guides de ces versions restent dans `build/`.

## Périmètre et crédits

Il s'agit d'un prototype sur un étage. La simulation reste volontairement lisible : pas de besoins détaillés, de recrutement avec compétences, d'événements, ni de sons. Les tenues restent suggestives, sans nudité. Le club fonctionne comme dans l'artwork : bar, salon, scène, salons privés.

Code, sprites, tuiles et interface ont été créés pour le projet. L'artwork de référence n'est pas embarqué dans le jeu. Godot est sous licence MIT : voir `build/LICENCES.txt` et `build/GODOT-TIERS.txt`. Pixelify Sans est sous SIL OFL : voir `build/PIXELIFY-OFL.txt`. Le jeu ne télécharge aucune ressource.
