<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:import href="../hteiml/xsl/tei2html.xsl"/>

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

  <xsl:template match="tei:ref[@type='note']">
    <xsl:variable name="corps" select="key('chr-note-by-id', substring-after(@target, '#'))[1]"/>
    <a class="noteref"
       id="{@xml:id}"
       href="#{substring-after(@target, '#')}">
      <xsl:if test="$corps">
        <!-- « 1. La lettre J est decoree d'entrelacs. » : le numero precedait le
             texte dans le <span class="apparatusNote"> de l'ancien site. -->
        <xsl:attribute name="data-tip">
          <xsl:value-of select="normalize-space(concat(@n, '. ', normalize-space($corps)))"/>
        </xsl:attribute>
      </xsl:if>
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
  <!-- D34 : plus aucun lien ne s'en sert (les deux modèles qui l'employaient
       visent désormais l'entrée). Conservée : elle documente l'identifiant de la
       page d'index, et un retour en arrière tient en deux remplacements. -->
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
                   href="/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
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
                 href="/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
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
       href="http://127.0.0.1:8080/api/dts/document?resource=christofle_1437&amp;mediaType=xml">
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
        <a class="internalLink" href="/christofle/document/christofle_1437?refId={$cible}">
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
                     href="/christofle/document/christofle_1437?refId={substring-after(tei:ref/@target, '#')}">
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
       La lettre de chaque entrée est lue dans christofle-index-lettres.xml
       (fichier généré, même procédé que delescluze-persons.xml) : le fragment
       servi ne contient pas l'index, on ne peut pas la calculer sur place.
       RETOUR EN ARRIÈRE : christofle.xsl.bak_p1043_20260914. -->
  <xsl:variable name="christofle-index-lettres" select="document('christofle-index-lettres.xml')/index-lettres"/>

  <!-- href d'un renvoi vers une entrée d'index, à partir de son seul identifiant. -->
  <xsl:template name="christofle-index-href">
    <xsl:param name="cible"/>
    <xsl:variable name="lettre" select="$christofle-index-lettres/e[@id = $cible]/@lettre"/>
    <xsl:text>/christofle/document/christofle_1437?refId=</xsl:text>
    <xsl:choose>
      <!-- Entrée connue : page de la lettre + ancre, comme l'ÉLEC. -->
      <xsl:when test="$lettre">
        <xsl:value-of select="$lettre"/>
        <xsl:text>#</xsl:text>
        <xsl:value-of select="$cible"/>
      </xsl:when>
      <!-- Cible inconnue de la carte (0 cas mesuré sur les 1 447 cibles du TEI) :
           on garde l'ancien comportement plutôt que de fabriquer un lien faux. -->
      <xsl:otherwise><xsl:value-of select="$cible"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:text[starts-with(@xml:id, 'minute-')]//tei:persName[@ref[starts-with(., '#p-')]] | tei:text[starts-with(@xml:id, 'minute-')]//tei:placeName[@ref[starts-with(., '#l-')]] | tei:text[starts-with(@xml:id, 'minute-')]//tei:orgName[@ref[starts-with(., '#o-')]]" priority="10">
    <a class="linkToIndex" title="{normalize-space(.)}">
      <xsl:attribute name="href">
        <xsl:call-template name="christofle-index-href">
          <xsl:with-param name="cible" select="substring-after(@ref, '#')"/>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- Recensement des fac-similés réellement servis, relevé sur les pages de notes
       de l'édition Élec et vérifié dans dots-vue/public/images/christofle/ ;
       même dispositif que saint-denis-images-locales.xml. -->
  <xsl:variable name="christofle-images-locales" select="document('christofle-images-locales.xml')/images"/>

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
         historique — puis confronté au recensement christofle-images-locales.xml.
         Un <pb> sans @facs, ou dont le fichier n'est pas recensé, n'affiche pas
         d'image plutôt que d'ouvrir un lien mort : c'est le cas du folio 82 cité
         dans le paratexte « Commancement d'année », que l'Élec n'illustre pas non
         plus. -->
    <xsl:variable name="facs-file" select="substring-after(@facs, 'images/sources/')"/>
    <xsl:variable name="folio" select="$christofle-images-locales/folio[@fichier = $facs-file][1]"/>
    <xsl:if test="$folio">
      <xsl:variable name="folio-label" select="$folio/@libelle"/>
      <details class="christofle-facsimile">
        <summary title="Afficher en grand le fac-similé du folio {$folio-label}">
          <img class="christofle-facsimile-vignette" src="/images/christofle/vignettes/{$folio/@vignette}" alt="Fac-similé du folio {$folio-label}"/>
          <span class="christofle-facsimile-ouvrir">Fol. <xsl:value-of select="$folio-label"/> — agrandir le fac-similé</span>
          <span class="christofle-facsimile-fermer">Fol. <xsl:value-of select="$folio-label"/> — réduire le fac-similé</span>
        </summary>
        <img class="christofle-facsimile-image" src="/images/christofle/sources/{$folio/@fichier}" alt="Fac-similé du folio {$folio-label}" loading="lazy"/>
        <span class="christofle-facsimile-legende">Archives départementales du Loiret, 3E 10144, fol. <xsl:value-of select="$folio-label"/></span>
      </details>
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

      <!-- D34 (2026-09-14) : la barre des 21 boutons de filtre est RETIRÉE.
           Les lettres sont désormais des unités citables du TEI
           (div[@type='lettre'], xml:id=idx-lettre-A…) : elles paraissent dans le
           sommaire de gauche, avec leurs 1 420 entrées. Garder la barre ferait
           doublon — c'est ce qui a été retiré partout ailleurs (D28).
           Le modèle christofle-lettres-bar et la clé chr-idx-lettre restent dans
           la feuille, inutilisés, pour un retour en arrière en une ligne.
           Les 26 règles :has() de christofle.customCss.css (l. 547-635) deviennent
           elles aussi sans objet ; elles sont inoffensives et peuvent rester.

           Cette page-ci n'est plus servie qu'en excludeFragments (dès que
           « Index des lieux et personnes » quitte editByCiteType) : les
           div[@type='lettre'] en sont retirés par DoTS et il ne reste que les
           deux paragraphes d'introduction. L'apply-templates ci-dessous ne sert
           donc que si l'on sert l'unité entière (API, export) : il rend alors
           l'index complet, lettre par lettre, sans rien perdre. -->
      <div class="christofle-index-entries">
        <xsl:for-each select="tei:div[@type = 'lettre']">
          <!-- D34 : plus de xsl:sort. L'ordre alphabétique mêlé est désormais
               celui de la SOURCE, écrit par d34_christofle_index_lettres.xq avec
               une clé réglée sur celle-ci (0 divergence sur 1 420 vérifiée).
               Trier encore ferait diverger la page du sommaire, qui suit
               l'ordre du document. -->
          <xsl:apply-templates select="."/>
        </xsl:for-each>
      </div>
    </section>
  </xsl:template>

  <!-- D34 : page d'une lettre (unité citable idx-lettre-A…). C'est l'équivalent
       exact des pages lettre-X.html de l'ÉLEC historique.
       ⚠ la classe « christofle-index » est OBLIGATOIRE ici : toute la mise en
       forme des fiches est écrite « .christofle-index .index-entry » dans
       christofle.customCss.css (l. 269-355). Sans elle, les pages de lettre
       perdraient leur présentation. -->
  <xsl:template match="tei:div[@type = 'lettre']" priority="9">
    <section class="christofle-index christofle-index-lettre">
      <xsl:if test="tei:head">
        <h2 class="christofle-index-lettre-titre"><xsl:value-of select="normalize-space(tei:head)"/></h2>
      </xsl:if>
      <div class="christofle-index-entries">
        <xsl:apply-templates select="tei:listPerson | tei:listPlace"/>
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

  <!-- D14e2 : lettre de classement d'une vedette d'index.
       La table translate() est EXACTEMENT celle des <xsl:sort> ci-dessus : la
       lettre affichée par la barre est donc toujours celle du tri (sinon une
       vedette accentuée se rangerait sous une lettre et se filtrerait sous une
       autre). @use ne peut pas référencer une variable en XSLT 1.0 : la table
       est donc répétée littéralement dans la clé et dans le template. -->
  <xsl:key name="chr-idx-lettre"
           match="tei:person | tei:div[@type = 'places-index']/tei:listPlace/tei:place"
           use="translate(substring(normalize-space(string((tei:persName/tei:surname[normalize-space()] | tei:persName/tei:name[normalize-space()] | tei:persName/tei:forename[not(../tei:surname[normalize-space()] or ../tei:name[normalize-space()])] | tei:placeName)[1])), 1, 1), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')"/>

  <xsl:template name="christofle-index-lettre">
    <!-- agent_chrx2 : « tei:orgName » ajouté à l'union, pour les 3 <org>. La même
         branche a été ajoutée à local:vedette() de d34_christofle_index_lettres.xq :
         les deux doivent rester d'accord, sinon une vedette se rangerait sous une
         lettre et s'afficherait sous une autre. -->
    <xsl:variable name="vedette" select="normalize-space(string((tei:persName/tei:surname[normalize-space()] | tei:persName/tei:name[normalize-space()] | tei:persName/tei:forename[not(../tei:surname[normalize-space()] or ../tei:name[normalize-space()])] | tei:placeName | tei:orgName)[1]))"/>
    <xsl:variable name="c" select="translate(substring($vedette, 1, 1), 'abcdefghijklmnopqrstuvwxyzàáâäãåÀÁÂÄÃÅçÇéèêëÉÈÊËíìîïÍÌÎÏñÑóòôöõÓÒÔÖÕùúûüÙÚÛÜÿýŸÝœŒæÆ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAAAAAAAAACCEEEEEEEEIIIIIIIINNOOOOOOOOOOUUUUUUUUYYYYOOAA')"/>
    <xsl:choose>
      <!-- contains(…, '') est vrai : le test sur $c non vide est nécessaire. -->
      <xsl:when test="$c != '' and contains('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $c)">
        <xsl:value-of select="$c"/>
      </xsl:when>
      <xsl:otherwise>#</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Parcours récursif de l'alphabet : un bouton par lettre REPRÉSENTÉE
       (key() renvoie un node-set vide pour les autres). « Toutes » est le
       choix par défaut : aucune règle :has() ne s'applique, tout reste visible. -->
  <xsl:template name="christofle-lettres-bar">
    <nav class="chr-lettres" aria-label="Filtrer l’index par lettre">
      <span class="chr-lettres-label">Lettre :</span>
      <span class="chr-lettre chr-lettre-tous">
        <input type="radio" name="chr-lettre" value="__tous__" id="chr-lettre-tous" class="chr-lettre-radio" checked="checked"/>
        <label for="chr-lettre-tous">Toutes</label>
      </span>
      <xsl:call-template name="christofle-lettres-bar-loop"/>
    </nav>
  </xsl:template>

  <xsl:template name="christofle-lettres-bar-loop">
    <xsl:param name="alphabet" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>
    <xsl:if test="$alphabet != ''">
      <xsl:variable name="L" select="substring($alphabet, 1, 1)"/>
      <xsl:if test="key('chr-idx-lettre', $L)">
        <span class="chr-lettre">
          <input type="radio" name="chr-lettre" value="{$L}" id="chr-lettre-{$L}" class="chr-lettre-radio"/>
          <label for="chr-lettre-{$L}" title="{count(key('chr-idx-lettre', $L))} vedettes"><xsl:value-of select="$L"/></label>
        </span>
      </xsl:if>
      <xsl:call-template name="christofle-lettres-bar-loop">
        <xsl:with-param name="alphabet" select="substring($alphabet, 2)"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:listPerson | tei:listPlace" priority="8">
    <xsl:apply-templates select="tei:person | tei:org | tei:place"/>
  </xsl:template>

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
  <xsl:template match="tei:org" priority="8">
    <article id="{@xml:id}" class="index-entry org-entry">
      <xsl:attribute name="data-lettre"><xsl:call-template name="christofle-index-lettre"/></xsl:attribute>
      <p>
        <span class="orgName-entry"><xsl:value-of select="normalize-space(tei:orgName[1])"/></span>
        <xsl:call-template name="christofle-index-refs"/>
        <xsl:apply-templates select="tei:note" mode="christofle-index-seealso"/>
      </p>
    </article>
  </xsl:template>

  <!-- Fiche personne -->
  <xsl:template match="tei:person" priority="8">
    <article id="{@xml:id}" class="index-entry person-entry">
      <!-- D14e2 : cible des règles de filtre par lettre (barre .chr-lettres). -->
      <xsl:attribute name="data-lettre"><xsl:call-template name="christofle-index-lettre"/></xsl:attribute>
      <p>
        <span class="persName-entry">
          <!-- 2026-09-13 : SEULEMENT le premier <persName>. 24 personnes du corpus en portent
               deux (formes graphiques concurrentes du même nom), et les rendre l'un après
               l'autre donnait « Barbechon, Baubin Barbachon, Baubin » — le nom complet deux
               fois de suite, sans séparateur. L'ÉLEC n'imprime pas cela : il joint les formes
               du NOM DE FAMILLE par une barre oblique et ne répète pas le prénom, soit
               « Barbechon / Barbachon, Baubin » (relevé dans la source de
               index-lieux-et-personnes/lettre-B.html). Les variantes sont donc passées au
               modèle de la vedette, qui les insère au bon endroit. -->
          <xsl:apply-templates select="tei:persName[1]" mode="christofle-index-name">
            <xsl:with-param name="variantes" select="tei:persName[position() > 1]"/>
          </xsl:apply-templates>
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
    <!-- Les autres <persName> de la même personne : leurs noms de famille viennent s'ajouter
         derrière le premier, séparés par « / », avant le prénom. -->
    <xsl:param name="variantes" select="()"/>
    <xsl:choose>
      <xsl:when test="tei:surname">
        <span class="surname"><xsl:value-of select="normalize-space(tei:surname)"/></span>
        <xsl:for-each select="$variantes/tei:surname[normalize-space()]
                              [normalize-space() != normalize-space(current()/tei:surname)]">
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
  <xsl:template match="tei:place" priority="8">
    <article id="{@xml:id}" class="index-entry place-entry">
      <!-- D14e2 : idem. Les sous-entrées de lieux en héritent aussi, mais les
           règles de filtre ne visent que les enfants directs de
           .christofle-index-entries : une sous-entrée suit toujours son parent. -->
      <xsl:attribute name="data-lettre"><xsl:call-template name="christofle-index-lettre"/></xsl:attribute>
      <p>
        <!-- 2026-09-13 : 37 lieux portent deux ou trois <placeName> (forme historique et forme
             actuelle). Les rendre à la suite les collait : « Saint-Privé-lez-OrléansSaint-Pryvé-
             Saint-Mesmin ». L'ÉLEC les sépare par une barre oblique — « Saint-Privé-lez-Orléans /
             Saint-Pryvé-Saint-Mesmin » (relevé dans index-lieux-et-personnes/lettre-S.html). -->
        <span class="placeName-entry">
          <xsl:for-each select="tei:placeName">
            <xsl:if test="position() > 1"><xsl:text> / </xsl:text></xsl:if>
            <xsl:apply-templates select="." mode="christofle-index-inline"/>
          </xsl:for-each>
        </span>
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
            <!-- D34 : idem pour les 157 renvois « voir » internes à l'index
                 (156 vers une entrée, 1 vers une sous-entrée).
                 CORRECTIF p-1043 : même cible que les renvois des minutes,
                 « page de la lettre + ancre » ; sinon ces 157 liens mènent eux
                 aussi à une page vide. -->
            <a class="linkToIndex">
              <xsl:attribute name="href">
                <xsl:call-template name="christofle-index-href">
                  <xsl:with-param name="cible" select="substring-after(normalize-space(@target), '#')"/>
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
      <a class="internalLink" title="Consulter la minute" href="/christofle/document/christofle_1437?refId=minute-{$mid}">
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
  <xsl:template match="tei:title[../tei:idno[@type = 'URI'][normalize-space(.) = 'http://elec.enc.sorbonne.fr' or normalize-space(.) = 'http://elec.enc.sorbonne.fr/']]" priority="14">
    <a class="title d5-local" href="/"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- renvoi bibliographique vers cette edition -->
  <xsl:template match="tei:ref[@target = 'http://elec.enc.sorbonne.fr/christofle/']" priority="14">
    <a class="ref d5-local" href="/christofle"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- 2026-09-12 : dernier renvoi vers l'ancien site, dans l'EXEMPLE DE CITATION du teiHeader
       (« En ligne : http://elec.enc.sorbonne.fr/christofle/notes/note-136.html »). La page existe
       ici sous `minute-136` (vérifié dans la navigation DTS : 411 unités, dont minute-136). Même
       règle que le reste du bloc D5 : le TEXTE reste mot pour mot — c'est l'adresse de la
       publication d'origine, citée comme telle — et seule la cible devient la route locale. -->
  <xsl:template match="tei:ref[normalize-space(@target) = 'http://elec.enc.sorbonne.fr/christofle/notes/note-136.html']" priority="15">
    <a class="ref d5-local" href="/christofle/document/christofle_1437?refId=minute-136"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- D5-FIN -->

</xsl:transform>
