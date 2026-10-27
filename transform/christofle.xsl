<?xml version="1.0" encoding="UTF-8"?>
<!-- Christofle : surcharge de hteiml, reconstruite le 13/10/2026 en partant du rendu
     hteiml nu.

     Principe : chaque page reprend le DOM de l'ÉLEC (mêmes id et mêmes classes que
     elec.enc.sorbonne.fr/christofle), de sorte que la CSS historique (theme/christofle.css)
     s'applique presque telle quelle. Aucun JavaScript dans le HTML : la note d'apparat
     s'affiche au survol en CSS ; les tableaux filtrables ne portent que des marqueurs
     tf-* (module tableau-filtrable.xsl, préfixe chr-) dont le comportement vit dans
     christofle.customJs.js (collectionCustomJs).

     Pages : accueil, introduction, édition des notes (sommaire des mois), mois, note
     (minute), index des types d'actes, index des lieux et personnes. -->
<xsl:transform version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:chr="urn:christofle"
  exclude-result-prefixes="tei xs chr">

  <!-- ==== 0. DÉCLARATIONS : imports, sortie, paramètres, variables, clés, fonctions ==== -->

  <xsl:import href="../../renderers/hteiml/xsl/tei2html.xsl"/>

  <!-- Tableaux triables et filtrables : module commun, copie à côté de cette feuille. -->
  <xsl:import href="tableau-filtrable.xsl"/>

  <!-- 2026-10-14 : index des types d'actes en liste repliable (module commun, classes lr-*). -->
  <xsl:import href="liste-repliable.xsl"/>

  <xsl:variable name="tf-prefixe" select="'chr'"/>

  <!-- Pas d'indentation : dots-vue compile la sortie en gabarit Vue, qui retire les blancs
       contenant un saut de ligne entre deux balises (« Adam de » devenait « Adamde »). -->
  <xsl:output indent="no"/>

  <!-- Unité qui porte tout l'index des lieux et personnes (servie entière). -->
  <xsl:variable name="index-ref" select="'r65205'"/>

  <xsl:variable name="mois" select="('janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
                                     'août', 'septembre', 'octobre', 'novembre', 'décembre')"/>

  <xsl:key name="note-par-id" match="tei:note[@xml:id]" use="@xml:id"/>

  <!-- Première lettre en capitale (« quittance » → « Quittance »). -->
  <xsl:function name="chr:capitale" as="xs:string">
    <xsl:param name="s"/>
    <xsl:variable name="t" select="normalize-space($s)"/>
    <xsl:sequence select="concat(upper-case(substring($t, 1, 1)), substring($t, 2))"/>
  </xsl:function>

  <!-- Folio : @n « 76 » ou « 82v » → « 76 r° », « 82 v° ». -->
  <xsl:function name="chr:folio" as="xs:string">
    <xsl:param name="n"/>
    <xsl:variable name="n" select="normalize-space($n)"/>
    <xsl:variable name="fin" select="substring($n, string-length($n))"/>
    <xsl:sequence select="if ($fin = ('r', 'v'))
                          then concat(substring($n, 1, string-length($n) - 1), ' ', $fin, '°')
                          else concat($n, ' r°')"/>
  </xsl:function>

  <!-- Vedette en texte simple (tri, suggestions) ; sous-entrée : « Lieu › sous-entrée ». -->
  <xsl:function name="chr:vedette" as="xs:string" version="3.0">
    <xsl:param name="e" as="element()"/>
    <xsl:variable name="v"><xsl:apply-templates select="$e" mode="christofle-vedette"/></xsl:variable>
    <xsl:sequence select="normalize-space(if ($e/parent::tei:place) then concat(chr:vedette($e/parent::tei:place), ' › ', $v) else string($v))"/>
  </xsl:function>

  <!-- Forme aplatie des valeurs de filtre et de tri (même règle que tf:plat du module commun). -->
  <xsl:function xmlns:xs="http://www.w3.org/2001/XMLSchema" name="chr:plat" as="xs:string" version="3.0">
    <xsl:param name="s" as="xs:string?"/>
    <xsl:sequence select="normalize-space(lower-case(replace(normalize-unicode(string($s), 'NFD'), '\p{Mn}', '')))"/>
  </xsl:function>

  <!-- ==== 1. HISTORIQUE : surcharge reprise de la feuille de l'ÉLEC (rendu du texte de l'édition) ==== -->

  <!-- « 1er juin » → 1<sup>er</sup> juin, comme l'ÉLEC. -->
  <xsl:template name="date-ordinal">
    <xsl:param name="texte"/>
    <xsl:analyze-string select="$texte" regex="(^|\s)1er(\s|$)">
      <xsl:matching-substring><xsl:value-of select="regex-group(1)"/>1<sup>er</sup><xsl:value-of select="regex-group(2)"/></xsl:matching-substring>
      <xsl:non-matching-substring><xsl:value-of select="."/></xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

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
      <!-- 2026-10-27 : plus de liste des parties ici (intro-menu) : la TOC de dots-vue suffit. -->
      <section>
        <article>
          <h1 class="head"><xsl:value-of select="normalize-space($partie/tei:head)"/></h1>
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
          <h1 class="head"><xsl:value-of select="normalize-space(tei:head)"/></h1>
          <xsl:apply-templates select="node()[not(self::tei:head)]"/>
          <!-- 2026-10-27 : corps des notes de la partie (hteiml ne les sort que pour tei:text) :
               sans lui, l'appel de note pointe vers un id absent. -->
          <xsl:call-template name="footnotes">
            <xsl:with-param name="cont" select="."/>
          </xsl:call-template>
        </article>
      </section>
    </section>
  </xsl:template>

  <!-- 2026-10-19 : « Édition des notes » (r1609) : la liste des mois et des jours de l'ÉLEC est retirée ;
       la page garde le sommaire de DoTS (décision de Maxime). -->
  <xsl:template match="tei:group[tei:argument[@ana = '#notes-index']]">
    <h1 class="head"><xsl:value-of select="(normalize-space(tei:head[1])[. != ''], 'Édition des notes')[1]"/></h1>
  </xsl:template>

  <!-- ================================================================
       Note (minute) — ÉLEC notes/note-NNN.html
       ================================================================ -->
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]">
    <!-- 2026-10-19 : barres de navigation de l'ÉLEC (mois, jours, minutes voisines) retirées : sommaire et flèches de dots-vue -->
    <section id="content" class="mins">
      <section id="facsimile" class="col">
        <xsl:apply-templates select="tei:body//tei:pb[@facs]" mode="facsimile"/>
      </section>
      <section id="text">
        <section id="edition">
          <article id="edition-text">
            <!-- 2026-10-19 : en-tête au modèle de hteiml (comme les actes des autres corpus) : n°, date, analyse -->
            <header class="front">
              <div class="docNum"><xsl:value-of select="tei:front/tei:docTitle/tei:titlePart[@type = 'number']"/></div>
              <span class="docDate">
                <time datetime="{tei:front/tei:docDate/tei:date/@when}">
                  <xsl:call-template name="date-ordinal"><xsl:with-param name="texte" select="normalize-space(tei:front/tei:docDate/tei:date)"/></xsl:call-template>
                </time>
              </span>
              <div class="argument">
                <p>
                  <xsl:if test="tei:front/tei:index/tei:term[@type = 'natureJuridique']">
                    <span class="recordType"><xsl:value-of select="chr:capitale(tei:front/tei:index/tei:term[@type = 'natureJuridique'][1])"/></span>
                    <xsl:text>. — </xsl:text>
                  </xsl:if>
                  <xsl:apply-templates select="tei:front/tei:div[@type = 'summary']/tei:p/node()"/>
                </p>
              </div>
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

  <!-- ================================================================
       Index des types d'actes — ÉLEC index-des-types-d-actes.html
       « Accord : 9 (8 janvier) ; 26 (16 janvier) ; … »
       2026-10-14 : liste repliable (module liste-repliable.xsl) : une ligne par type
       (« Accord … 23 actes »), dépliée sur ses minutes en colonnes (« 9 — 8 janvier »).
       ================================================================ -->
  <xsl:template match="tei:div[@type = 'index-types-actes']">
    <section id="content" class="actTypes">
      <section>
        <h1><xsl:value-of select="normalize-space(tei:head)"/></h1>
        <div class="lr-liste">
          <xsl:for-each select="tei:list[@type = 'act-types']/tei:item">
            <xsl:call-template name="lr-entree">
              <xsl:with-param name="titre"><xsl:value-of select="chr:capitale(tei:label)"/></xsl:with-param>
              <xsl:with-param name="nb" select="count(tei:list/tei:item)"/>
              <xsl:with-param name="unite" select="'acte'"/>
              <xsl:with-param name="contenu">
                <ul class="lr-colonnes">
                  <xsl:for-each select="tei:list/tei:item">
                    <li>
                      <a title="Consulter la minute" class="internalLink" href="?refId={substring-after(tei:ref/@target, '#')}"><xsl:value-of select="tei:ref"/></a>
                      <span class="chr-type-date">
                        <xsl:text> — </xsl:text>
                        <xsl:call-template name="date-ordinal"><xsl:with-param name="texte" select="normalize-space(tei:date)"/></xsl:call-template>
                      </span>
                    </li>
                  </xsl:for-each>
                </ul>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:for-each>
        </div>
      </section>
    </section>
  </xsl:template>

  <!-- ==== 2. BLOCS HTEIML GÉNÉRIQUES : enveloppe dts:wrapper, notes, apparat critique, bibliographie (listBibl) ==== -->

  <!-- ================================================================
       Enveloppe DoTS
       hteiml ne connaît pas <dts:wrapper> et l'affiche en rouge : on le traverse.
       ================================================================ -->
  <xsl:template match="*[local-name() = 'wrapper']">
    <xsl:apply-templates/>
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

  <!-- ==== 3. PROPRE AU PROJET ==== -->

  <xsl:template match="tei:graphic">
    <img src="../../images/christofle/{substring-after(@url, 'images/')}" alt="{normalize-space(../tei:figDesc)}"/>
  </xsl:template>

  <!-- ================================================================
       Page d'un mois : filtre par jour sans JavaScript (boutons radio et CSS), repris
       tel quel de la feuille précédente (christofle-month-index).
       ================================================================ -->
  <xsl:template match="tei:group[tei:argument[@ana = '#month-index']]">
    <xsl:call-template name="christofle-month-index">
      <xsl:with-param name="month" select="tei:argument[@ana = '#month-index']"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Index d'un mois : filtre par jour sans JS.
       $month est ici <argument type="month-index"> et contient une liste
       précalculée de toutes les minutes du mois. -->
  <xsl:template name="christofle-month-index">
    <xsl:param name="month"/>
    <xsl:variable name="mid" select="substring-after($month/@corresp, '#')"/>
    <xsl:variable name="minutes" select="$month/tei:list/tei:item"/>
    <section class="christofle-mois" id="{$mid}">
      <h2 class="mois-head"><xsl:value-of select="normalize-space($month/tei:head)"/></h2>
      <p class="mois-intro"><xsl:value-of select="count($minutes)"/> actes. Filtrez par jour ou cliquez un acte pour le consulter.</p>

      <input type="radio" name="jf-{$mid}" id="jf-{$mid}-all" class="jf-radio" checked="checked"/>

      <nav class="jours-nav" aria-label="Filtrer par jour">
        <span class="jours-label">Jours :</span>
        <label class="jour-link jour-all" for="jf-{$mid}-all">Tous</label>
        <!-- 2026-09-29 : jours dans l'ordre des dates (voir la barre des jours
             des minutes) ; le premier de chaque jour reste choisi dans l'ordre
             du document (preceding-sibling), le tri ne joue que sur l'affichage. -->
        <xsl:for-each select="$minutes">
          <xsl:sort select="tei:date/@when"/>
          <xsl:variable name="when" select="tei:date/@when"/>
          <xsl:if test="not(preceding-sibling::tei:item[tei:date/@when = $when])">
            <label class="jour-link" for="jf-{$mid}-{$when}" title="{normalize-space(tei:date)}">
              <xsl:value-of select="number(substring($when, 9))"/>
            </label>
          </xsl:if>
        </xsl:for-each>
      </nav>

      <div class="jours-index">
        <xsl:for-each select="$minutes">
          <xsl:sort select="tei:date/@when"/>
          <xsl:variable name="when" select="tei:date/@when"/>
          <xsl:if test="not(preceding-sibling::tei:item[tei:date/@when = $when])">
            <section class="jour-group jg-{$when}" id="jour-{$when}">
              <input type="radio" name="jf-{$mid}" id="jf-{$mid}-{$when}" class="jf-radio"/>
              <h3 class="jour-head"><xsl:value-of select="normalize-space(tei:date)"/></h3>
              <xsl:for-each select="$minutes[tei:date/@when = $when]">
                <div class="jour-note">
                  <a class="internalLink note-link" href="?refId={substring-after(tei:ref/@target, '#')}">
                    <span class="note-num"><xsl:value-of select="tei:ref"/>.</span>
                    <xsl:text> </xsl:text>
                    <xsl:variable name="nature" select="normalize-space(tei:term[@type = 'natureJuridique'][1])"/>
                    <xsl:if test="$nature != ''">
                      <span class="note-type"><xsl:value-of select="$nature"/></span>
                      <xsl:text> — </xsl:text>
                    </xsl:if>
                    <span class="note-summary"><xsl:value-of select="normalize-space(tei:seg[@type = 'summary'])"/></span>
                  </a>
                </div>
              </xsl:for-each>
            </section>
          </xsl:if>
        </xsl:for-each>
      </div>
    </section>
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

  <!-- Ajout marginal : « Dans la marge gauche : a. » -->
  <xsl:template match="tei:add[starts-with(@place, 'margin')]">
    <span class="add">
      <xsl:if test="@n"><span class="editor-note"><xsl:value-of select="@n"/> : </span><xsl:text> </xsl:text></xsl:if>
      <span class="margin-addition"><xsl:apply-templates/></span>
    </span>
  </xsl:template>

  <xsl:template match="tei:person" mode="christofle-vedette">
    <xsl:apply-templates select="tei:persName[1]" mode="christofle-index-name">
      <xsl:with-param name="variantes" select="tei:persName[position() &gt; 1]"/>
    </xsl:apply-templates>
    <xsl:if test="tei:note[@type = 'relation']">
      <xsl:text>, </xsl:text>
      <xsl:value-of select="normalize-space(tei:note[@type = 'relation'])"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:place" mode="christofle-vedette">
    <xsl:for-each select="tei:placeName">
      <xsl:if test="position() &gt; 1"><xsl:text> / </xsl:text></xsl:if>
      <xsl:apply-templates select="." mode="christofle-index-inline"/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'indexes']" priority="9" version="3.0">
    <xsl:variable name="fiches" select=".//tei:div[@type = 'lettre']//(tei:person | tei:place | tei:org)"/>
    <section class="christofle-index christofle-index-unified">
      <xsl:apply-templates select="tei:head" mode="christofle-index"/>
      <div class="christofle-index-intro">
        <xsl:for-each select="tei:p | tei:div[@type = 'places-index']/tei:p">
          <p><xsl:apply-templates/></p>
        </xsl:for-each>
      </div>
      <xsl:call-template name="chr-tableau-index">
        <xsl:with-param name="fiches" select="$fiches"/>
        <xsl:with-param name="csv-nom" select="'christofle-index-lieux-personnes'"/>
      </xsl:call-template>
    </section>
  </xsl:template>

  <!-- Cellule « Nom » : la vedette telle que dans les fiches des pages par lettre. -->
  <xsl:template name="chr-cellule-nom" version="3.0">
    <span class="index-vedette">
      <xsl:if test="parent::tei:place">
        <span class="chr-parent"><xsl:apply-templates select="parent::tei:place" mode="christofle-vedette"/></span>
        <span class="chr-chevron"> › </span>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="self::tei:person">
          <span class="persName-entry">
            <xsl:apply-templates select="tei:persName[1]" mode="christofle-index-name">
              <xsl:with-param name="variantes" select="tei:persName[position() &gt; 1]"/>
            </xsl:apply-templates>
            <xsl:if test="tei:note[@type = 'relation']">
              <xsl:text>, </xsl:text>
              <span class="persName-note"><xsl:value-of select="normalize-space(tei:note[@type = 'relation'])"/></span>
            </xsl:if>
          </span>
        </xsl:when>
        <xsl:when test="self::tei:org">
          <span class="orgName-entry"><xsl:value-of select="normalize-space(tei:orgName[1])"/></span>
        </xsl:when>
        <xsl:otherwise>
          <span class="placeName-entry">
            <xsl:for-each select="tei:placeName">
              <xsl:if test="position() &gt; 1"><xsl:text> / </xsl:text></xsl:if>
              <xsl:apply-templates select="." mode="christofle-index-inline"/>
            </xsl:for-each>
          </span>
          <xsl:if test="tei:location">
            <xsl:text> </xsl:text><!-- insécable : une espace seule entre deux balises est supprimée par Vue -->
            <span class="location chr-location"><xsl:apply-templates select="tei:location/*" mode="christofle-index-loc"/></span>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
    </span>
    <xsl:apply-templates select="tei:note[not(@type = 'relation')]" mode="christofle-index-seealso"/>
  </xsl:template>

  <!-- Fiche personne -->
  <!-- Nom en vedette : « Surname, Forename nameLink », « Forename, roleName »… -->
  <xsl:template match="tei:persName" mode="christofle-index-name">
    <!-- Les autres <persName> de la même personne : leurs noms de famille viennent s'ajouter
         derrière le premier, séparés par « / », avant le prénom. -->
    <xsl:param name="variantes" select="()"/>
    <xsl:choose>
      <xsl:when test="tei:surname">
        <span class="surname"><xsl:value-of select="normalize-space(tei:surname)"/></span>
        <xsl:for-each select="$variantes/tei:surname[normalize-space()]                               [normalize-space() != normalize-space(current()/tei:surname)]">
          <xsl:text> / </xsl:text>
          <span class="surname surname-variante"><xsl:value-of select="normalize-space(.)"/></span>
        </xsl:for-each>
        <xsl:if test="tei:forename">
          <xsl:text>, </xsl:text>
          <span class="forename"><xsl:value-of select="normalize-space(tei:forename)"/></span>
          <xsl:if test="tei:nameLink"><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tei:nameLink)"/></xsl:if>
        </xsl:if>
        <xsl:if test="tei:roleName"><xsl:text>, </xsl:text><span class="persName-role"><xsl:value-of select="normalize-space(tei:roleName)"/></span></xsl:if>
        <xsl:if test="tei:addName"><xsl:text>, dit </xsl:text><xsl:value-of select="normalize-space(tei:addName)"/></xsl:if>
      </xsl:when>

      <!-- Certaines vedettes de l'index sont encodées uniquement avec <name>
           (ex. p-0287 = Cordeau). L'ancien template tombait dans le cas
           "otherwise" et cherchait un <forename> inexistant : la vedette
           disparaissait alors que son @corresp vers la minute était valide. -->
      <xsl:when test="tei:name">
        <span class="name-entry"><xsl:value-of select="normalize-space(tei:name)"/></span>
      </xsl:when>

      <xsl:otherwise>
        <span class="forename-entry"><xsl:value-of select="normalize-space(tei:forename)"/></span>
        <xsl:if test="tei:roleName"><xsl:text>, </xsl:text><span class="persName-role"><xsl:value-of select="normalize-space(tei:roleName)"/></span></xsl:if>
        <xsl:if test="tei:addName"><xsl:text>, dit </xsl:text><xsl:value-of select="normalize-space(tei:addName)"/></xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Fiche lieu : présentation historique "ADON [ Loiret, Briare ]". -->
  <!-- placeName avec <term> inline : « Bannier (porte) » -->
  <xsl:template match="tei:term" mode="christofle-index-inline">
    <span class="term"><xsl:value-of select="normalize-space(.)"/></span>
    <!-- 2026-10-06 : pas de blanc devant « ) » ni devant un blanc de la source :
         96 vedettes sortaient « Saint-Euverte (abbaye ) ». -->
    <xsl:variable name="suite" select="string(following-sibling::node()[1])"/>
    <xsl:if test="not(starts-with($suite, ')') or starts-with($suite, ' ') or $suite = '')"><xsl:text> </xsl:text></xsl:if>
  </xsl:template>

  <!-- 2026-09-29 : surnom d'un lieu, « La Sauverie, dit La Roigelerie » comme
       l'ÉLEC. Le TEI colle <addName> au nom (« La Sauverie<addName>dit … ») :
       sans ce modèle la vedette sortait « La Sauveriedit La Roigelerie ».
       2 vedettes : l-0398, l-0207 (« Nerront (clos de) , dit le coin Chabot »,
       espace avant la virgule compris, tel que sur l'ÉLEC). -->
  <xsl:template match="tei:addName" mode="christofle-index-inline"><xsl:text>, </xsl:text><span class="addName"><xsl:value-of select="normalize-space(.)"/></span></xsl:template>

  <!-- location : departement, canton, settlement… séparés par des virgules -->
  <xsl:template match="tei:location/*" mode="christofle-index-loc">
    <xsl:if test="position() &gt; 1">, </xsl:if>
    <span>
      <xsl:attribute name="class">
        <xsl:value-of select="local-name()"/>
        <xsl:if test="@type">
          <xsl:text> </xsl:text>
          <xsl:value-of select="@type"/>
        </xsl:if>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(.)"/>
    </span>
  </xsl:template>

  <!-- « voir … » : renvoi vers une autre entrée d'index -->
  <xsl:template match="tei:note" mode="christofle-index-seealso">
    <span class="index-seealso"><xsl:text> (</xsl:text>
      <xsl:for-each select="node()">
        <xsl:choose>
          <!-- Les ancres nues (#p-…/#l-…) sont interceptées par le routeur SPA.
               On repasse donc par la page parent de l'index, qui conserve l'ancre. -->
          <xsl:when test="self::tei:ref and starts-with(normalize-space(@target), '#')">
            <!-- D34 : idem pour les 157 renvois « voir » internes à l'index
                 (156 vers une entrée, 1 vers une sous-entrée).
                 CORRECTIF p-1043 : même cible que les renvois des minutes,
                 « page de la lettre + ancre » ; sinon ces 157 liens mènent eux
                 aussi à une page vide. -->
            <a class="linkToIndex">
              <xsl:attribute name="href">
                <xsl:call-template name="christofle-index-href">
                  <xsl:with-param name="cible" select="substring-after(normalize-space(@target), '#')"/>
                  <xsl:with-param name="lettre" select="substring-after(@corresp, '#')"/>
                </xsl:call-template>
              </xsl:attribute>
              <xsl:value-of select="normalize-space(.)"/>
            </a>
          </xsl:when>
          <!-- Deux renvois de la source n'ont volontairement/pas encore de @target :
               on garde leur libellé mais on ne fabrique plus de href="#". -->
          <xsl:when test="self::tei:ref">
            <xsl:value-of select="normalize-space(.)"/>
          </xsl:when>
          <!-- 2026-10-06 : un blanc seulement entre deux mots ; le texte vide qui suit
               le dernier renvoi donnait « (voir Notre-Dame ) ». -->
          <xsl:when test="normalize-space(.) = ''"/>
          <xsl:otherwise><xsl:value-of select="normalize-space(.)"/><xsl:if test="following-sibling::node()[normalize-space()]"><xsl:text> </xsl:text></xsl:if></xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
      <xsl:text>)</xsl:text>
    </span>
  </xsl:template>

  <!-- Renvois aux minutes, déduits de @corresp="#minute-120 #minute-121" -->
  <xsl:template name="christofle-refs-loop">
    <xsl:param name="refs"/>
    <xsl:param name="first" select="true()"/>
    <xsl:variable name="head" select="substring-before(concat($refs, ' '), ' ')"/>
    <xsl:variable name="tail" select="normalize-space(substring-after($refs, ' '))"/>
    <xsl:variable name="mid" select="substring-after($head, '#minute-')"/>
    <xsl:if test="$mid != ''">
      <xsl:if test="not($first)"><span class="chr-sep"> · </span></xsl:if>
      <a class="internalLink" title="Consulter la minute" href="?refId=minute-{$mid}">
        <xsl:value-of select="number($mid)"/>
      </a>
    </xsl:if>
    <xsl:if test="$tail != ''">
      <xsl:call-template name="christofle-refs-loop">
        <xsl:with-param name="refs" select="$tail"/>
        <xsl:with-param name="first" select="false()"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- ==== 4. MÉCANISMES COMMUNS : tableau filtrable (tf-*), liens vers l'ancien site (D5), liens internes entre fragments ==== -->

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

  <!-- Nom lié à l'index : lien vers l'entrée, dans la page de l'index.
       L'infobulle est la vedette de l'index (@n), comme l'ÉLEC. -->
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//(tei:persName | tei:placeName | tei:orgName)[@ref]">
    <a class="linkToIndex" href="?refId={$index-ref}{@ref}" title="{normalize-space(if (@n) then @n else .)}">
      <xsl:if test="@xml:id"><xsl:attribute name="id" select="@xml:id"/></xsl:if>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- ================================================================
       Index des lieux et des personnes : tableau filtrable et triable (Nom, Type,
       Minutes). Barre, en-têtes, filtres et cellules vides : modèles tf-barre, tf-th,
       tf-filtre du module tableau-filtrable.xsl. Le comportement (tri, filtres, « Effacer »,
       CSV) est dans christofle.customJs.js.
       ================================================================ -->
  <!-- href d'un renvoi vers une entrée d'index : identifiant de la cible, et
       division-lettre qui la contient, lue dans le @corresp du renvoi. -->
  <xsl:template name="christofle-index-href">
    <xsl:param name="cible"/>
    <xsl:param name="lettre"/>
    <xsl:text>?refId=</xsl:text>
    <xsl:choose>
      <!-- Entrée connue : page de la lettre + ancre, comme l'ÉLEC. -->
      <!-- 2026-10-08 : les pages par lettre ne sont plus des unités (lettres retirées du registre :
           l'index tient sur la seule page r65205, servie entière). L'entrée est visée dans cette page. -->
      <xsl:when test="$lettre">
        <xsl:text>r65205#</xsl:text>
        <xsl:value-of select="$cible"/>
      </xsl:when>
      <!-- Renvoi sans @corresp, c'est-à-dire dont la cible n'est dans aucune
           division-lettre (1 cas dans la source : un « voir » d'apparat qui
           pointe une minute) : on garde l'ancien comportement plutôt que de
           fabriquer un lien faux. -->
      <xsl:otherwise><xsl:value-of select="$cible"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 2026-10-07 : le tableau de l'index, sorti du gabarit « indexes » pour servir aussi
       aux pages par lettre (idx-lettre-A…), à la demande de l'utilisateur. -->
  <xsl:template name="chr-tableau-index" version="3.0">
    <xsl:param name="fiches"/>
    <xsl:param name="csv-nom" select="'christofle-index'"/>
      <xsl:if test="$fiches">
        <xsl:variable name="vedettes" as="xs:string*">
          <xsl:for-each select="$fiches">
            <xsl:sequence select="chr:vedette(.)"/>
          </xsl:for-each>
        </xsl:variable>
        <div class="tf-cadre chr-tableau-cadre">
          <xsl:call-template name="tf-barre">
            <xsl:with-param name="total" select="count($fiches)"/>
            <xsl:with-param name="unite" select="'entrées'"/>
          </xsl:call-template>
          <table class="chr-tableau chr-index" data-csv-nom="{$csv-nom}" data-csv-entetes="Nom|Type|Minutes">
            <caption class="chr-tableau-legende">
              <xsl:text>Cliquer sur un en-tête de colonne pour trier (un second clic inverse l’ordre ; la colonne Minutes se trie par nombre de minutes). </xsl:text>
              <span class="chr-aide-minutes">Filtre Minute : un numéro (12), ou un intervalle (12–40, ou « de 12 à 40 ») ; une ligne est retenue si l’une de ses minutes tombe dans l’intervalle.</span>
            </caption>
            <thead>
              <tr>
                <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'chr-c-nom'"/><xsl:with-param name="libelle" select="'Nom'"/></xsl:call-template>
                <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'chr-c-type'"/><xsl:with-param name="libelle" select="'Type'"/></xsl:call-template>
                <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'chr-c-minutes'"/><xsl:with-param name="libelle" select="'Minutes'"/><xsl:with-param name="numerique" select="true()"/></xsl:call-template>
              </tr>
              <tr class="tf-filtres chr-filtres">
                <xsl:call-template name="tf-filtre">
                  <xsl:with-param name="col" select="0"/>
                  <xsl:with-param name="libelle" select="'Nom'"/>
                  <xsl:with-param name="suggestions" select="distinct-values($vedettes)"/>
                  <xsl:with-param name="liste" select="concat('chr-noms-', $csv-nom)"/>
                </xsl:call-template>
                <xsl:call-template name="tf-filtre">
                  <xsl:with-param name="col" select="1"/>
                  <xsl:with-param name="libelle" select="'Type'"/>
                  <xsl:with-param name="type" select="'liste'"/>
                  <xsl:with-param name="options" select="('Personne', 'Lieu', 'Organisme')"/>
                </xsl:call-template>
                <!-- Surcharge locale : le modèle tf-filtre n'a pas de title ; le champ garde l'info-bulle
                     de l'index (data-k="num" = type numeros du module). -->
                <td>
                  <input type="search" data-col="2" data-k="num" placeholder="n° ou 12–40" aria-label="Minute : un numéro, ou un intervalle de … à …" title="Un numéro (12), ou un intervalle (12–40 ou « de 12 à 40 »)"/>
                </td>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="$fiches">
                <xsl:variable name="i" select="position()"/>
                <xsl:variable name="type" select="if (self::tei:person) then 'Personne' else if (self::tei:org) then 'Organisme' else 'Lieu'"/>
                <xsl:variable name="nums" select="for $r in tokenize(normalize-space(@corresp), ' ')[starts-with(., '#minute-')] return string(number(substring-after($r, '#minute-')))"/>
                <xsl:variable name="cellule-nom">
                  <xsl:call-template name="chr-cellule-nom"/>
                </xsl:variable>
                <tr id="{@xml:id}" class="chr-ligne chr-{lower-case($type)}{if (parent::tei:place) then ' chr-sous-entree' else ''}" data-o="{$i}">
                  <td class="chr-c-nom" data-sort="{$vedettes[$i]}" data-f="{chr:plat(string($cellule-nom))}" data-csv="{normalize-space(string($cellule-nom))}">
                    <xsl:copy-of select="$cellule-nom"/>
                  </td>
                  <td class="chr-c-type" data-sort="{$type}" data-f="{chr:plat($type)}">
                    <xsl:value-of select="$type"/>
                  </td>
                  <td class="chr-c-minutes" data-sort="{if (exists($nums[. castable as xs:integer])) then min($nums[. castable as xs:integer] ! xs:integer(.)) else ''}" data-f="{string-join($nums, ' ')}" data-csv="{string-join($nums, ', ')}">
                    <xsl:choose>
                      <xsl:when test="exists($nums)">
                        <xsl:call-template name="christofle-refs-loop">
                          <xsl:with-param name="refs" select="normalize-space(@corresp)"/>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise><span class="tf-vide chr-vide">—</span></xsl:otherwise>
                    </xsl:choose>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </xsl:if>
  </xsl:template>

</xsl:transform>
