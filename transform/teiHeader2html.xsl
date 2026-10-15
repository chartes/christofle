<?xml version="1.0" encoding="UTF-8"?>
<!-- Page de titre de Christofle (route /api/dts/cover) : modèle commun page-de-titre.xsl.
     Écart : édition électronique = respStmt de la conception du site web. -->
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:import href="page-de-titre.xsl"/>

  <xsl:variable name="th-edition-electronique" select="$th-ts/tei:respStmt[contains(tei:resp, 'site web')]/tei:persName"/>
</xsl:transform>
