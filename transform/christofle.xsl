<?xml version="1.0" encoding="UTF-8"?>
<!-- Christofle : surcharge de hteiml, reconstruite le 13/10/2026 en partant du rendu
     hteiml nu.

     Principe : chaque page reprend le DOM de l'ÉLEC (mêmes id et mêmes classes que
     elec.enc.sorbonne.fr/christofle), de sorte que la CSS historique (theme/christofle.css)
     s'applique presque telle quelle. Aucun JavaScript : dots-vue retire <script> et
     les attributs on…, la note d'apparat s'affiche donc au survol en CSS.

     Pages : accueil, introduction, édition des notes (sommaire des mois), mois, note
     (minute), index des types d'actes, index des lieux et personnes. -->
<xsl:transform version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:chr="urn:christofle"
  exclude-result-prefixes="tei xs chr">

  <xsl:import href="../../renderers/hteiml/xsl/tei2html.xsl"/>

  <!-- Pas d'indentation : dots-vue compile la sortie en gabarit Vue, qui retire les blancs
       contenant un saut de ligne entre deux balises (« Adam de » devenait « Adamde »). -->
  <xsl:output indent="no"/>

  <!-- Unité qui porte tout l'index des lieux et personnes (servie entière). -->
  <xsl:variable name="index-ref" select="'r65205'"/>

  <xsl:variable name="mois" select="('janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
                                     'août', 'septembre', 'octobre', 'novembre', 'décembre')"/>

  <xsl:key name="note-par-id" match="tei:note[@xml:id]" use="@xml:id"/>

  <!-- ================================================================
       Enveloppe DoTS
       hteiml ne connaît pas <dts:wrapper> et l'affiche en rouge : on le traverse.
       ================================================================ -->
  <xsl:template match="*[local-name() = 'wrapper']">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Première lettre en capitale (« quittance » → « Quittance »). -->
  <xsl:function name="chr:capitale" as="xs:string">
    <xsl:param name="s"/>
    <xsl:variable name="t" select="normalize-space($s)"/>
    <xsl:sequence select="concat(upper-case(substring($t, 1, 1)), substring($t, 2))"/>
  </xsl:function>

  <!-- « 1er juin » → 1<sup>er</sup> juin, comme l'ÉLEC. -->
  <xsl:template name="date-ordinal">
    <xsl:param name="texte"/>
    <xsl:analyze-string select="$texte" regex="(^|\s)1er(\s|$)">
      <xsl:matching-substring><xsl:value-of select="regex-group(1)"/>1<sup>er</sup><xsl:value-of select="regex-group(2)"/></xsl:matching-substring>
      <xsl:non-matching-substring><xsl:value-of select="."/></xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <!-- Folio : @n « 76 » ou « 82v » → « 76 r° », « 82 v° ». -->
  <xsl:function name="chr:folio" as="xs:string">
    <xsl:param name="n"/>
    <xsl:variable name="n" select="normalize-space($n)"/>
    <xsl:variable name="fin" select="substring($n, string-length($n))"/>
    <xsl:sequence select="if ($fin = ('r', 'v'))
                          then concat(substring($n, 1, string-length($n) - 1), ' ', $fin, '°')
                          else concat($n, ' r°')"/>
  </xsl:function>

  <!-- ================================================================
       Accueil (ÉLEC index.html : section#content.titlePage)
       ================================================================ -->
  <xsl:template match="tei:div[@type = 'homePageAbstract']">
    <section id="content" class="titlePage">
      <xsl:for-each select="tei:figure[@type = 'homeImage']">
        <section id="image">
          <figure>
            <img src="../../images/christofle/{substring-after(tei:graphic/@url, 'images/')}"
                 alt="{normalize-space(tei:figDesc)}"/>
            <figcaption><xsl:apply-templates select="tei:figDesc/node()"/></figcaption>
          </figure>
        </section>
      </xsl:for-each>
      <section id="titlePage">
        <article>
          <div><xsl:apply-templates select="tei:p"/></div>
        </article>
      </section>
    </section>
  </xsl:template>

  <!-- ================================================================
       Introduction (ÉLEC introduction/partie-N.html : section#content.paratext)
       La page « Introduction » (servie sans ses parties) rend la première partie,
       comme le menu de l'ÉLEC, qui menait à partie-1.html.
       ================================================================ -->
  <xsl:template match="tei:div[tei:argument[@ana = '#intro-index']]">
    <xsl:variable name="arg" select="tei:argument[@ana = '#intro-index']"/>
    <xsl:variable name="partie" select="$arg/tei:floatingText[@type = 'first-part']/tei:body"/>
    <section id="content" class="paratext">
      <xsl:call-template name="intro-menu">
        <xsl:with-param name="liste" select="$arg/tei:list"/>
        <xsl:with-param name="courant" select="$arg/tei:list/tei:item[1]/tei:ref/@target"/>
      </xsl:call-template>
      <section>
        <article>
          <h1><xsl:value-of select="normalize-space($arg/tei:head)"/> &gt; <xsl:value-of select="normalize-space($partie/tei:head)"/></h1>
          <xsl:apply-templates select="$partie/node()[not(self::tei:head)]"/>
        </article>
      </section>
    </section>
  </xsl:template>

  <!-- Une partie de l'introduction servie seule (r515, r527…). -->
  <xsl:template match="tei:div[@xml:id = ('r515', 'r527', 'r658', 'r1153', 'r1288')]">
    <section id="content" class="paratext">
      <section>
        <article>
          <h1>Introduction &gt; <xsl:value-of select="normalize-space(tei:head)"/></h1>
          <xsl:apply-templates select="node()[not(self::tei:head)]"/>
        </article>
      </section>
    </section>
  </xsl:template>

  <xsl:template name="intro-menu">
    <xsl:param name="liste"/>
    <xsl:param name="courant"/>
    <nav id="specific-menu-paratext">
      <ul>
        <xsl:for-each select="$liste/tei:item">
          <li>
            <xsl:if test="tei:ref/@target = $courant"><xsl:attribute name="class">selected</xsl:attribute></xsl:if>
            <a href="?refId={substring-after(tei:ref/@target, '#')}"><xsl:value-of select="normalize-space(tei:ref)"/></a>
          </li>
        </xsl:for-each>
      </ul>
    </nav>
  </xsl:template>

  <!-- Lien de téléchargement (partie « Télécharger ») : le TEI servi par DoTS. -->
  <xsl:template match="tei:ref[starts-with(@target, 'telechargement')]" priority="12">
    <a class="externalLink" download="christofle_1437.xml"
       href="https://dots.chartes.psl.eu/api/dts/document?resource=christofle_1437&amp;mediaType=xml">
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- Liens de l'introduction vers d'anciennes pages .html de l'ÉLEC. -->
  <xsl:template match="tei:ref[@type = 'internalLink'][contains(@target, '.html')]" priority="12">
    <xsl:choose>
      <xsl:when test="@target = 'partie-4.html'"><a class="internalLink" href="?refId=r1153"><xsl:apply-templates/></a></xsl:when>
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:ref[starts-with(@target, 'http')]" priority="11">
    <a class="externalLink" href="{@target}" target="_blank" rel="noopener"><xsl:apply-templates/></a>
  </xsl:template>

  <xsl:template match="tei:graphic">
    <img src="../../images/christofle/{substring-after(@url, 'images/')}" alt="{normalize-space(../tei:figDesc)}"/>
  </xsl:template>

  <!-- ================================================================
       Édition des notes (r1609) : les douze mois et leurs jours.
       L'ÉLEC n'avait pas de page à ce niveau (son menu menait à la note 1) ;
       on reprend ses deux barres #months-list et #days-list, un mois par ligne.
       ================================================================ -->
  <xsl:template match="tei:group[tei:argument[@ana = '#notes-index']]">
    <section id="content" class="paratext">
      <section>
        <article>
          <h1>Édition des notes</h1>
          <xsl:for-each select="tei:argument/tei:list/tei:item">
            <article class="notes-mois">
              <p>
                <a class="internalLink" href="?refId={substring-after(tei:ref/@target, '#')}">
                  <xsl:value-of select="chr:capitale(tei:ref)"/>
                </a>
                <xsl:text> (</xsl:text><xsl:value-of select="tei:num"/>
                <xsl:value-of select="if (number(tei:num) = 1) then ' note' else ' notes'"/><xsl:text>) : </xsl:text>
                <xsl:for-each select="tei:list[@type = 'days']/tei:item">
                  <xsl:sort select="tei:ref/@n"/>
                  <xsl:if test="position() > 1"><span class="sep"> | </span></xsl:if>
                  <a class="internalLink" href="?refId={substring-after(tei:ref/@target, '#')}">
                    <xsl:value-of select="number(substring(tei:ref/@n, 9))"/>
                  </a>
                </xsl:for-each>
              </p>
            </article>
          </xsl:for-each>
        </article>
      </section>
    </section>
  </xsl:template>

  <!-- ================================================================
       Page d'un mois : les notes du mois, jour par jour, chacune avec son
       en-tête (numéro, type, analyse), comme le haut d'une note de l'ÉLEC.
       ================================================================ -->
  <xsl:template match="tei:group[tei:argument[@ana = '#month-index']]">
    <xsl:variable name="arg" select="tei:argument[@ana = '#month-index']"/>
    <section id="content" class="paratext mois">
      <section>
        <article>
          <h1>Édition des notes &gt; <xsl:value-of select="normalize-space($arg/tei:head)"/></h1>
          <xsl:for-each-group select="$arg/tei:list/tei:item" group-by="tei:date/@when">
            <xsl:sort select="current-grouping-key()"/>
            <h2 class="jour"><xsl:call-template name="date-ordinal"><xsl:with-param name="texte" select="normalize-space(tei:date)"/></xsl:call-template></h2>
            <xsl:for-each select="current-group()">
              <article class="mois-note">
                <p>
                  <a class="internalLink recordNumber" title="Consulter la note" href="?refId={substring-after(tei:ref/@target, '#')}">
                    <xsl:value-of select="tei:ref"/>
                  </a>
                  <xsl:text>. </xsl:text>
                  <xsl:if test="tei:term[@type = 'natureJuridique']">
                    <span class="recordType"><xsl:value-of select="chr:capitale(tei:term[@type = 'natureJuridique'][1])"/></span>
                    <xsl:text>. — </xsl:text>
                  </xsl:if>
                  <xsl:value-of select="normalize-space(tei:seg[@type = 'summary'])"/>
                </p>
              </article>
            </xsl:for-each>
          </xsl:for-each-group>
        </article>
      </section>
    </section>
  </xsl:template>

  <!-- ================================================================
       Note (minute) — ÉLEC notes/note-NNN.html
       ================================================================ -->
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]">
    <xsl:apply-templates select="tei:front/tei:argument[@ana = '#note-nav']"/>
    <section id="content" class="mins">
      <section id="facsimile" class="col">
        <xsl:apply-templates select="tei:body//tei:pb[@facs]" mode="facsimile"/>
      </section>
      <section id="text">
        <section id="edition">
          <article id="edition-text">
            <header class="recordMetadata">
              <h2>
                <span class="recordNumber"><xsl:value-of select="tei:front/tei:docTitle/tei:titlePart[@type = 'number']"/></span>
                <br/>
                <span class="recordDate">
                  <time datetime="{tei:front/tei:docDate/tei:date/@when}">
                    <xsl:call-template name="date-ordinal"><xsl:with-param name="texte" select="normalize-space(tei:front/tei:docDate/tei:date)"/></xsl:call-template>
                  </time>
                </span>
              </h2>
              <p class="recordSummary">
                <xsl:if test="tei:front/tei:index/tei:term[@type = 'natureJuridique']">
                  <span class="recordType"><xsl:value-of select="chr:capitale(tei:front/tei:index/tei:term[@type = 'natureJuridique'][1])"/></span>
                  <xsl:text>. — </xsl:text>
                </xsl:if>
                <xsl:apply-templates select="tei:front/tei:div[@type = 'summary']/tei:p/node()"/>
              </p>
            </header>
            <div><xsl:apply-templates select="tei:body/tei:div/node()"/></div>
          </article>
        </section>
      </section>
    </section>
  </xsl:template>

  <!-- Barres de navigation de l'ÉLEC : mois, jours du mois, notes voisines. -->
  <xsl:template match="tei:argument[@ana = '#note-nav']">
    <nav id="specific-menu-minutes">
      <ul id="months-list">
        <xsl:for-each select="tei:list[@type = 'months']/tei:item">
          <li>
            <xsl:if test="tei:ref/@ana = 'selected'"><xsl:attribute name="class">selected</xsl:attribute></xsl:if>
            <a href="?refId={substring-after(tei:ref/@target, '#')}"><xsl:value-of select="normalize-space(tei:ref)"/></a>
            <xsl:if test="position() != last()"><span class="sep"> | </span></xsl:if>
          </li>
        </xsl:for-each>
      </ul>
      <ul id="days-list">
        <xsl:for-each select="tei:list[@type = 'days']/tei:item">
          <xsl:sort select="tei:ref/@n"/>
          <li>
            <xsl:if test="tei:ref/@ana = 'selected'"><xsl:attribute name="class">selected</xsl:attribute></xsl:if>
            <a href="?refId={substring-after(tei:ref/@target, '#')}">
              <xsl:call-template name="date-ordinal">
                <xsl:with-param name="texte" select="normalize-space(replace(tei:ref, '^.*,', ''))"/>
              </xsl:call-template>
            </a>
            <xsl:if test="position() != last()"><span class="sep"> | </span></xsl:if>
          </li>
        </xsl:for-each>
      </ul>
      <ul id="mins-list">
        <xsl:for-each select="tei:list[@type = 'minutes']/tei:item">
          <li>
            <xsl:if test="tei:ref/@ana = 'selected'"><xsl:attribute name="class">selected</xsl:attribute></xsl:if>
            <xsl:if test="tei:ref/@type = 'next'"><span class="sep"> &gt;&gt; </span></xsl:if>
            <a href="?refId={substring-after(tei:ref/@target, '#')}"><xsl:value-of select="normalize-space(tei:ref)"/></a>
            <xsl:choose>
              <xsl:when test="tei:ref/@type = 'previous'"><span class="sep"> &lt;&lt; </span></xsl:when>
              <xsl:when test="tei:ref/@type = 'next'"/>
              <xsl:when test="following-sibling::tei:item[1]/tei:ref/@type = 'minute'"><span class="sep"> | </span></xsl:when>
            </xsl:choose>
          </li>
        </xsl:for-each>
      </ul>
    </nav>
  </xsl:template>

  <!-- Folio dans le texte : « [76 r°] » (crochets posés par la CSS .pb). -->
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//tei:pb">
    <span class="pb"><xsl:value-of select="chr:folio(@n)"/></span>
  </xsl:template>

  <!-- Colonne des fac-similés : un folio par <pb>. La vignette s'ouvre en grand
       sans script (<details>). -->
  <xsl:template match="tei:pb" mode="facsimile">
    <xsl:variable name="fichier" select="substring-after(@facs, 'images/sources/')"/>
    <figure>
      <details>
        <summary>
          <span class="pageUrl">Fol. <xsl:value-of select="chr:folio(@n)"/></span>
          <img class="vignette" src="../../images/christofle/vignettes/{substring-before($fichier, '.jpg')}_ptt.jpg"
               alt="Fac-similé du folio {chr:folio(@n)}"/>
        </summary>
        <img class="grande" src="../../images/christofle/sources/{$fichier}" alt="Fac-similé du folio {chr:folio(@n)}" loading="lazy"/>
      </details>
      <figcaption>Archives départementales du Loiret, 3E 10144, fol. <xsl:value-of select="chr:folio(@n)"/></figcaption>
    </figure>
  </xsl:template>

  <!-- Nom lié à l'index : lien vers l'entrée, dans la page de l'index.
       L'infobulle est la vedette de l'index (@n), comme l'ÉLEC. -->
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//(tei:persName | tei:placeName | tei:orgName)[@ref]">
    <a class="linkToIndex" href="?refId={$index-ref}{@ref}" title="{normalize-space(if (@n) then @n else .)}">
      <xsl:if test="@xml:id"><xsl:attribute name="id" select="@xml:id"/></xsl:if>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- Appel de note d'apparat : la note s'affiche à côté au survol (ou au
       focus), comme displayApparatusNote() de l'ÉLEC, mais en CSS. -->
  <xsl:template match="tei:ref[@type = 'note']">
    <xsl:variable name="note" select="key('note-par-id', substring-after(@target, '#'))[1]"/>
    <span class="noteAnchor" tabindex="0" id="{@xml:id}"><sup><xsl:value-of select="@n"/></sup></span>
    <xsl:if test="$note">
      <span class="apparatusNote"><xsl:value-of select="@n"/>. <xsl:apply-templates select="$note/node()" mode="note-en-ligne"/></span>
    </xsl:if>
  </xsl:template>

  <!-- Le <p> d'une note devient du texte au fil dans la bulle. -->
  <xsl:template match="tei:p" mode="note-en-ligne">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="node()" mode="note-en-ligne">
    <xsl:apply-templates select="."/>
  </xsl:template>

  <!-- Ajout marginal : « Dans la marge gauche : a. » -->
  <xsl:template match="tei:add[starts-with(@place, 'margin')]">
    <span class="add">
      <xsl:if test="@n"><span class="editor-note"><xsl:value-of select="@n"/> : </span><xsl:text> </xsl:text></xsl:if>
      <span class="margin-addition"><xsl:apply-templates/></span>
    </span>
  </xsl:template>

  <!-- ================================================================
       Index des types d'actes — ÉLEC index-des-types-d-actes.html
       « Accord : 9 (8 janvier) ; 26 (16 janvier) ; … »
       ================================================================ -->
  <xsl:template match="tei:div[@type = 'index-types-actes']">
    <section id="content" class="actTypes">
      <section>
        <h1><xsl:value-of select="normalize-space(tei:head)"/></h1>
        <xsl:for-each select="tei:list[@type = 'act-types']/tei:item">
          <article>
            <span class="index-entry"><span class="actType-entry"><xsl:value-of select="chr:capitale(tei:label)"/></span></span>
            <span class="index-refs">
              <xsl:text> : </xsl:text>
              <xsl:for-each select="tei:list/tei:item">
                <xsl:if test="position() > 1"> ; </xsl:if>
                <a title="Consulter la note" class="internalLink" href="?refId={substring-after(tei:ref/@target, '#')}"><xsl:value-of select="tei:ref"/></a>
                <xsl:text> (</xsl:text>
                <xsl:call-template name="date-ordinal"><xsl:with-param name="texte" select="normalize-space(tei:date)"/></xsl:call-template>
                <xsl:text>)</xsl:text>
              </xsl:for-each>
            </span>
          </article>
        </xsl:for-each>
      </section>
    </section>
  </xsl:template>

  <!-- ================================================================
       Index des lieux et des personnes — ÉLEC index-lieux-et-personnes/lettre-X.html
       Toutes les lettres sur une page ; barre des lettres en tête.
       ================================================================ -->
  <xsl:template match="tei:div[@type = 'indexes']">
    <section id="content" class="index">
      <nav id="specific-menu-index">
        <ul id="letters-list">
          <xsl:for-each select="tei:div[@type = 'lettre']">
            <li><a href="#{@xml:id}"><xsl:value-of select="normalize-space(tei:head)"/></a></li>
          </xsl:for-each>
        </ul>
      </nav>
      <section>
        <h1>Index des lieux et des personnes</h1>
        <xsl:apply-templates select="tei:p"/>
        <xsl:for-each select="tei:div[@type = 'lettre']">
          <h2 class="lettre" id="{@xml:id}"><xsl:value-of select="normalize-space(tei:head)"/></h2>
          <xsl:apply-templates select=".//(tei:person | tei:org | tei:place[not(parent::tei:place)])" mode="index"/>
        </xsl:for-each>
      </section>
    </section>
  </xsl:template>

  <!-- Le <bibl> de l'introduction de l'index : « Jacques Soyer, Les noms… (1979) ». -->
  <xsl:template match="tei:div[@type = 'indexes']/tei:p//tei:bibl/tei:title">
    <cite><xsl:apply-templates/></cite>
  </xsl:template>

  <xsl:template match="tei:person | tei:org" mode="index">
    <article id="{@xml:id}">
      <p>
        <span class="persName-Entry">
          <xsl:apply-templates select="(tei:persName | tei:orgName)[1]" mode="vedette"/>
        </span>
        <xsl:for-each select="tei:occupation | tei:note[@type = 'relation']">
          <xsl:text>, </xsl:text><xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
        <xsl:apply-templates select="tei:note[not(@type)]" mode="voir"/>
        <xsl:call-template name="renvois"/>
      </p>
    </article>
  </xsl:template>

  <xsl:template match="tei:place" mode="index">
    <article id="{@xml:id}">
      <p>
        <span class="placeName-entry"><xsl:apply-templates select="tei:placeName[1]" mode="lieu"/></span>
        <xsl:apply-templates select="tei:location" mode="lieu"/>
        <xsl:apply-templates select="tei:note[not(@type)]" mode="voir"/>
        <xsl:call-template name="renvois"/>
      </p>
      <xsl:if test="tei:place">
        <ul>
          <xsl:for-each select="tei:place">
            <li>
              <span class="index-2th-entry" id="{@xml:id}">
                <span class="placeName-entry"><xsl:apply-templates select="tei:placeName[1]" mode="lieu"/></span>
              </span>
              <xsl:apply-templates select="tei:location" mode="lieu"/>
              <xsl:apply-templates select="tei:note[not(@type)]" mode="voir"/>
              <xsl:call-template name="renvois"/>
            </li>
          </xsl:for-each>
        </ul>
      </xsl:if>
    </article>
  </xsl:template>

  <!-- Vedette de personne : « Taboureux, Jean le », « Aignan, saint », « Bomes ». -->
  <xsl:template match="tei:persName" mode="vedette">
    <xsl:choose>
      <xsl:when test="tei:surname">
        <span class="surname"><xsl:value-of select="normalize-space(tei:surname)"/></span>
        <xsl:if test="tei:forename">, <span class="forename"><xsl:value-of select="normalize-space(tei:forename)"/></span></xsl:if>
        <xsl:if test="tei:nameLink"><span class="nameLink"><xsl:value-of select="concat(' ', normalize-space(tei:nameLink))"/></span></xsl:if>
      </xsl:when>
      <xsl:when test="tei:name"><xsl:value-of select="normalize-space(tei:name)"/></xsl:when>
      <xsl:otherwise><span class="forename"><xsl:value-of select="normalize-space(tei:forename)"/></span></xsl:otherwise>
    </xsl:choose>
    <xsl:for-each select="tei:genName | tei:roleName">, <xsl:value-of select="normalize-space(.)"/></xsl:for-each>
    <xsl:if test="tei:addName">, dit <xsl:value-of select="normalize-space(tei:addName)"/></xsl:if>
  </xsl:template>

  <xsl:template match="tei:orgName" mode="vedette">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>

  <!-- Vedette de lieu : « Talemelerie (rue de la) », le terme en <span class="term">. -->
  <xsl:template match="tei:placeName" mode="lieu">
    <xsl:for-each select="node()">
      <xsl:choose>
        <xsl:when test="self::tei:term"><span class="term"><xsl:value-of select="normalize-space(.)"/></span>
          <xsl:if test="following-sibling::node()[1][self::text()][not(starts-with(normalize-space(.), ')'))][normalize-space()]"><xsl:text> </xsl:text></xsl:if>
        </xsl:when>
        <xsl:when test="self::tei:addName">, dit <xsl:value-of select="normalize-space(.)"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="replace(., '\s+', ' ')"/></xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Localisation : « Loiret, Briare » ; une commune seule : « , Orléans ». -->
  <xsl:template match="tei:location" mode="lieu">
    <xsl:choose>
      <xsl:when test="tei:district">
        <span class="location-full">
          <xsl:for-each select="tei:district">
            <xsl:if test="position() > 1">, </xsl:if>
            <span class="{@type}"><xsl:value-of select="normalize-space(.)"/></span>
          </xsl:for-each>
        </span>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>, </xsl:text>
        <span class="location"><xsl:value-of select="normalize-space(string-join(*, ', '))"/></span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- « voir Notre-Dame » : renvoi vers une autre entrée de l'index (même page). -->
  <xsl:template match="tei:note" mode="voir">
    <xsl:text> : </xsl:text>
    <xsl:for-each select="node()">
      <xsl:choose>
        <xsl:when test="self::tei:ref[starts-with(@target, '#')]">
          <a class="internalLink" href="?refId={$index-ref}{@target}"><xsl:value-of select="normalize-space(.)"/></a>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="replace(., '\s+', ' ')"/></xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Renvois aux notes, lus dans @corresp : « : 9, 14, 47 ». -->
  <xsl:template name="renvois">
    <xsl:variable name="id" select="@xml:id"/>
    <xsl:variable name="notes" select="tokenize(normalize-space(@corresp), ' ')[starts-with(., '#minute-')]"/>
    <xsl:if test="exists($notes)">
      <span class="index-refs">
        <xsl:text> : </xsl:text>
        <xsl:for-each select="$notes">
          <xsl:if test="position() > 1">, </xsl:if>
          <a class="internalLink" title="Consulter la note" href="?refId={substring(., 2)}#{$id}">
            <xsl:value-of select="number(substring-after(., '#minute-'))"/>
          </a>
        </xsl:for-each>
      </span>
    </xsl:if>
  </xsl:template>

</xsl:transform>
