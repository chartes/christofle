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

  <!--
    Mois = <group type="month" xml:id="mois-NN"><head>janvier</head><text minute-…>.
    L'ELEC proposait un drill mois -> jours -> notes. Le front dots-vue rend le mois
    en excludeFragments : les <text minute-…> enfants sont EXCLUS du wrapper (seul
    le <head> arrive), et le ToC (profondeur 2) ne descend pas jusqu'aux notes ->
    aucune navigation vers les 50 minutes du mois. On restitue donc, sur la page du
    mois, un INDEX des notes GROUPÉES PAR JOUR (déduites de docDate/date/@when),
    chaque note = un lien vers son fragment (?refId=minute-NNN).

    Comme les minutes sont absentes du wrapper, on lit la source complète via
    document('christofle.xml'). Ce side-car est donc une dépendance de déploiement
    de cette surcharge et doit rester à côté de la XSL. Pur XSL, aucun script,
    aucun JS.
  -->
  <xsl:variable name="chr-full" select="document('christofle.xml')"/>

  <!-- Clé pour grouper les minutes par nature juridique (index des types d'actes).
       Utilisée dans le contexte de $chr-full (document secondaire). -->
  <xsl:key name="minByType"
           match="tei:text[starts-with(@xml:id, 'minute-')]"
           use="normalize-space((tei:front/tei:index/tei:term[@type = 'natureJuridique'])[1])"/>

  <!-- RefId DoTS de la page parent « Index des lieux et personnes ».
       Centralisé ici car cet identifiant est auto-généré et doit être revérifié
       après une ré-ingestion de la ressource. -->
  <xsl:variable name="christofle-index-refid" select="'r65205'"/>

  <!-- INDEX DES TYPES D'ACTES = fragment citeStructure (comme l'ELEC
       christofle/index-des-types-d-actes.html), et non plus un composant Vue.
       La coquille <div type="index-types-actes"> (dans le <back>) est remplie ici :
       on lit toutes les minutes via document('christofle.xml'), on les groupe par
       <term type="natureJuridique"> (Muenchian), types triés alphabétiquement,
       actes triés par numéro et liés à leur fragment (?refId=minute-NNN). -->
  <xsl:template match="tei:div[@type = 'index-types-actes']" priority="12">
    <section class="chr-types christofle-index">
      <h2><xsl:value-of select="normalize-space(tei:head)"/></h2>
      <xsl:for-each select="$chr-full">
        <xsl:variable name="minutes" select="//tei:text[starts-with(@xml:id, 'minute-')]"/>
        <p class="chr-types-intro">
          <xsl:value-of select="count($minutes[normalize-space((tei:front/tei:index/tei:term[@type = 'natureJuridique'])[1]) != ''])"/>
          <xsl:text> actes classés par nature juridique.</xsl:text>
        </p>
        <xsl:for-each select="$minutes[normalize-space((tei:front/tei:index/tei:term[@type = 'natureJuridique'])[1]) != ''][generate-id() = generate-id(key('minByType', normalize-space((tei:front/tei:index/tei:term[@type = 'natureJuridique'])[1]))[1])]">
          <xsl:sort select="normalize-space((tei:front/tei:index/tei:term[@type = 'natureJuridique'])[1])"/>
          <xsl:variable name="type" select="normalize-space((tei:front/tei:index/tei:term[@type = 'natureJuridique'])[1])"/>
          <div class="chr-type">
            <h3 class="chr-type-head">
              <xsl:value-of select="$type"/>
              <xsl:text> </xsl:text>
              <span class="chr-type-count">(<xsl:value-of select="count(key('minByType', $type))"/>)</span>
            </h3>
            <ul class="chr-acte-list">
              <xsl:for-each select="key('minByType', $type)">
                <xsl:sort select="number(tei:front/tei:docTitle/tei:titlePart[@type = 'number'])" data-type="number"/>
                <li>
                  <a href="/christofle/document/christofle_1437?refId={@xml:id}">
                    <xsl:value-of select="tei:front/tei:docTitle/tei:titlePart[@type = 'number']"/>
                  </a>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:for-each>
      </xsl:for-each>
    </section>
  </xsl:template>

  <!-- Wrapper de fragment SANS teiHeader. Cas particulier : la page d'un MOIS
       arrive en excludeFragments, réduite à <head>NOM_DU_MOIS</head> (les minutes,
       unités citables, sont retirées). On identifie le mois par son intitulé
       (unique) dans la source complète document('christofle.xml') et on rend
       l'index des notes groupées par jour. Tous les autres fragments : rendu
       par défaut (apply-templates), identique à la générique. -->
  <xsl:template match="*[local-name() = 'wrapper'][not(tei:teiHeader)]" priority="12">
    <xsl:variable name="headtext" select="normalize-space(tei:head[1])"/>
    <xsl:variable name="month" select="$chr-full//tei:group[@type = 'month'][normalize-space(tei:head) = $headtext]"/>
    <xsl:choose>
      <xsl:when test="$headtext != '' and $month and not(tei:text) and not(tei:div) and not(tei:group) and not(tei:p)">
        <xsl:call-template name="christofle-month-index">
          <xsl:with-param name="month" select="$month"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Lien de téléchargement de l'édition (<ref target="telechargement/…zip">) :
       on ne sert pas le zip historique ; on pointe vers l'EXPORT TEI live DoTS
       (source toujours à jour). Chemin relatif /api/dts (même origine que le front
       en production ; en dev sans proxy, viser http://127.0.0.1:8080/api/dts). -->
  <xsl:template match="tei:ref[starts-with(@target, 'telechargement')]" priority="12">
    <a class="christofle-download" download="christofle_1437.xml"
       href="/api/dts/document?resource=christofle_1437&amp;mediaType=xml">
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- Liens externes de l'introduction : nouvel onglet. -->
  <xsl:template match="tei:ref[starts-with(@target, 'http')]" priority="11">
    <a class="externalLink" href="{@target}" target="_blank" rel="noopener"><xsl:apply-templates/></a>
  </xsl:template>

  <!-- Index d'un mois : FILTRE PAR JOUR sans JS et sans <style> (le front retire
       les <style> injectés). Corrélation GÉNÉRIQUE via :has() (règle unique en
       CSS statique) : chaque <input type="radio"> (même name) vit DANS son
       .jour-group ; les <label for> de la barre les cochent à distance. Un jour
       coché -> .jours-index masque les groupes sans radio coché. « Tous » est un
       radio placé HORS de .jours-index : coché, aucun groupe n'est masqué.
       Chaque note est liée à son fragment (?refId=minute-NNN). -->
  <xsl:template name="christofle-month-index">
    <xsl:param name="month"/>
    <xsl:variable name="mid" select="$month/@xml:id"/>
    <xsl:variable name="minutes" select="$month/tei:text[starts-with(@xml:id, 'minute-')]"/>
    <section class="christofle-mois" id="{$mid}">
      <h2 class="mois-head"><xsl:value-of select="normalize-space($month/tei:head)"/></h2>
      <p class="mois-intro"><xsl:value-of select="count($minutes)"/> actes. Filtrez par jour ou cliquez un acte pour le consulter.</p>

      <!-- radio « Tous » : HORS de .jours-index, coché par défaut -->
      <input type="radio" name="jf-{$mid}" id="jf-{$mid}-all" class="jf-radio" checked="checked"/>

      <nav class="jours-nav" aria-label="Filtrer par jour">
        <span class="jours-label">Jours :</span>
        <label class="jour-link jour-all" for="jf-{$mid}-all">Tous</label>
        <xsl:for-each select="$minutes">
          <xsl:variable name="when" select="tei:front/tei:docDate/tei:date/@when"/>
          <xsl:if test="not(preceding-sibling::tei:text[tei:front/tei:docDate/tei:date/@when = $when])">
            <label class="jour-link" for="jf-{$mid}-{$when}" title="{normalize-space(tei:front/tei:docDate/tei:date)}">
              <xsl:value-of select="number(substring($when, 9))"/>
            </label>
          </xsl:if>
        </xsl:for-each>
      </nav>

      <div class="jours-index">
        <xsl:for-each select="$minutes">
          <xsl:variable name="when" select="tei:front/tei:docDate/tei:date/@when"/>
          <!-- une section par jour (au premier acte de la journée), englobant tous ses actes -->
          <xsl:if test="not(preceding-sibling::tei:text[tei:front/tei:docDate/tei:date/@when = $when])">
            <section class="jour-group jg-{$when}" id="jour-{$when}">
              <input type="radio" name="jf-{$mid}" id="jf-{$mid}-{$when}" class="jf-radio"/>
              <h3 class="jour-head"><xsl:value-of select="normalize-space(tei:front/tei:docDate/tei:date)"/></h3>
              <xsl:for-each select="$minutes[tei:front/tei:docDate/tei:date/@when = $when]">
                <div class="jour-note">
                  <a class="internalLink note-link" href="/christofle/document/christofle_1437?refId={@xml:id}">
                    <span class="note-num"><xsl:value-of select="tei:front/tei:docTitle/tei:titlePart[@type = 'number']"/>.</span>
                    <xsl:text> </xsl:text>
                    <xsl:variable name="nature" select="normalize-space(tei:front/tei:index/tei:term[@type = 'natureJuridique'][1])"/>
                    <xsl:if test="$nature != ''"><span class="note-type"><xsl:value-of select="$nature"/></span><xsl:text> — </xsl:text></xsl:if>
                    <span class="note-summary"><xsl:value-of select="normalize-space(tei:front/tei:div[@type = 'summary']/tei:p)"/></span>
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
       href="/christofle/document/christofle_1437?refId={$christofle-index-refid}#{substring-after(@ref, '#')}"
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
               href="/christofle/document/christofle_1437?refId={$christofle-index-refid}#{substring-after(normalize-space(@target), '#')}">
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

</xsl:transform>
