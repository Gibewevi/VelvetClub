# Construction V87 — Cloisons

Exécutable : `Construction-V87-Cloisons.exe`. Il utilise la même sauvegarde que les versions précédentes.

## Les cloisons posées avant la V86 coupent aussi la pièce

En V86, une cloison qui ferme entièrement une partie d'une pièce en fait une nouvelle pièce. Mais une cloison tracée avant la V86 restait une simple cloison : en cliquant, toute la pièce était sélectionnée.

- Au chargement de la partie, chaque cloison qui ferme déjà une partie d'une pièce la coupe maintenant, comme si elle venait d'être tracée.
- La nouvelle pièce garde le type et les finitions de la pièce d'origine. Cliquez-la pour la sélectionner seule et changer son type.
- Les portes posées sur la cloison deviennent des portes entre les deux pièces.
- Rien n'est facturé : la valeur du club reste la même.
- Vérifié sur une copie de votre partie : le hall de 96 m² devient un hall de 80 m² et une pièce de 16 m² en haut à droite.

## Vérifié

- Test du modèle : une ancienne sauvegarde avec une pièce fermée par une cloison se charge en deux pièces, porte conservée, à la même valeur.
- Toutes les suites passent.
