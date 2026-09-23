# Christofle — L’année 1437 dans la pratique de Pierre Christofle, notaire du Châtelet d’Orléans

Édition électronique du corpus `christofle`, servie par l’API DoTS de l’École nationale des chartes.

## L’édition

- **Titre** : *L’année 1437 dans la pratique de Pierre Christofle, notaire du Châtelet d’Orléans*
- **Chercheuse principale** : Kouky Fianu (Université d’Ottawa)
- **Assistante de recherche** : Anne Fortier (Université d’Ottawa)
- **Conseil scientifique** : Olivier Guyotjeannin (École nationale des chartes)
- **Première transcription** : Catherine Coulombes (Université d’Ottawa)
- **Indexation, enrichissement du document TEI** : Danny Bertrand (Université d’Ottawa)
- **Modélisation, conversion en XML/TEI P5, conception du site d’édition numérique** : Florence Clavaud (Archives nationales de France, Centre Jean-Mabillon)
- **Mise à disposition des documents** : Conseil général du Loiret, Archives départementales
- **Financements** : Conseil de recherche en sciences humaines du Canada ; Fonds québécois de la recherche sur la société et la culture
- **Éditeurs** : GREPSOMM (Groupe de recherche sur les pouvoirs et les sociétés de l’Occident médiéval et moderne, Université du Québec à Montréal) ; École nationale des chartes
- **Date de publication** : mai 2015-….
- **Licence** : Creative Commons « Paternité – Pas d’Utilisation Commerciale – Pas de Modification ; 2.0 France »

## Contenu de la branche `migration`

Cette branche suit l’arborescence attendue par DoTS.

```
data/        les fichiers TEI servis par BaseX
metadata/    dots_metadata_mapping.xml et collection.tsv
transform/   la feuille XSL du corpus et son fichier compagnon
README.md
```

### `data/`

- `christofle.xml` — le document TEI unique du corpus (index et arguments de mois précalculés).

### `metadata/`

- `dots_metadata_mapping.xml` — la carte des métadonnées DoTS ; elle ne déclare qu’une seule source, `./collection.tsv`.
- `collection.tsv` — la fiche de la collection `christofle` (`id`, `title`, `short_title`, `creator`, `publisher`, `issued`, `description`).

Le corpus ne comporte **pas** de fichier de métadonnées au niveau document : la base n’en contient aucun et la carte n’en réclame aucun.

### `transform/`

- `christofle.xsl` — la feuille de transformation TEI → HTML du corpus (minutes, apparat, index, folios, fac-similés).
- `christofle-index-lettres.xml` — fichier compagnon lu par la feuille via `document('christofle-index-lettres.xml')` ; il doit rester à côté de la XSL.

### Ce qui ne figure pas ici

- Les images des fac-similés (191 folios et leurs vignettes, ainsi que les figures de l’introduction) ne sont pas versionnées : leur hébergement n’est pas arrêté. La feuille les appelle sous `/images/christofle/`.
- La feuille de style d’habillage (`christofle.customCss.css`) et la configuration du corpus (`christofle.conf.json`) relèvent du dépôt `dots-vue-elec-settings`.
- Le registre `dots/*_register.xml` est reconstruit par BaseX à l’ingestion et n’est pas versionné.

## Provenance

Les fichiers de `data/` et de `metadata/` ont été exportés de la base BaseX `christofle` le 23 septembre 2026, par l’API REST, en lecture seule. Les fichiers de `transform/` proviennent du répertoire de transformation de l’instance DoTS locale à la même date.
