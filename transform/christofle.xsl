<?xml version='1.0' encoding='UTF-8'?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:chr="urn:christofle:fonctions" version="1.1" exclude-result-prefixes="tei xs chr">

  <xsl:import href="../../renderers/hteiml/xsl/tei2html.xsl"/>
  <xsl:include href="garde.xsl"/><!-- 2026-10-08 : page de garde commune à tous les projets -->
  <xsl:include href="ordinaux.xsl"/> <!-- chantier ordinaux 2026-10-08 -->

  <!-- 2026-10-04 (C7) : chemins selon le serveur. Dans le dépôt, l'application est
       servie sous /elec/ et l'API sous /dots/api/dts/ (dev.chartes.psl.eu) ; la copie
       locale de dots-clean garde '' et l'API locale. Seules ces deux valeurs et
       l'import de hteiml diffèrent entre les deux versions. -->
  <xsl:variable name="elec-base" select="'/elec'"/>
  <xsl:variable name="dts-api-base" select="'/dots/api/dts/'"/>

  <!--
    Rendu racine DTS :
    la requête /document sans @ref doit laisser la feuille générique rendre
    l'ensemble du document, et non réduire le résultat au seul teiHeader.
    Les fragments (accueil, introduction, mois, minutes, index) restent
    consultables séparément via leurs ref DTS.
  -->

  <!--
    Surcharge Christofle — liage des notes d'apparat.

    Convention de l'edition : l'appel et la note sont DEUX elements distincts,
    relies par @target :
       appel : <ref type="note" xml:id="minute-098-a-01" target="#minute-098-n-01"/>
       note  : <note n="1" xml:id="minute-098-n-01" target="#minute-098-a-01">…</note>

    La generique (template "noteref" de tei2html.xsl) est ecrite pour la
    convention "note inline" (un seul <note> partageant un id) : elle emet
       <a href="#{xml:id de l'appel}" id="{xml:id de l'appel}_">
    donc elle IGNORE @target et suffixe l'ancre d'un "_".  Resultat : le lien
    aller pointe vers l'id de l'appel (au lieu de la note) et l'ancre de retour
    porte un "_" que le href de retour de la note (=@target, sans "_") ne trouve
    jamais. Les deux liens sont casses pour les 384 notes.

    Correctif : pour un <ref type="note">, faire pointer le href sur la cible
    (@target) et donner a l'ancre l'id nu (= @xml:id, sans "_"). Le corps de la
    note (aside id=@xml:id, retour href=@target) est deja correct dans la
    generique : cette seule surcharge referme les deux sens.
  -->
  <!-- D14e2 (2026-09-12) : bulle d'apparat au survol, sans JavaScript.
       L'ancien site portait la note d'apparat en frere du sudit appel
         <span class="noteAnchor" onmouseover="displayApparatusNote(this)"><sup>1</sup></span>
         <span class="apparatusNote">1. La lettre J est decoree d'entrelacs.</span>
       et displayApparatusNote/hideApparatusNote (utils.js, 84 pages relevees)
       ne faisaient qu'afficher/masquer ce frere au survol : le lecteur lisait la
       note SANS quitter sa ligne. DoTS-vue compile le fragment comme un gabarit
       Vue : aucun <script> ne s'execute. On reprend donc le motif retenu pour
       bellelay (transform/bellelay.xsl) : le texte de la note est recopie dans
       @data-tip et la CSS l'affiche en bulle sur :hover / :focus-visible.
       Le lien vers la note en pied (liage @target de la tache precedente) est
       conserve tel quel : la bulle s'ajoute, elle ne remplace rien. -->
  <xsl:key name="chr-note-by-id" match="tei:note[@xml:id]" use="@xml:id"/>

  <!-- 2026-09-29 : appel d'apparat À L'INTÉRIEUR d'un nom lié à l'index
       (« Jehan<sup>1</sup> Mignon », 24 appels dans 21 minutes). Un <a> dans le
       <a class="linkToIndex"> est interdit en HTML : le navigateur fermait le
       lien d'index avant l'appel, et « Mignon » sortait du lien. Comme l'ÉLEC
       (<span class="noteAnchor">), l'appel y devient un <span> : même classe,
       même id (cible du retour de la note), même bulle @data-tip ; tabindex
       pour garder la bulle au clavier. Seul le saut vers la note en pied est
       perdu, le clic allant au lien d'index. -->
  <xsl:template match="tei:ref[@type='note']">
    <xsl:variable name="corps" select="key('chr-note-by-id', substring-after(@target, '#'))[1]"/>
    <xsl:variable name="dans-lien" select="ancestor::tei:text[starts-with(@xml:id, 'minute-')]               and (ancestor::tei:persName[starts-with(@ref, '#p-')]                    or ancestor::tei:placeName[starts-with(@ref, '#l-')]                    or ancestor::tei:orgName[starts-with(@ref, '#o-')])"/>
    <xsl:variable name="balise">
      <xsl:choose>
        <xsl:when test="$dans-lien">span</xsl:when>
        <xsl:otherwise>a</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:element name="{$balise}">
      <xsl:attribute name="class">noteref</xsl:attribute>
      <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="$dans-lien"><xsl:attribute name="tabindex">0</xsl:attribute></xsl:when>
        <xsl:otherwise><xsl:attribute name="href">#<xsl:value-of select="substring-after(@target, '#')"/></xsl:attribute></xsl:otherwise>
      </xsl:choose>
      <xsl:if test="$corps">
        <!-- « 1. La lettre J est decoree d'entrelacs. » : le numero precedait le
             texte dans le <span class="apparatusNote"> de l'ancien site. -->
        <xsl:attribute name="data-tip">
          <xsl:value-of select="normalize-space(concat(@n, '. ', normalize-space($corps)))"/>
        </xsl:attribute>
      </xsl:if>
      <sup><xsl:call-template name="note-n"/></sup>
    </xsl:element>
  </xsl:template>

  <!--
    Notes SANS xml:id (gloses d'index type="relation", renvois d'index, note
    liminaire du poeme…). La generique les traite comme des appels de note et
    emet <a class="noteref" href="#noteN"> vers une cible inexistante : 223
    faux appels orphelins. Ces notes ne sont pas des notes de bas de page mais
    du texte au fil (une relation « ep. de … », un renvoi « voir … ») : on les
    rend inline. Les 384 vraies notes d'apparat ont un xml:id et ne sont pas
    concernees ; les notes marginales gardent le rendu generique.
  -->
  <!-- 2026-10-05 : une note de fin sans @target et sans aucun appel qui la vise (seul cas :
       minute-098, dont l'appel ajouté à la migration a été retiré le 04/10) n'a pas de lien de
       retour : hteiml en fabriquait un vers « #id_ », qui ne mène nulle part. Pour toute autre
       note, le modèle est celui de hteiml (tei2html.xsl, noteback), recopié à l'identique. -->
  <xsl:template name="noteback">
    <xsl:param name="class">noteback</xsl:param>
    <xsl:variable name="id">
      <xsl:call-template name="id"/>
    </xsl:variable>
    <xsl:variable name="xid" select="string(@xml:id)"/>
    <xsl:choose>
      <xsl:when test="$class = 'noteback' and self::tei:note and not(@target) and ancestor::tei:back and not(//*[@target = concat('#', $xid)])">
        <span class="{$class}">
          <xsl:call-template name="note-n"/>
          <xsl:text>. </xsl:text>
        </span>
      </xsl:when>
      <xsl:otherwise>
        <a class="{$class}">
          <xsl:attribute name="href">
            <xsl:choose>
              <xsl:when test="@target">
                <xsl:value-of select="substring-before(concat(@target, ' '), ' ')"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>#</xsl:text>
                <xsl:value-of select="$id"/>
                <xsl:text>_</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:call-template name="note-n"/>
          <xsl:if test="$class = 'noteback'">
            <xsl:text>. </xsl:text>
          </xsl:if>
        </a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:note[not(@xml:id) and not(@target) and not(@place = 'margin')]" priority="6">
    <xsl:choose>
      <xsl:when test="tei:p or tei:div">
        <div class="note note-inline {@type}"><xsl:apply-templates/></div>
      </xsl:when>
      <xsl:otherwise>
        <span class="note note-inline {@type}"><xsl:apply-templates/></span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    La consultation historique rendait chaque minute comme une fiche : numero,
    date, nature juridique et résumé précédaient directement la transcription.
    La source TEI porte déjà cette structure dans front/body ; on la restitue
    ici sans changer le composant Vue qui affiche le fragment transformé.
  -->
  <!-- Index précalculés dans data/christofle.xml par scripts/build_indexes.py.
       Ils restent disponibles dans les fragments DoTS, sans composant Vue spécifique. -->
  <!-- D34 : plus aucun lien ne s'en sert (les deux modèles qui l'employaient
       visent désormais l'entrée). Conservée : elle documente l'identifiant de la
       page d'index, et un retour en arrière tient en deux remplacements. -->
  <!-- Index des types d'actes : vrai fragment TEI/DTS.
       2026-10-06 : une ligne REPLIABLE par type (<details> natif, sans script), sur le
       modèle de la page Références des Chroniques latines : replié, le type et son
       nombre d'actes ; déplié, les actes groupés par mois (d'après date/@when, pas le
       texte : « fevrier » s'y trouve une fois), chaque numéro menant à sa minute, suivi
       du jour. L'ÉLEC alignait tout sur une ligne par type (« Accord : 9 (8 janvier) ; … »). -->
  <xsl:template match="tei:div[@type = 'index-types-actes']" priority="12" version="3.0">
    <xsl:variable name="mois" select="('janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',                                        'août', 'septembre', 'octobre', 'novembre', 'décembre')"/>
    <section class="chr-types" id="{@xml:id}">
      <h1><xsl:value-of select="normalize-space(tei:head)"/></h1>
      <p class="chr-types-intro">L’index renvoie au numéro de la transaction.</p>

      <xsl:for-each select="tei:list[@type='act-types']/tei:item">
        <xsl:sort select="tei:label"/>
        <xsl:variable name="actes" select="tei:list/tei:item"/>
        <details class="chr-type">
          <summary>
            <span class="chr-type-head">
              <!-- L'ÉLEC affiche « Accord », « Contrat d'apprentissage » : seule la
                   première lettre est capitalisée (text-transform:capitalize donnerait
                   « Contrat D'apprentissage »). -->
              <xsl:variable name="label" select="normalize-space(tei:label)"/>
              <xsl:value-of select="concat(upper-case(substring($label, 1, 1)), substring($label, 2))"/>
            </span>
            <span class="chr-type-nb">
              <xsl:value-of select="count($actes)"/>
              <xsl:value-of select="if (count($actes) = 1) then ' acte' else ' actes'"/>
            </span>
          </summary>
          <dl class="chr-mois">
            <xsl:for-each-group select="$actes" group-by="substring(tei:date/@when, 6, 2)">
              <xsl:sort select="number(current-grouping-key())" data-type="number"/>
              <dt><xsl:value-of select="concat(upper-case(substring($mois[number(current-grouping-key())], 1, 1)), substring($mois[number(current-grouping-key())], 2))"/></dt>
              <dd>
                <xsl:for-each select="current-group()">
                  <xsl:sort select="number(tei:ref)" data-type="number"/>
                  <xsl:if test="position() != 1"><span class="chr-sep"> · </span></xsl:if>
                  <a title="Consulter la note" class="internalLink" href="{$elec-base}/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
                    <xsl:value-of select="tei:ref"/>
                  </a>
                  <xsl:variable name="jour" select="substring-before(concat(normalize-space(tei:date), ' '), ' ')"/>
                  <xsl:if test="$jour != ''">
                    <span class="chr-acte-date"><xsl:value-of select="concat(' (', $jour, ')')"/></span>
                  </xsl:if>
                </xsl:for-each>
              </dd>
            </xsl:for-each-group>
          </dl>
        </details>
      </xsl:for-each>
    </section>
  </xsl:template>

  <!-- Les mois utilisent l'argument TEI précalculé dans data/christofle.xml. -->
  <xsl:template match="*[local-name() = 'wrapper'][not(tei:teiHeader)]" priority="12">
    <xsl:choose>
      <xsl:when test="tei:argument[@ana = '#month-index']">
        <xsl:apply-templates select="tei:argument[@ana = '#month-index']"/>
      </xsl:when>
      <xsl:when test="tei:argument[@ana = '#intro-index']">
        <xsl:apply-templates select="tei:argument[@ana = '#intro-index']"/>
      </xsl:when>
      <xsl:when test="tei:argument[@ana = '#notes-index']">
        <xsl:apply-templates select="tei:argument[@ana = '#notes-index']"/>
      </xsl:when>
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Barre de navigation d'une note, reprise de l'ÉLEC (#months-list puis
       #days-list de notes/note-001.html) : les douze mois, puis les jours du
       mois courant. Précalculée par build_indexes.py dans chaque minute, donc
       disponible même quand le fragment est servi seul. Aucun JavaScript. -->
  <!-- 2026-09-29 : troisième barre, celle des notes du jour (#mins-list de
       l'ÉLEC, présente sur ses 387 pages de notes) : « Note 30 << Note 55 |
       Note 56 >> Note 31 » — dernière note du jour précédent, notes du jour,
       première note du jour suivant, dans l'ordre des dates, mois franchis.
       Le fragment d'une minute ne contient pas ses voisines : la liste est
       donc portée, comme les deux autres barres, par l'argument note-nav du
       TEI (<list type="minutes">, ref/@type previous | minute | next). Règle
       vérifiée sur les 387 pages ÉLEC moissonnées : 0 écart. -->
  <xsl:template match="tei:argument[@ana = '#note-nav']" priority="12">
    <nav class="christofle-note-nav" aria-label="Navigation par mois, par jour et par note">
      <xsl:for-each select="tei:list">
        <ul>
          <xsl:attribute name="class">
            <xsl:choose>
              <xsl:when test="@type = 'months'">months-list</xsl:when>
              <xsl:when test="@type = 'minutes'">mins-list</xsl:when>
              <xsl:otherwise>days-list</xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:for-each select="tei:item">
            <!-- 2026-09-29 : jours triés par date (@n = AAAA-MM-JJ), comme l'ÉLEC.
                 L'argument les liste dans l'ordre des minutes : en janvier, le
                 21 (minute-055, copiée après le 31 dans le registre) venait
                 après le 31. La barre des mois n'a pas de @n : clé vide, et
                 xsl:sort étant stable, son ordre reste celui de la source. -->
            <xsl:sort select="tei:ref[@type = 'day']/@n"/>
            <li>
              <xsl:choose>
                <xsl:when test="tei:ref/@ana = 'selected'">
                  <xsl:attribute name="class">selected</xsl:attribute>
                </xsl:when>
                <xsl:when test="tei:ref/@type = 'previous'">
                  <xsl:attribute name="class">mins-prev</xsl:attribute>
                </xsl:when>
                <xsl:when test="tei:ref/@type = 'next'">
                  <xsl:attribute name="class">mins-next</xsl:attribute>
                  <span class="sep"> &gt;&gt; </span>
                </xsl:when>
              </xsl:choose>
              <a class="internalLink" href="{$elec-base}/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
                <xsl:choose>
                  <!-- barre des jours : le quantième suffit, le mois est au-dessus -->
                  <xsl:when test="tei:ref/@type = 'day'">
                    <xsl:value-of select="number(substring(tei:ref/@n, 9))"/>
                  </xsl:when>
                  <xsl:otherwise><xsl:value-of select="normalize-space(tei:ref)"/></xsl:otherwise>
                </xsl:choose>
              </a>
              <xsl:if test="tei:ref/@type = 'previous'">
                <span class="sep"> &lt;&lt; </span>
              </xsl:if>
            </li>
          </xsl:for-each>
        </ul>
      </xsl:for-each>
    </nav>
  </xsl:template>

  <!-- « Édition des notes » : page d'entrée de l'édition proprement dite.

       L'ÉLEC affichait ici un sommaire des douze mois, chacun suivi des jours
       représentés. DoTS publie déjà les douze mois comme unités citables : ils
       figurent dans le sommaire (à gauche et en haut) et chaque page de mois
       porte son propre filtre par jour. Reproduire la liste ici faisait donc
       doublon avec le sommaire ET avec les pages de mois : on ne garde que
       l'en-tête et une phrase d'orientation. La liste reste précalculée dans le
       TEI (<argument type="notes-index">, build_indexes.py) si elle devait être
       réintroduite. -->
  <xsl:template match="tei:argument[@ana = '#notes-index']" priority="12">
    <section class="christofle-notes-index">
      <h1>Édition des notes</h1>
      <p class="notes-intro">Les <xsl:value-of select="sum(tei:list/tei:item/tei:num)"/> notes de l’année 1437 sont réparties par mois. Choisissez un mois dans le sommaire, puis un jour dans la barre de filtres de la page du mois.</p>
    </section>
  </xsl:template>

  <!-- Introduction : sommaire de ses parties. Comme pour les mois, l'index est
       précalculé dans le TEI (build_indexes.py) et porté par un <argument>,
       enfant direct du <div> : il survit donc à excludeFragments, alors que les
       parties elles-mêmes, unités citables, sont retirées du fragment. -->
  <!-- L'ÉLEC n'a pas de page d'accueil d'introduction : son entrée de menu mène
       à introduction/partie-1.html, titrée « Introduction > Le notaire ». On rend
       donc ici la première partie, dont build_indexes.py a placé une copie dans
       l'<argument> — les parties elles-mêmes, unités citables, sont retirées du
       fragment servi. La liste tei:list reste disponible dans le TEI si un
       sommaire devait être réintroduit.
       2026-09-29 : la copie de la première partie n'est plus une <div> (interdite
       dans <argument> par tei_all) mais un <floatingText type="first-part">
       dont le <body> porte le titre et les paragraphes ; rendu inchangé. -->
  <xsl:template match="tei:argument[@ana = '#intro-index']" priority="12">
    <section class="christofle-intro">
      <h1 class="intro-head">
        <xsl:value-of select="normalize-space(tei:head)"/>
        <xsl:text> &gt; </xsl:text>
        <xsl:value-of select="normalize-space(tei:floatingText[@type = 'first-part']/tei:body/tei:head)"/>
      </h1>
      <xsl:apply-templates select="tei:floatingText[@type = 'first-part']/tei:body/node()[not(self::tei:head)]"/>
    </section>
  </xsl:template>

  <xsl:template match="tei:argument[@ana = '#month-index']" priority="12">
    <xsl:call-template name="christofle-month-index">
      <xsl:with-param name="month" select="."/>
    </xsl:call-template>
  </xsl:template>

  <!-- Lien de téléchargement de l'édition : export TEI live DoTS. -->
  <xsl:template match="tei:ref[starts-with(@target, 'telechargement')]" priority="12">
    <a class="christofle-download" download="christofle_1437.xml" href="{$dts-api-base}document?resource=christofle_1437&amp;mediaType=xml">
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- Liens internes hérités du site ÉLEC : ils pointaient vers des fichiers
       .html qui n'existent plus. On les redirige vers le fragment DoTS
       équivalent (les deux cibles ont un xml:id stable dans le TEI). -->
  <xsl:template match="tei:ref[@type = 'internalLink'][contains(@target, '.html')]" priority="12">
    <xsl:variable name="cible">
      <xsl:choose>
        <xsl:when test="@target = 'partie-4.html'">r1153</xsl:when>
        <xsl:when test="contains(@target, 'mentions-legales')">mentionsLegales</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$cible != ''">
        <a class="internalLink" href="{$elec-base}/christofle/document/christofle_1437?refId={$cible}">
          <xsl:apply-templates/>
        </a>
      </xsl:when>
      <!-- Cible inconnue : on garde le texte, sans lien mort. -->
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Liens externes de l'introduction : nouvel onglet. -->
  <xsl:template match="tei:ref[starts-with(@target, 'http')]" priority="11">
    <a class="externalLink" href="{@target}" target="_blank" rel="noopener"><xsl:apply-templates/></a>
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
                  <a class="internalLink note-link" href="{$elec-base}/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
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

  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]" priority="10">
    <xsl:apply-templates select="tei:front/tei:argument[@ana = '#note-nav']"/>
    <article id="{@xml:id}" class="christofle-minute">
      <header class="recordMetadata">
        <h2>
          <span class="recordNumber"><xsl:value-of select="tei:front/tei:docTitle/tei:titlePart[@type = 'number']"/></span>
          <br/>
          <span class="recordDate">
            <time datetime="{tei:front/tei:docDate/tei:date/@when}"><xsl:apply-templates select="tei:front/tei:docDate/tei:date/node()"/></time>
          </span>
        </h2>
        <xsl:if test="tei:front/tei:index/tei:term[@type = 'natureJuridique'] or tei:front/tei:div[@type = 'summary']">
          <p class="recordSummary">
            <xsl:if test="tei:front/tei:index/tei:term[@type = 'natureJuridique']">
              <span class="recordType">
                <xsl:variable name="nature" select="normalize-space(tei:front/tei:index/tei:term[@type = 'natureJuridique'][1])"/>
                <xsl:value-of select="concat(translate(substring($nature, 1, 1), 'abcdefghijklmnopqrstuvwxyzàâäéèêëîïôöùûüç', 'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ'), substring($nature, 2))"/>
              </span>
              <xsl:text>. — </xsl:text>
            </xsl:if>
            <xsl:apply-templates select="tei:front/tei:div[@type = 'summary']/tei:p/node()"/>
          </p>
        </xsl:if>
      </header>
      <div class="christofle-transcription"><xsl:apply-templates select="tei:body/node()"/></div>
      <xsl:apply-templates select="tei:back/node()"/>
    </article>
  </xsl:template>

  <!-- Renvoi d'une minute vers l'index INTERNE dots-vue (et non plus vers le site
       ELEC historique elec.enc.sorbonne.fr). L'ancre est l'@xml:id de la fiche
       (les fiches sont rendues <article id="p-…"> / <article id="l-…">).

       IMPORTANT : on vise le refId 'r65205' = la page éditable « Index des lieux
       et personnes » (parent commun des fragments 'index-personnes' et
       'index-lieux'), PAS ces fragments enfants. Motif : viser un fragment enfant
       (index-lieux#l-…) fait réécrire le SPA en 'r65205#index-lieux' et PERD
       l'ancre précise -> on reste en haut de l'index. En visant directement la
       page parent, l'ancre #l-… / #p-… est conservée et le scroll fonctionne.
       ⚠️ 'r65205' est l'id DoTS auto-généré du <div> d'index (sans xml:id dans le
       TEI) : à revérifier après toute ré-ingestion (ou donner un xml:id au div). -->
  <!-- D34 (2026-09-14) : la cible devient l'ENTRÉE elle-même.
       Mesuré : 4 032 persName + 2 170 placeName = 6 202 renvois, dont 5 996 vers
       une entrée de 1er niveau et 206 vers une sous-entrée de lieu ; 0 cible
       inconnue. Toutes sont des unités citables après la mise en lettres.
       L'ancienne forme « ?refId=r65205#p-0040 » ne peut plus fonctionner : dès
       que « Index des lieux et personnes » quitte editByCiteType, r65205 est
       servi en excludeFragments et ne contient plus aucune fiche.
       DoTS-vue conduit ensuite le lecteur tout seul : une unité au-dessous d'un
       niveau éditable est marquée « hash » et l'adresse est réécrite en
       « ?refId=idx-lettre-P#p-0040 » (mesuré sur testaments-poilus :
       ?refId=EAime devient ?refId=testateurs-A#EAime). -->
  <!-- agent_chrx2 (2026-09-14) : les <orgName @ref='#o-…'> entrent dans la règle.
       Mesuré : 21 renvois du texte (19 vers o-0001, 1 vers o-0002, 1 vers o-0003),
       toutes cibles existantes, AUCUN cliquable jusqu'ici. Ils le deviennent parce
       que les 3 <org> de l'index sont désormais des unités citables — sans quoi ils
       figureraient au sommaire sans que rien n'y mène. -->
  <!-- CORRECTIF p-1043 (2026-09-14).
       Symptôme : « ?refId=p-1043 » atteint par un clic DANS l'application
       n'affichait RIEN — pas même un #article — sous la barre de navigation de
       la page quittée. Mesuré : 0 caractère rendu, contre 1 445 après correctif.
       Cause : une entrée d'index est une unité citable de niveau 3, donc
       au-dessous du niveau éditable de DoTS-vue. Un chargement à froid de cette
       adresse est réécrit vers le parent (« ?refId=idx-lettre-V#p-1043 »), mais
       une navigation interne (router.push) ne l'est PAS et ne rend rien. D34
       (2026-09-14, plus haut) a fait viser l'entrée elle-même en pariant sur
       cette réécriture : elle n'a lieu qu'au chargement à froid. 1 511 renvois
       d'entrées étaient concernés.
       ⚠️ À NE PAS confondre avec un second défaut, réel mais SANS effet ici :
       en « excludeFragments=true » DoTS retire l'ÉLÉMENT PORTEUR lui-même
       (mesuré sur p-1043 : le <person xml:id="p-1043" corresp="#minute-003">
       disparaît, il ne reste que <persName>), si bien que les modèles
       tei:person / tei:place / tei:org ci-dessous ne s'appliquent pas, que la
       vedette retombe sur le tei:persName générique (« Villebresme de Pierre »,
       21 caractères) et que @corresp — donc le renvoi à la minute — est perdu.
       1 354 unités sur 1 943 rendent moins de 80 caractères dans ce mode.
       Mais DoTS-vue n'appelle PAS excludeFragments (relevé dans les requêtes
       réseau le 2026-09-14 : document?resource=…&ref=…&mediaType=html, sans le
       paramètre) : ce mode ne sert que l'API et l'export.
       Fidélité ÉLEC : l'ancien site ne donne pas de page à une entrée, il l'ancre
       dans la page de sa lettre — relevé dans notes/note-003.html :
       href="../index-lieux-et-personnes/lettre-V.html#p-1043". On vise donc
       l'unité citable de la lettre, plus l'ancre de l'entrée, ce qui est la forme
       recommandée pour une unité au-dessous du niveau éditable.
       La lettre de chaque entrée est portée par la source elle-même : à côté de
       son @ref (ou de son @target), chaque renvoi vers une entrée d'index a un
       @corresp="#idx-lettre-X" qui nomme la division-lettre où l'entrée vit
       réellement. Elle reste donc lisible dans le fragment servi, qui ne contient
       pas l'index et où la chaîne d'ancêtres est absente.
       2026-09-25 : le fichier compagnon christofle-index-lettres.xml, qui portait
       cette information hors de la source, a été supprimé après réinjection de ses
       1 511 entrées dans le TEI (6 380 @corresp posés).
       RETOUR EN ARRIÈRE : christofle.xsl.bak_p1043_20260914. -->

  <!-- href d'un renvoi vers une entrée d'index : identifiant de la cible, et
       division-lettre qui la contient, lue dans le @corresp du renvoi. -->
  <xsl:template name="christofle-index-href">
    <xsl:param name="cible"/>
    <xsl:param name="lettre"/>
    <xsl:value-of select="$elec-base"/>
    <xsl:text>/christofle/document/christofle_1437?refId=</xsl:text>
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

  <!-- 2026-09-29 : infobulle du lien d'index = VEDETTE de l'index, comme l'ÉLEC
       (title="Anxeau, Perrin" sur « Perrin Anxeau » ; « Belon, ép. de Jean
       Mignon »), et non plus la forme du texte.
       La vedette vit dans l'index, hors du fragment de la minute : la feuille
       relit donc le TEI complet, selon le dispositif de Montferrand
       (transform/comptes.xsl, variable $full) — pas de fichier engendré, pas
       d'interrogation de l'API (qui s'interbloquerait avec la requête en cours) :
         - déployée, christofle.xml est posé à côté de la feuille, copie exacte
           du fichier versé dans BaseX ;
         - dans le dépôt, il est lu dans ../data/.
       La vedette est écrite par les modèles mêmes de la page d'index (mode
       christofle-index-name, note de relation, placeName en mode
       christofle-index-inline) : infobulle et index ne peuvent pas diverger.
       Fichier introuvable ou cible absente : repli sur la forme du texte
       (comportement antérieur). Variable globale : évaluée seulement quand une
       page contient un lien d'index. -->

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

  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//tei:persName[@ref[starts-with(., '#p-')]] | tei:text[starts-with(@xml:id, 'minute-')]//tei:placeName[@ref[starts-with(., '#l-')]] | tei:text[starts-with(@xml:id, 'minute-')]//tei:orgName[@ref[starts-with(., '#o-')]]" priority="10">
    <xsl:variable name="cible" select="substring-after(@ref, '#')"/>
    <!-- 2026-10-04 (C9) : la vedette est écrite en @n dans le TEI ; plus de lecture du TEI complet. -->
    <xsl:variable name="vedette" select="string(@n)"/>
    <a class="linkToIndex">
      <xsl:attribute name="title">
        <xsl:choose>
          <xsl:when test="normalize-space($vedette) != ''"><xsl:value-of select="normalize-space($vedette)"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="href">
        <xsl:call-template name="christofle-index-href">
          <xsl:with-param name="cible" select="substring-after(@ref, '#')"/>
          <xsl:with-param name="lettre" select="substring-after(@corresp, '#')"/>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- L'ancienne edition affichait les folios sous la forme [77 v°]. -->
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//tei:pb" priority="10">
    <span class="pb"><xsl:text>[</xsl:text>
      <xsl:choose>
        <xsl:when test="substring(@n, string-length(@n)) = 'r' or substring(@n, string-length(@n)) = 'v'">
          <xsl:value-of select="substring(@n, 1, string-length(@n) - 1)"/><xsl:text> </xsl:text><xsl:value-of select="substring(@n, string-length(@n))"/><xsl:text>°</xsl:text>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="@n"/></xsl:otherwise>
      </xsl:choose><xsl:text>]</xsl:text>
    </span>
    <!-- Fac-similé du folio, comme dans l'édition Élec. La vignette déplie l'image
         pleine taille dans la page (<details>, sans script) : DoTS-vue fait passer
         tout lien de même origine par le routeur (target="_blank" ignoré), donc un
         <a href="/images/…"> menait à une route morte.
         D14e2 (2026-09-12) : un fac-similé par folio et non plus le seul premier de
         la minute. L'ancien site listait tous les folios (<ul class="images-list">
         « Fol. 56 v° | Fol. 57 r° ») et loadImageSectionBis (theme/utils.js)
         échangeait l'image au clic ; 113 minutes ont deux folios ou plus.
         2026-09-24 : le nom du fichier n'est plus calculé à partir de @n. Il est lu
         dans @facs — posé dans la source d'après les 387 pages de notes du site
         historique.
         2026-09-25 : @facs pilote seul l'affichage. Le recensement local
         christofle-images-locales.xml, qui confrontait chaque @facs aux JPEG du
         dossier servi, a été supprimé : les images de christofle partent sur
         Nakala, un garde-fou sur le contenu d'un dossier local n'a plus d'objet.
         A disparu avec lui le repli qui reconstruisait le nom du fichier depuis
         @n par format-number : plus rien ici n'invente de nom de fichier.
         Un <pb> sans @facs n'affiche pas d'image : c'est le cas du folio 82 cité
         dans le paratexte « Commancement d'année », que l'Élec n'illustre pas non
         plus.
         Le libellé du folio est celui de l'Élec (« 56 v° », « 57 r° ») : il est lu
         dans @n, où le recto est implicite, et non dans le nom du fichier.
         La vignette est ce même fichier suffixé « _ptt », convention du dossier
         d'images de l'édition. -->
    <xsl:variable name="facs-file" select="substring-after(@facs, 'images/sources/')"/>
    <xsl:if test="$facs-file != ''">
      <xsl:variable name="folio-label">
        <xsl:choose>
          <xsl:when test="substring(@n, string-length(@n)) = 'r' or substring(@n, string-length(@n)) = 'v'">
            <xsl:value-of select="substring(@n, 1, string-length(@n) - 1)"/><xsl:text> </xsl:text><xsl:value-of select="substring(@n, string-length(@n))"/><xsl:text>°</xsl:text>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="@n"/><xsl:text> r°</xsl:text></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:variable name="facs-vignette" select="concat(substring-before($facs-file, '.jpg'), '_ptt.jpg')"/>
      <details class="christofle-facsimile">
        <summary title="Afficher en grand le fac-similé du folio {$folio-label}">
          <img class="christofle-facsimile-vignette" src="{$elec-base}/images/christofle/vignettes/{$facs-vignette}" alt="Fac-similé du folio {$folio-label}"/>
          <span class="christofle-facsimile-ouvrir">Fol. <xsl:value-of select="$folio-label"/> — agrandir le fac-similé</span>
          <span class="christofle-facsimile-fermer">Fol. <xsl:value-of select="$folio-label"/> — réduire le fac-similé</span>
        </summary>
        <img class="christofle-facsimile-image" src="{$elec-base}/images/christofle/sources/{$facs-file}" alt="Fac-similé du folio {$folio-label}" loading="lazy"/>
        <span class="christofle-facsimile-legende">Archives départementales du Loiret, 3E 10144, fol. <xsl:value-of select="$folio-label"/></span>
      </details>
    </xsl:if>
  </xsl:template>

  <!-- Les images de l'introduction sont désormais servies par le répertoire
       statique du projet DoTS, plutôt que par les chemins relatifs Élec. -->
  <xsl:template match="tei:graphic" priority="10">
    <img class="christofle-image" src="{$elec-base}/images/christofle/{substring-after(@url, 'images/')}" alt="{normalize-space(../tei:figDesc)}"/>
  </xsl:template>

  <!-- ===================================================================
       INDEX DES LIEUX ET DES PERSONNES

       La générique ne connaît pas <person>/<place>/<listPerson>/<listPlace>
       et les affiche en rouge comme balises non gérées. On restitue ici la
       présentation de l'édition Élec : chaque entrée est une fiche portant le
       nom en vedette (surname, forename, nameLink, roleName, addName, note de
       relation) suivi des renvois aux minutes (déduits de @corresp).
       =================================================================== -->

  <!-- 2026-10-06 : index des lieux et des personnes en TABLEAU, sur une seule page.
       Trois colonnes : Nom (champ de recherche avec suggestions), Type (Personne,
       Lieu, Organisme), Minutes (recherche d'un numéro exact ; le tri range par
       nombre de minutes). Tri, compteur, « Effacer » et export CSV : module de
       Montferrand (comptes.xsl), préfixé chr-.
       Les sous-entrées de lieux ont leur ligne, « Lieu › sous-entrée ».
       Les pages par lettre (idx-lettre-A…) restent pour le sommaire et pour les
       renvois des minutes : leurs fiches ne changent pas.
       La page n'est complète que servie avec ses fragments (citeType
       indexLieuxPersonnes dans editByCiteType) ; sans eux, il ne reste que
       l'introduction, comme avant. -->
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
        <div class="chr-tableau-cadre">
          <xsl:call-template name="chr-barre-filtres">
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
                <xsl:call-template name="chr-th"><xsl:with-param name="classe" select="'chr-c-nom'"/><xsl:with-param name="libelle" select="'Nom'"/></xsl:call-template>
                <xsl:call-template name="chr-th"><xsl:with-param name="classe" select="'chr-c-type'"/><xsl:with-param name="libelle" select="'Type'"/></xsl:call-template>
                <xsl:call-template name="chr-th"><xsl:with-param name="classe" select="'chr-c-minutes'"/><xsl:with-param name="libelle" select="'Minutes'"/><xsl:with-param name="numerique" select="true()"/></xsl:call-template>
              </tr>
              <tr class="chr-filtres">
                <xsl:call-template name="chr-filtre">
                  <xsl:with-param name="col" select="0"/>
                  <xsl:with-param name="libelle" select="'Nom'"/>
                  <xsl:with-param name="suggestions" select="distinct-values($vedettes)"/>
                  <xsl:with-param name="liste" select="concat('chr-noms-', $csv-nom)"/>
                </xsl:call-template>
                <xsl:call-template name="chr-filtre">
                  <xsl:with-param name="col" select="1"/>
                  <xsl:with-param name="libelle" select="'Type'"/>
                  <xsl:with-param name="type" select="'liste'"/>
                  <xsl:with-param name="options" select="('Personne', 'Lieu', 'Organisme')"/>
                </xsl:call-template>
                <xsl:call-template name="chr-filtre">
                  <xsl:with-param name="col" select="2"/>
                  <xsl:with-param name="libelle" select="'Minute'"/>
                  <xsl:with-param name="type" select="'minutes'"/>
                </xsl:call-template>
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
                      <xsl:otherwise><span class="chr-vide">—</span></xsl:otherwise>
                    </xsl:choose>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </xsl:if>
  </xsl:template>

  <!-- Vedette en texte simple (tri, suggestions) ; sous-entrée : « Lieu › sous-entrée ». -->
  <xsl:function name="chr:vedette" as="xs:string" version="3.0">
    <xsl:param name="e" as="element()"/>
    <xsl:variable name="v"><xsl:apply-templates select="$e" mode="christofle-vedette"/></xsl:variable>
    <xsl:sequence select="normalize-space(if ($e/parent::tei:place) then concat(chr:vedette($e/parent::tei:place), ' › ', $v) else string($v))"/>
  </xsl:function>

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

  <!-- Module tableau (tri, filtres, compteur, CSV) repris de Montferrand, préfixé chr-. -->
  <xsl:function xmlns:xs="http://www.w3.org/2001/XMLSchema" name="chr:plat" as="xs:string" version="3.0">
    <xsl:param name="s" as="xs:string?"/>
    <xsl:sequence select="normalize-space(lower-case(replace(normalize-unicode(string($s), 'NFD'), '\p{Mn}', '')))"/>
  </xsl:function>
  <xsl:variable version="3.0" name="chr-tri-js">var th=this.closest('th'),tr=th.parentNode,b=th.closest('table').tBodies[0],i=Array.prototype.indexOf.call(tr.cells,th),num=th.getAttribute('data-type')==='n',d=th.getAttribute('aria-sort')==='ascending'?-1:1,c=window.chrTriColl||(window.chrTriColl=new Intl.Collator('fr',{sensitivity:'base',numeric:true})),k=Array.from(b.rows).map(function(r){var s=r.cells[i].getAttribute('data-sort')||'';return {r:r,s:s,v:num?Number(s):s,o:Number(r.getAttribute('data-o'))};});k.sort(function(x,y){if((x.s==='')!==(y.s===''))return x.s===''?1:-1;return d*(num?x.v-y.v:c.compare(x.v,y.v))||x.o-y.o;});var f=document.createDocumentFragment();k.forEach(function(e){f.appendChild(e.r);});b.appendChild(f);b.querySelectorAll('.dots-target').forEach(function(x){x.classList.remove('dots-target');});Array.from(tr.cells).forEach(function(h){h.setAttribute('aria-sort','none');});th.setAttribute('aria-sort',d===1?'ascending':'descending');</xsl:variable>
  <xsl:variable version="3.0" name="chr-filtre-js">var cadre=this.closest('.chr-tableau-cadre'),t=cadre.querySelector('table'),n=function(s){return (s||'').normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase().trim();},cr=[];cadre.querySelectorAll('.chr-filtres input, .chr-filtres select').forEach(function(e){var v=n(e.value);if(v!=='')cr.push({i:Number(e.getAttribute('data-col')),k:e.getAttribute('data-k'),v:v});});var tst=function(r,c){var f=r.cells[c.i].getAttribute('data-f')||'';if(c.k==='t')return f.indexOf(c.v)!==-1;if(c.k==='eq')return (' '+f+' ').indexOf(' '+c.v+' ')!==-1;if(c.k==='mi'){var m=/^(?:de )?(\d+)(?:\s*[-–a]\s*(\d+))?$/.exec(c.v);if(!m)return true;var lo=Number(m[1]),hi=m[2]===undefined?lo:Number(m[2]);if(lo&gt;hi){var t0=lo;lo=hi;hi=t0;}return f.split(' ').some(function(s){var x=Number(s);return s!==''&amp;&amp;x&gt;=lo&amp;&amp;x&lt;=hi;});}var x=Number(r.cells[c.i].getAttribute('data-sort')||0),y=Number(c.v);if(isNaN(y))return true;return c.k==='min'?Math.sign(x-y)!==-1:Math.sign(y-x)!==-1;};var nb=0,tot=0;Array.from(t.tBodies[0].rows).forEach(function(r){tot++;var ok=cr.every(function(c){return tst(r,c);});r.hidden=!ok;if(ok)nb++;});cadre.querySelectorAll('.chr-filtres input[list]').forEach(function(e){var d=document.getElementById(e.getAttribute('list'));if(!d)return;var col=Number(e.getAttribute('data-col')),aut=cr.filter(function(c){return c.i!==col;}),txt='';if(aut.length)Array.from(t.tBodies[0].rows).forEach(function(r){if(aut.every(function(c){return tst(r,c);}))txt+='|'+(r.cells[col].getAttribute('data-f')||'');});var q=n(e.value),qb=e.value.toLowerCase().replace(/\s+/g,'');Array.from(d.options).forEach(function(o){var v=o.getAttribute('data-n')||n(o.value),ok=v.indexOf(q)!==-1;if(ok)if(aut.length)ok=txt.indexOf(v)!==-1;o.disabled=!ok;if(ok)if(o.value.toLowerCase().replace(/\s+/g,'').indexOf(qb)===-1){o.label=v;return;}o.removeAttribute('label');});});var cp=cadre.querySelector('.chr-compteur');if(cp)cp.textContent=(cr.length?nb+' sur '+tot:tot)+' '+cp.getAttribute('data-unite');var ef=cadre.querySelector('.chr-effacer');if(ef)ef.hidden=!cr.length;</xsl:variable>
  <xsl:variable version="3.0" name="chr-effacer-js">var cadre=this.closest('.chr-tableau-cadre');cadre.querySelectorAll('.chr-filtres input, .chr-filtres select').forEach(function(e){e.value='';});cadre.querySelector('.chr-filtres input, .chr-filtres select').dispatchEvent(new Event('input',{bubbles:true}));</xsl:variable>
  <xsl:variable version="3.0" name="chr-csv-js">var cadre=this.closest('.chr-tableau-cadre'),t=cadre.querySelector('table'),q=String.fromCharCode(34),sep=';',nl=String.fromCharCode(13,10),ent=(t.getAttribute('data-csv-entetes')||'').split('|'),val=function(td){var v=td.getAttribute('data-csv');if(v===null)v=td.querySelector('.chr-vide')?'':td.innerText;return v.replace(/\s+/g,' ').trim();},champ=function(s){return q+String(s).split(q).join(q+q)+q;},lignes=[ent.map(champ).join(sep)];Array.from(t.tBodies[0].rows).forEach(function(r){if(r.hidden)return;var l=[];Array.from(r.cells).forEach(function(td){l.push(val(td));var p=td.getAttribute('data-csv-plus');if(p!==null)l.push(p);});lignes.push(l.map(champ).join(sep));});var b=new Blob([String.fromCharCode(65279)+lignes.join(nl)],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=window.URL.createObjectURL(b);a.download=(t.getAttribute('data-csv-nom')||'export')+'-'+new Date().toISOString().slice(0,10)+'.csv';document.body.appendChild(a);a.click();a.remove();setTimeout(function(){window.URL.revokeObjectURL(a.href);},1000);</xsl:variable>
  <xsl:template version="3.0" name="chr-barre-filtres">
    <xsl:param name="total"/>
    <xsl:param name="unite"/>
    <div class="chr-barre-filtres">
      <span class="chr-compteur" aria-live="polite" data-unite="{$unite}"><xsl:value-of select="concat($total, ' ', $unite)"/></span>
      <button type="button" class="chr-effacer" hidden="hidden">
        <xsl:attribute name="onclick" select="$chr-effacer-js"/>
        <xsl:text>Effacer les filtres</xsl:text>
      </button>
      <button type="button" class="chr-csv" title="Télécharger les lignes affichées, dans l’ordre du tri, au format CSV">
        <xsl:attribute name="onclick" select="$chr-csv-js"/>
        <xsl:text>Télécharger (CSV)</xsl:text>
      </button>
    </div>
  </xsl:template>
  <xsl:template version="3.0" name="chr-filtre">
    <xsl:param name="col"/>
    <xsl:param name="libelle"/>
    <xsl:param name="type" select="'texte'"/>
    <xsl:param name="min" select="''"/>
    <xsl:param name="max" select="''"/>
    <xsl:param name="options" select="()"/>
    <!-- Suggestions d'un champ texte (datalist du navigateur) : facultatives.
         Même logique « contient » que le filtre du tableau : à chaque frappe,
         chr-filtre-js désactive (disabled) les options dont la forme aplatie
         (data-n, casse et accents ôtés comme data-f) ne contient pas la saisie
         aplatie, ou qui n'apparaissent dans aucune ligne retenue par les autres
         filtres. Chrome filtre ensuite de son côté (HTMLInputElement::
         FilteredDataListOptions) : il garde une option si chaque mot tapé est
         contenu dans sa valeur OU son libellé, casse ignorée mais PAS les
         accents, et il écarte les options disabled. Quand une option n'est
         retenue qu'au prix des accents (« etienne » pour « Étienne »), le
         script lui donne pour libellé sa forme aplatie, que Chrome affiche
         sous la valeur : sans cela il la masquerait. Limite : une saisie
         accentuée ne retrouve pas dans la liste une forme écrite sans accent
         (le tableau, lui, la retrouve). -->
    <xsl:param name="suggestions" select="()"/>
    <xsl:param name="liste" select="''"/>
    <td>
      <xsl:choose>
        <xsl:when test="$type = 'intervalle'">
          <span class="chr-intervalle">
            <input type="number" data-col="{$col}" data-k="min" placeholder="{$min}" min="{$min}" max="{$max}" aria-label="{$libelle} : au moins">
              <xsl:attribute name="oninput" select="$chr-filtre-js"/>
            </input>
            <span class="chr-tiret" aria-hidden="true">–</span>
            <input type="number" data-col="{$col}" data-k="max" placeholder="{$max}" min="{$min}" max="{$max}" aria-label="{$libelle} : au plus">
              <xsl:attribute name="oninput" select="$chr-filtre-js"/>
            </input>
          </span>
        </xsl:when>
        <xsl:when test="$type = 'exact'">
          <input type="search" data-col="{$col}" data-k="eq" placeholder="N°…" inputmode="numeric" aria-label="{$libelle} : numéro exact">
            <xsl:attribute name="oninput" select="$chr-filtre-js"/>
          </input>
        </xsl:when>
        <xsl:when test="$type = 'minutes'">
          <!-- Minutes : un numéro (12), ou un intervalle (12–40, « de 12 à 40 »). Une ligne
               est retenue si l’une de ses minutes (data-f : « 3 12 40 ») tombe dans l’intervalle. -->
          <input type="search" data-col="{$col}" data-k="mi" placeholder="n° ou 12–40" aria-label="{$libelle} : un numéro, ou un intervalle de … à …" title="Un numéro (12), ou un intervalle (12–40 ou « de 12 à 40 »)">
            <xsl:attribute name="oninput" select="$chr-filtre-js"/>
          </input>
        </xsl:when>
        <xsl:when test="$type = 'liste'">
          <select data-col="{$col}" data-k="eq" aria-label="{$libelle}">
            <xsl:attribute name="onchange" select="$chr-filtre-js"/>
            <xsl:attribute name="oninput" select="$chr-filtre-js"/>
            <option value="">Toutes</option>
            <xsl:for-each select="$options">
              <option value="{chr:plat(.)}"><xsl:value-of select="."/></option>
            </xsl:for-each>
          </select>
        </xsl:when>
        <xsl:otherwise>
          <input type="search" data-col="{$col}" data-k="t" placeholder="Filtrer…" aria-label="Filtrer la colonne {$libelle}">
            <xsl:if test="exists($suggestions) and $liste != ''">
              <xsl:attribute name="list" select="$liste"/>
              <xsl:attribute name="autocomplete" select="'off'"/>
            </xsl:if>
            <xsl:attribute name="oninput" select="$chr-filtre-js"/>
          </input>
          <xsl:if test="exists($suggestions) and $liste != ''">
            <datalist id="{$liste}">
              <xsl:for-each select="$suggestions">
                <option value="{.}" data-n="{chr:plat(.)}"/>
              </xsl:for-each>
            </datalist>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>
  <xsl:template version="3.0" name="chr-th">
    <xsl:param name="classe"/>
    <xsl:param name="libelle"/>
    <xsl:param name="numerique" select="false()"/>
    <th scope="col" class="{$classe}" aria-sort="none">
      <xsl:if test="$numerique"><xsl:attribute name="data-type">n</xsl:attribute></xsl:if>
      <button type="button" class="chr-tri" title="Trier par cette colonne (cliquer de nouveau pour inverser)">
        <xsl:attribute name="onclick" select="$chr-tri-js"/>
        <xsl:value-of select="$libelle"/>
      </button>
    </th>
  </xsl:template>

  <!-- D34 : page d'une lettre (unité citable idx-lettre-A…). C'est l'équivalent
       exact des pages lettre-X.html de l'ÉLEC historique.
       ⚠ la classe « christofle-index » est OBLIGATOIRE ici : toute la mise en
       forme des fiches est écrite « .christofle-index .index-entry » dans
       christofle.customCss.css (l. 269-355). Sans elle, les pages de lettre
       perdraient leur présentation. -->
  <!-- Les sous-fragments restent consultables directement, avec le même tri. -->
  <!-- D14e2 : lettre de classement d'une vedette d'index.
       La table translate() est EXACTEMENT celle des <xsl:sort> ci-dessus : la
       lettre affichée par la barre est donc toujours celle du tri (sinon une
       vedette accentuée se rangerait sous une lettre et se filtrerait sous une
       autre). @use ne peut pas référencer une variable en XSLT 1.0 : la table
       est donc répétée littéralement dans la clé et dans le template. -->
  <!-- Parcours récursif de l'alphabet : un bouton par lettre REPRÉSENTÉE
       (key() renvoie un node-set vide pour les autres). « Toutes » est le
       choix par défaut : aucune règle :has() ne s'applique, tout reste visible. -->
  <!-- Fiche organisme. agent_chrx2 (2026-09-14).
       Le <listPerson> de l'index compte 1078 enfants : 1075 <person> et 3 <org>
       (o-0001 « Châtelet, Compagnons du », o-0002 « Saint-Aignan, chapelains de »,
       o-0003 « Saint-Ladre, chapelains de »). Aucun modèle ne les traitait : ils
       sont ABSENTS de la page depuis toujours, alors que 21 renvois du texte les
       visent. Ils deviennent des unités citables du sommaire avec D34 ; sans ce
       modèle, le sommaire porterait trois entrées ne menant à rien.
       RETOUR EN ARRIÈRE : supprimer ce modèle, retirer « tei:org » ci-dessus, et
       retirer « listPerson/org » du @match du refsDecl — les 3 <org> redeviennent
       invisibles sans que le TEI perde quoi que ce soit. -->
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
      <a class="internalLink" title="Consulter la minute" href="{$elec-base}/christofle/document/christofle_1437?refId=minute-{$mid}">
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

  <!-- D5-DEBUT (autopilote 2026-09-12) : liens vers les anciens sites ELEC -->
  <!-- hteiml fait un lien de tout tei:idno commencant par « http » (tei2html.xsl l. 1805),
       du tei:title voisin d'un idno[@type='URI'] (l. 1796) et de tei:ref/@target (l. 1456).
       Les anciens sites ELEC ferment : le TEXTE affiche est conserve mot pour mot (c'est
       l'identifiant de la publication d'origine), seule la cible devient la route locale.
       Table et bloc produits par dots-autopilot/scripts/d5_legacy_links_fix.py. -->
  <!-- portail ELEC -->
  <!-- renvoi bibliographique vers cette edition -->
  <!-- 2026-09-12 : dernier renvoi vers l'ancien site, dans l'EXEMPLE DE CITATION du teiHeader
       (« En ligne : http://elec.enc.sorbonne.fr/christofle/notes/note-136.html »). La page existe
       ici sous `minute-136` (vérifié dans la navigation DTS : 411 unités, dont minute-136). Même
       règle que le reste du bloc D5 : le TEXTE reste mot pour mot — c'est l'adresse de la
       publication d'origine, citée comme telle — et seule la cible devient la route locale. -->
  <!-- D5-FIN -->

</xsl:transform>