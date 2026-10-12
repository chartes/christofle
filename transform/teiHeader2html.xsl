<?xml version="1.0" encoding="UTF-8"?>
<!-- Page de titre de Christofle (route /api/dts/cover?id=christofle), reprise de celle des
     chroniques latines. Écarts marqués [christofle]. -->
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"/>

  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml" lang="fr">
      <div id="aside">to delete</div>
      <div id="center">
        <div id="main">
          <div id="article"><xsl:apply-templates select="//tei:fileDesc/tei:titleStmt"/></div>
        </div>
      </div>
    </html>
  </xsl:template>

  <xsl:template match="tei:titleStmt">
    <div class="titlestmt">
      <!-- Premier titre uniquement -->
      <h1 class="head">
        <xsl:value-of select="normalize-space(tei:title[1])"/>
      </h1>

      <!-- Éditeurs. [christofle] le <principal> contient un persName avec rôle et affiliation :
           on n'en garde que le prénom et le nom. -->
      <xsl:if test="tei:principal">
        <p class="editors">
          <span class="editors-label">Édité par </span>
          <xsl:for-each select="tei:principal">
            <span class="editor">
              <xsl:value-of select="normalize-space(concat(.//tei:forename[1], ' ', .//tei:surname[1]))"/>
            </span>
            <xsl:choose>
              <xsl:when test="position() = last() - 1"> et </xsl:when>
              <xsl:when test="position() &lt; last()">, </xsl:when>
            </xsl:choose>
          </xsl:for-each>
        </p>
      </xsl:if>

      <!-- [christofle] Pas d'<editor> : l'édition électronique est le respStmt de la
           conception du site web (Florence Clavaud). -->
      <xsl:for-each select="tei:respStmt[contains(tei:resp, 'site web')]/tei:persName">
        <p class="editors">
          <span class="editors-label">Édition électronique par </span>
          <span class="editor">
            <xsl:value-of select="normalize-space(concat(tei:forename, ' ', tei:surname))"/>
          </span>
        </p>
      </xsl:for-each>

      <!-- [christofle] publicationStmt/date vaut « mai 2015-.... » : on n'affiche que l'année. -->
      <span class="date">
        <xsl:value-of select="replace(normalize-space(../tei:publicationStmt/tei:date[1]), '^\D*(\d{4}).*$', '$1')"/>
      </span>
    </div>
  </xsl:template>

</xsl:transform>
