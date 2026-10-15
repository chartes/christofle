<?xml version="1.0" encoding="UTF-8"?>
<!-- Liste repliable, module commun (2026-10-14).
     Rendu de la page « Références citées » des Chroniques latines, rendu générique : des groupes
     (● Romains (12)) ouverts à l'arrivée, et dans chaque groupe une ligne repliable par entrée
     (○ Caesar, Bellum gallicum … 21 passages), qui s'ouvre sur son contenu.
     Import : <xsl:import href="liste-repliable.xsl"/> après le xsl:import de hteiml ; la copie
     maîtresse est transform/commun/liste-repliable.xsl, chaque corpus en garde une copie à côté
     de sa feuille pour que son dépôt reste autonome. Aucun JavaScript : details/summary.
     La CSS est le bloc « Liste repliable » de la customCss du corpus.

     Contrat HTML :
       div.lr-liste                                  enveloppe (le corpus la pose)
         details.lr-groupe[open]                     groupe, ouvert à l'arrivée
           summary > hN.head.lr-groupe-titre > span.lr-groupe-nb   titre, (nombre)
                                                     (2026-10-15 : vrai intertitre, h2 par défaut,
                                                     mis en forme par hteiml, comme les rubriques
                                                     de bibliographie)
           details.lr-entree[id]                     entrée, repliée
             summary > span.lr-entree-titre + span.lr-entree-nb  titre, « N unités » à droite
             div.lr-entree-corps                     contenu déplié
       ul.lr-colonnes > li                           liste courte en colonnes (dans un corps)
       Une entrée visée par un renvoi (.dots-target sur elle ou dans elle) s'affiche ouverte. -->
<xsl:stylesheet version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs">

  <!-- Groupe : titre et nombre d'entrées ; contenu = les entrées (lr-entree). -->
  <xsl:template name="lr-groupe">
    <xsl:param name="id" as="xs:string?" select="()"/>
    <xsl:param name="titre"/>
    <xsl:param name="nb" select="()"/>
    <xsl:param name="ouvert" as="xs:boolean" select="true()"/>
    <xsl:param name="niveau" as="xs:integer" select="2"/>
    <xsl:param name="contenu"/>
    <details class="lr-groupe">
      <xsl:if test="$id"><xsl:attribute name="id" select="$id"/></xsl:if>
      <xsl:if test="$ouvert"><xsl:attribute name="open">open</xsl:attribute></xsl:if>
      <summary>
        <xsl:element name="h{$niveau}">
          <xsl:attribute name="class">head lr-groupe-titre</xsl:attribute>
          <xsl:copy-of select="$titre"/>
          <xsl:if test="exists($nb)">
            <xsl:text> </xsl:text>
            <span class="lr-groupe-nb"><xsl:value-of select="concat('(', $nb, ')')"/></span>
          </xsl:if>
        </xsl:element>
      </summary>
      <xsl:copy-of select="$contenu"/>
    </details>
  </xsl:template>

  <!-- Entrée : titre à gauche, « nb unite(s) » à droite ; contenu déplié dans lr-entree-corps. -->
  <xsl:template name="lr-entree">
    <xsl:param name="id" as="xs:string?" select="()"/>
    <xsl:param name="titre"/>
    <xsl:param name="nb" select="()"/>
    <xsl:param name="unite" as="xs:string" select="''"/>
    <xsl:param name="unites" as="xs:string" select="concat($unite, 's')"/>
    <xsl:param name="contenu"/>
    <details class="lr-entree">
      <xsl:if test="$id"><xsl:attribute name="id" select="$id"/></xsl:if>
      <summary>
        <span class="lr-entree-titre"><xsl:copy-of select="$titre"/></span>
        <xsl:if test="exists($nb)">
          <xsl:text> </xsl:text>
          <span class="lr-entree-nb">
            <xsl:value-of select="$nb"/>
            <xsl:if test="$unite != ''">
              <xsl:value-of select="concat(' ', if (number($nb) gt 1) then $unites else $unite)"/>
            </xsl:if>
          </span>
        </xsl:if>
      </summary>
      <div class="lr-entree-corps"><xsl:copy-of select="$contenu"/></div>
    </details>
  </xsl:template>

</xsl:stylesheet>
