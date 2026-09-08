<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:import href="../hteiml/xsl/tei2html.xsl"/>

  <!--
    Page de garde a la racine (meme correctif que chroniqueslatines.xsl) :
    christofle_1437 est un corpus de minutes (<text> racine sans xml:id contenant
    de nombreux <text xml:id="minute-…">). Au rendu du document entier
    (currentLevel=0) le teiHeader (page de garde) est present ; on neutralise alors
    le corps <text> racine pour n'afficher que la garde. Les minutes rendues comme
    fragments arrivent dans un <dts:wrapper> SANS teiHeader : elles ne sont pas
    touchees (le template minute- priorite 10 continue de s'appliquer).
    Priorite 15 pour dominer proprement les templates priorite 10 de ce fichier.
  -->
  <!-- Cas 1 : rendu du TEI complet (racine) : masquer le corps <text>. -->
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text" priority="15"/>

  <!-- Cas 2 : contenu servi dans un <dts:wrapper> embarquant le teiHeader
       (rendu racine via excludeFragments) : ne produire que la page de garde. -->
  <xsl:template match="*[local-name() = 'wrapper'][tei:teiHeader]" priority="20">
    <xsl:apply-templates select="tei:teiHeader"/>
  </xsl:template>

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
  <xsl:template match="tei:ref[@type='note']">
    <a class="noteref"
       id="{@xml:id}"
       href="#{substring-after(@target, '#')}">
      <sup><xsl:call-template name="note-n"/></sup>
    </a>
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
  <xsl:template match="tei:group" priority="8">
    <section class="christofle-edition">
      <xsl:apply-templates/>
    </section>
  </xsl:template>

  <!-- Index précalculés dans data/christofle.xml par scripts/build_indexes.py.
       Ils restent disponibles dans les fragments DoTS, sans composant Vue spécifique. -->
  <xsl:variable name="christofle-index-refid" select="'r65205'"/>

  <!-- Index des types d'actes : vrai fragment TEI/DTS. -->
  <xsl:template match="tei:div[@type = 'index-types-actes']" priority="12">
    <section class="chr-types" id="{@xml:id}">
      <h1><xsl:value-of select="normalize-space(tei:head)"/></h1>
      <p class="chr-types-intro">L’index renvoie au numéro de la transaction.</p>

      <xsl:for-each select="tei:list[@type='act-types']/tei:item">
        <xsl:sort select="tei:label"/>
        <article class="chr-type">
          <h3 class="chr-type-head">
            <!-- L'ÉLEC affiche « Accord », « Contrat d'apprentissage » : seule la
                 première lettre est capitalisée. text-transform:capitalize en CSS
                 donnerait « Contrat D'apprentissage », d'où la bascule ici. -->
            <xsl:variable name="label" select="normalize-space(tei:label)"/>
            <xsl:value-of select="translate(substring($label, 1, 1),
              'abcdefghijklmnopqrstuvwxyzàâäéèêëîïôöùûüç',
              'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ')"/>
            <xsl:value-of select="substring($label, 2)"/>
            <span class="chr-type-count">
              <xsl:text> (</xsl:text>
              <xsl:value-of select="count(tei:list/tei:item/tei:ref)"/>
              <xsl:text>)</xsl:text>
            </span>
          </h3>

          <ul class="chr-acte-list">
            <xsl:for-each select="tei:list/tei:item">
              <xsl:sort select="number(tei:ref)" data-type="number"/>
              <li>
                <a title="Consulter la note"
                   class="internalLink"
                   href="/elec/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
                  <xsl:value-of select="tei:ref"/>
                </a>
                <xsl:if test="tei:date">
                  <span class="chr-acte-date">
                    <xsl:text> (</xsl:text>
                    <xsl:value-of select="tei:date"/>
                    <xsl:text>)</xsl:text>
                  </span>
                </xsl:if>
              </li>
            </xsl:for-each>
          </ul>
        </article>
      </xsl:for-each>
    </section>
  </xsl:template>

  <!-- Les mois utilisent l'argument TEI précalculé dans data/christofle.xml. -->
  <xsl:template match="*[local-name() = 'wrapper'][not(tei:teiHeader)]" priority="12">
    <xsl:choose>
      <xsl:when test="tei:argument[@type='month-index']">
        <xsl:apply-templates select="tei:argument[@type='month-index']"/>
      </xsl:when>
      <xsl:when test="tei:argument[@type='intro-index']">
        <xsl:apply-templates select="tei:argument[@type='intro-index']"/>
      </xsl:when>
      <xsl:when test="tei:argument[@type='notes-index']">
        <xsl:apply-templates select="tei:argument[@type='notes-index']"/>
      </xsl:when>
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Barre de navigation d'une note, reprise de l'ÉLEC (#months-list puis
       #days-list de notes/note-001.html) : les douze mois, puis les jours du
       mois courant. Précalculée par build_indexes.py dans chaque minute, donc
       disponible même quand le fragment est servi seul. Aucun JavaScript. -->
  <xsl:template match="tei:argument[@type = 'note-nav']" priority="12">
    <nav class="christofle-note-nav" aria-label="Navigation par mois et par jour">
      <xsl:for-each select="tei:list">
        <ul>
          <xsl:attribute name="class">
            <xsl:choose>
              <xsl:when test="@type = 'months'">months-list</xsl:when>
              <xsl:otherwise>days-list</xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:for-each select="tei:item">
            <li>
              <xsl:if test="tei:ref/@ana = 'selected'">
                <xsl:attribute name="class">selected</xsl:attribute>
              </xsl:if>
              <a class="internalLink"
                 href="/elec/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
                <xsl:choose>
                  <!-- barre des jours : le quantième suffit, le mois est au-dessus -->
                  <xsl:when test="tei:ref/@type = 'day'">
                    <xsl:value-of select="number(substring(tei:ref/@n, 9))"/>
                  </xsl:when>
                  <xsl:otherwise><xsl:value-of select="normalize-space(tei:ref)"/></xsl:otherwise>
                </xsl:choose>
              </a>
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
  <xsl:template match="tei:group[tei:argument[@type = 'notes-index']]" priority="12">
    <xsl:apply-templates select="tei:argument[@type = 'notes-index']"/>
  </xsl:template>

  <xsl:template match="tei:argument[@type = 'notes-index']" priority="12">
    <section class="christofle-notes-index">
      <h1>Édition des notes</h1>
      <p class="notes-intro">Les <xsl:value-of select="sum(tei:list/tei:item/tei:num)"/> notes de l’année 1437 sont réparties par mois. Choisissez un mois dans le sommaire, puis un jour dans la barre de filtres de la page du mois.</p>
    </section>
  </xsl:template>

  <!-- Introduction : sommaire de ses parties. Comme pour les mois, l'index est
       précalculé dans le TEI (build_indexes.py) et porté par un <argument>,
       enfant direct du <div> : il survit donc à excludeFragments, alors que les
       parties elles-mêmes, unités citables, sont retirées du fragment. -->
  <xsl:template match="tei:div[@xml:id = 'introduction'][tei:argument[@type = 'intro-index']]" priority="12">
    <xsl:apply-templates select="tei:argument[@type = 'intro-index']"/>
  </xsl:template>

  <!-- L'ÉLEC n'a pas de page d'accueil d'introduction : son entrée de menu mène
       à introduction/partie-1.html, titrée « Introduction > Le notaire ». On rend
       donc ici la première partie, dont build_indexes.py a placé une copie dans
       l'<argument> — les parties elles-mêmes, unités citables, sont retirées du
       fragment servi. La liste tei:list reste disponible dans le TEI si un
       sommaire devait être réintroduit. -->
  <xsl:template match="tei:argument[@type = 'intro-index']" priority="12">
    <section class="christofle-intro">
      <h1 class="intro-head">
        <xsl:value-of select="normalize-space(tei:head)"/>
        <xsl:text> &gt; </xsl:text>
        <xsl:value-of select="normalize-space(tei:div[@type = 'first-part']/tei:head)"/>
      </h1>
      <xsl:apply-templates select="tei:div[@type = 'first-part']/node()[not(self::tei:head)]"/>
    </section>
  </xsl:template>

  <xsl:template match="tei:group[@type='month'][tei:argument[@type='month-index']]" priority="12">
    <xsl:apply-templates select="tei:argument[@type='month-index']"/>
  </xsl:template>

  <xsl:template match="tei:argument[@type='month-index']" priority="12">
    <xsl:call-template name="christofle-month-index">
      <xsl:with-param name="month" select="."/>
    </xsl:call-template>
  </xsl:template>

  <!-- Lien de téléchargement de l'édition : export TEI live DoTS. -->
  <xsl:template match="tei:ref[starts-with(@target, 'telechargement')]" priority="12">
    <a class="christofle-download" download="christofle_1437.xml"
       href="/dots/api/dts/document?resource=christofle_1437&amp;mediaType=xml">
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
        <a class="internalLink" href="/elec/christofle/document/christofle_1437?refId={$cible}">
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
        <xsl:for-each select="$minutes">
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
          <xsl:variable name="when" select="tei:date/@when"/>
          <xsl:if test="not(preceding-sibling::tei:item[tei:date/@when = $when])">
            <section class="jour-group jg-{$when}" id="jour-{$when}">
              <input type="radio" name="jf-{$mid}" id="jf-{$mid}-{$when}" class="jf-radio"/>
              <h3 class="jour-head"><xsl:value-of select="normalize-space(tei:date)"/></h3>
              <xsl:for-each select="$minutes[tei:date/@when = $when]">
                <div class="jour-note">
                  <a class="internalLink note-link"
                     href="/elec/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
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
    <xsl:apply-templates select="tei:argument[@type = 'note-nav']"/>
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
  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//tei:persName[@ref[starts-with(., '#p-')]] | tei:text[starts-with(@xml:id, 'minute-')]//tei:placeName[@ref[starts-with(., '#l-')]]" priority="10">
    <a class="linkToIndex"
       href="/elec/christofle/document/christofle_1437?refId={$christofle-index-refid}#{substring-after(@ref, '#')}"
       title="{normalize-space(.)}">
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
    <!-- Une fiche de note reçoit le fac-similé de son premier folio, comme
         dans l'édition Élec. Les deux fichiers sont conservés localement. -->
    <xsl:if test="generate-id() = generate-id(ancestor::tei:text[1]//tei:pb[1])">
      <xsl:variable name="folio-number" select="format-number(number(substring-before(concat(@n, 'v'), 'v')), '000')"/>
      <xsl:variable name="folio-side"><xsl:choose><xsl:when test="substring(@n, string-length(@n)) = 'v'">v</xsl:when><xsl:otherwise>r</xsl:otherwise></xsl:choose></xsl:variable>
      <xsl:variable name="folio-file" select="concat('FRAD045_3E10144_f', $folio-number, '_', $folio-side)"/>
      <a class="christofle-facsimile" href="/images/christofle/sources/{$folio-file}.jpg" target="_blank" rel="noopener" title="Ouvrir le fac-similé du folio {@n}">
        <img src="/images/christofle/vignettes/{$folio-file}_ptt.jpg" alt="Fac-similé du folio {@n}"/>
      </a>
    </xsl:if>
  </xsl:template>

  <!-- Les images de l'introduction sont désormais servies par le répertoire
       statique du projet DoTS, plutôt que par les chemins relatifs Élec. -->
  <xsl:template match="tei:graphic" priority="10">
    <img class="christofle-image" src="/images/christofle/{substring-after(@url, 'images/')}" alt="{normalize-space(../tei:figDesc)}"/>
  </xsl:template>

  <!-- ===================================================================
       INDEX DES LIEUX ET DES PERSONNES

       La générique ne connaît pas <person>/<place>/<listPerson>/<listPlace>
       et les affiche en rouge comme balises non gérées. On restitue ici la
       présentation de l'édition Élec : chaque entrée est une fiche portant le
       nom en vedette (surname, forename, nameLink, roleName, addName, note de
       relation) suivi des renvois aux minutes (déduits de @corresp).
       =================================================================== -->

  <!-- Index historique ELEC : personnes ET lieux dans une seule suite alphabétique.
       Le XML conserve deux listes distinctes (persons-index / places-index), mais le rendu
       les fusionne et les trie sans modifier la source TEI. -->
  <xsl:template match="tei:div[@type = 'indexes']" priority="9">
    <section class="christofle-index christofle-index-unified">
      <xsl:apply-templates select="tei:head" mode="christofle-index"/>

      <!-- Introduction générale + explication toponymique de l'ancien index. -->
      <div class="christofle-index-intro">
        <xsl:for-each select="tei:p | tei:div[@type = 'places-index']/tei:p">
          <p><xsl:apply-templates/></p>
        </xsl:for-each>
      </div>

      <div class="christofle-index-entries">
        <xsl:for-each select=".//tei:person | tei:div[@type = 'places-index']/tei:listPlace/tei:place">
          <xsl:sort select="translate(normalize-space(string((tei:persName/tei:surname[normalize-space()] | tei:persName/tei:name[normalize-space()] | tei:persName/tei:forename[not(../tei:surname[normalize-space()] or ../tei:name[normalize-space()])] | tei:placeName)[1])), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')" data-type="text" lang="fr"/>
          <xsl:sort select="translate(normalize-space(string(tei:persName/tei:forename[1])), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')" data-type="text" lang="fr"/>
          <xsl:apply-templates select="."/>
        </xsl:for-each>
      </div>
    </section>
  </xsl:template>

  <!-- Les sous-fragments restent consultables directement, avec le même tri. -->
  <xsl:template match="tei:div[@type = 'persons-index'] | tei:div[@type = 'places-index']" priority="9">
    <section class="christofle-index christofle-index-{substring-before(@type, '-')}">
      <xsl:apply-templates select="tei:head" mode="christofle-index"/>
      <xsl:choose>
        <xsl:when test="@type = 'persons-index'">
          <xsl:for-each select=".//tei:person">
            <xsl:sort select="translate(normalize-space(string((tei:persName/tei:surname[normalize-space()] | tei:persName/tei:name[normalize-space()] | tei:persName/tei:forename[not(../tei:surname[normalize-space()] or ../tei:name[normalize-space()])] | tei:placeName)[1])), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')" data-type="text" lang="fr"/>
            <xsl:sort select="translate(normalize-space(string(tei:persName/tei:forename[1])), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')" data-type="text" lang="fr"/>
            <xsl:apply-templates select="."/>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="tei:listPlace/tei:place">
            <xsl:sort select="translate(normalize-space(string(tei:placeName)), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')" data-type="text" lang="fr"/>
            <xsl:apply-templates select="."/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </section>
  </xsl:template>

  <xsl:template match="tei:head" mode="christofle-index">
    <h2><xsl:apply-templates/></h2>
  </xsl:template>

  <xsl:template match="tei:listPerson | tei:listPlace" priority="8">
    <xsl:apply-templates select="tei:person | tei:place"/>
  </xsl:template>

  <!-- Fiche personne -->
  <xsl:template match="tei:person" priority="8">
    <article id="{@xml:id}" class="index-entry person-entry">
      <p>
        <span class="persName-entry">
          <xsl:apply-templates select="tei:persName" mode="christofle-index-name"/>
          <xsl:if test="tei:note[@type = 'relation']">
            <xsl:text>, </xsl:text>
            <span class="persName-note"><xsl:value-of select="normalize-space(tei:note[@type = 'relation'])"/></span>
          </xsl:if>
        </span>
        <xsl:call-template name="christofle-index-refs"/>
        <xsl:apply-templates select="tei:note[not(@type = 'relation')]" mode="christofle-index-seealso"/>
      </p>
    </article>
  </xsl:template>

  <!-- Nom en vedette : « Surname, Forename nameLink », « Forename, roleName »… -->
  <xsl:template match="tei:persName" mode="christofle-index-name">
    <xsl:choose>
      <xsl:when test="tei:surname">
        <span class="surname"><xsl:value-of select="normalize-space(tei:surname)"/></span>
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
  <xsl:template match="tei:place" priority="8">
    <article id="{@xml:id}" class="index-entry place-entry">
      <p>
        <span class="placeName-entry"><xsl:apply-templates select="tei:placeName" mode="christofle-index-inline"/></span>
        <xsl:if test="tei:location">
          <xsl:text> [ </xsl:text>
          <span class="location"><xsl:apply-templates select="tei:location/*" mode="christofle-index-loc"/></span>
          <xsl:text> ]</xsl:text>
        </xsl:if>
        <xsl:call-template name="christofle-index-refs"/>
        <xsl:apply-templates select="tei:note" mode="christofle-index-seealso"/>
      </p>

      <!-- Sous-entrées de lieux : abbaye, église, paroisse, etc. -->
      <xsl:if test="tei:place">
        <div class="index-subentries">
          <xsl:for-each select="tei:place">
            <xsl:sort select="translate(normalize-space(string(tei:placeName)), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')" data-type="text" lang="fr"/>
            <xsl:apply-templates select="."/>
          </xsl:for-each>
        </div>
      </xsl:if>
    </article>
  </xsl:template>

  <!-- placeName avec <term> inline : « Bannier (porte) » -->
  <xsl:template match="tei:term" mode="christofle-index-inline"><span class="term"><xsl:value-of select="normalize-space(.)"/></span><xsl:text> </xsl:text></xsl:template>
  <xsl:template match="text()" mode="christofle-index-inline"><xsl:value-of select="."/></xsl:template>

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
            <a class="linkToIndex"
               href="/elec/christofle/document/christofle_1437?refId={$christofle-index-refid}#{substring-after(normalize-space(@target), '#')}">
              <xsl:value-of select="normalize-space(.)"/>
            </a>
          </xsl:when>
          <!-- Deux renvois de la source n'ont volontairement/pas encore de @target :
               on garde leur libellé mais on ne fabrique plus de href="#". -->
          <xsl:when test="self::tei:ref">
            <xsl:value-of select="normalize-space(.)"/>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="normalize-space(.)"/><xsl:text> </xsl:text></xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
      <xsl:text>)</xsl:text>
    </span>
  </xsl:template>

  <!-- Renvois aux minutes, déduits de @corresp="#minute-120 #minute-121" -->
  <xsl:template name="christofle-index-refs">
    <xsl:if test="@corresp">
      <span class="index-refs">
        <xsl:text>&#160;: </xsl:text>
        <xsl:call-template name="christofle-refs-loop">
          <xsl:with-param name="refs" select="normalize-space(@corresp)"/>
        </xsl:call-template>
      </span>
    </xsl:if>
  </xsl:template>

  <xsl:template name="christofle-refs-loop">
    <xsl:param name="refs"/>
    <xsl:param name="first" select="true()"/>
    <xsl:variable name="head" select="substring-before(concat($refs, ' '), ' ')"/>
    <xsl:variable name="tail" select="normalize-space(substring-after($refs, ' '))"/>
    <xsl:variable name="mid" select="substring-after($head, '#minute-')"/>
    <xsl:if test="$mid != ''">
      <xsl:if test="not($first)">, </xsl:if>
      <a class="internalLink" title="Consulter la minute" href="/elec/christofle/document/christofle_1437?refId=minute-{$mid}">
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

</xsl:transform>
