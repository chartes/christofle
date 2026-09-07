L’année 1437 dans la pratique de Pierre Christofle, notaire du Châtelet d’Orléans
===
* Elec 27. http://elec.enc.sorbonne.fr/christofle/
* Sources XML de l’édition (Kouky Fianu, Anne Fortier et Florence Clavaud).

## Publication DoTS

Le document à ingérer est `data/christofle.xml`. Il contient les 387 minutes,
les listes mensuelles et l’index précalculé des types d’actes. La feuille
`transform/christofle.xsl` lit ces listes dans les fragments servis par DoTS ;
elle ne nécessite plus de fichier XML compagnon dans `transform/`.
Le fichier `xml/Christofle-septembre2016.xml` reste la source historique.

Après modification des dates, numéros, identifiants, types juridiques ou résumés
des minutes, régénérer les index avant ingestion (Python et `lxml` requis) :

```sh
python scripts/build_indexes.py data/christofle.xml data/christofle.xml
```

Une simple correction dans la transcription ne nécessite pas de régénérer les index.
Déployer le XML enrichi dans DoTS avant, ou en même temps que, cette XSL : l’ancienne
version du XML sans listes ne permet pas à la nouvelle feuille de produire les index.
La feuille conserve son import du moteur partagé `../hteiml/xsl/tei2html.xsl`.

Pierre Christofle fut notaire royal à Orléans de 1423 à 1450, attaché à la prévôté pour qui il rédigeait des contrats portant le sceau de l’institution. Comme ses confrères, Pierre Christofle inscrivait dans un registre et en une forme abrégée les conventions qu’il attestait. Ces notes, au nombre de 387, rédigées entre le 1er janvier et le 29 décembre 1437, sont ici éditées dans leur ensemble. L’édition, indexée et prochainement téléchargeable, permet l’enquête sur le lexique des actes. Elle accompagne et complète une version imprimée, publiée dans la collection « Mémoires et documents de l’École des chartes », qui propose un essai interprétatif de cette documentation.
