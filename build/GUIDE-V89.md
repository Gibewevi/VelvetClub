# Construction V89 — Priorités

Exécutable : `Construction-V89-Priorites.exe`. Il utilise la même sauvegarde que les versions précédentes.

## La priorité se choisit aussi dans l'onglet Équipe

Les priorités du personnel existent depuis la V86, mais elles n'apparaissaient que dans le panneau de sélection, en cliquant l'employé dans le club. Dans **Personnel → Équipe**, rien ne les montrait.

- Chaque **femme de ménage**, **technicien** et **employé polyvalent** a maintenant un bouton **« Priorité : … »** sur sa fiche dans Équipe.
- Cliquez-le pour choisir dans la liste :
  - **femme de ménage** et employé polyvalent : Aucune, Sanitaires, Lits, Poubelles, Sols mouillés, Déchets au sol ;
  - **technicien** : Aucune, Réparations, Sanitaires, Sols mouillés, Déchets au sol.
- Exemple : « Sanitaires » sur une femme de ménage. Dès qu'elle est libre, elle s'occupe d'abord de l'eau par terre dans les toilettes, puis des WC, lavabos et douches sales. Ensuite seulement, elle reprend son travail habituel.
- Avec le filtre par poste de la V88, cliquez le visage de la femme de ménage pour régler toutes vos femmes de ménage d'un coup d'œil.
- Le choix reste aussi possible dans le panneau de sélection de l'employé (section PRIORITÉ).

## Vérifié

- Test de scène : le bouton de priorité est présent sur les fiches. Choisir « Sanitaires » le règle pour cette femme de ménage et le bouton l'affiche.
- Toutes les suites passent.
- Contrôlé dans le jeu sur capture.

## Aperçu (`Apercus-V89/`)

- `priorite-dans-equipe.png` : les femmes de ménage dans Équipe, avec leur bouton de priorité.
