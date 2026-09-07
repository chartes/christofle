"""Generate DoTS TEI indexes. Requires lxml; input is a TEI file or export URL."""
import argparse
from collections import defaultdict
from pathlib import Path
from urllib.request import urlopen
from lxml import etree as E

NS = {'t': 'http://www.tei-c.org/ns/1.0'}
XML_ID = '{http://www.w3.org/XML/1998/namespace}id'

def node(tag, text=None, **attrs):
    el = E.Element('{%s}%s' % (NS['t'], tag), **attrs)
    el.text = text or None
    return el

def text(el, path):
    return ' '.join(''.join(el.xpath(path, namespaces=NS)[0].itertext()).split()) if el.xpath(path, namespaces=NS) else ''

def enrich(root):
    minutes = root.xpath('//t:text[starts-with(@xml:id,"minute-")]', namespaces=NS)
    def edition_only(m):
        # Sérialisation de la minute privée de sa navigation : le garde-fou
        # continue de vérifier que le texte d'édition n'a pas bougé, tout en
        # autorisant l'insertion de <argument type="note-nav">.
        copy = E.fromstring(E.tostring(m))
        for nav in copy.xpath('t:argument[@type="note-nav"]', namespaces=NS):
            copy.remove(nav)
        return E.tostring(copy)

    before = [edition_only(m) for m in minutes]
    types = defaultdict(list)
    for m in minutes:
        nature = text(m, 't:front/t:index/t:term[@type="natureJuridique"]')
        if nature:
            types[nature].append(m)
    index = root.xpath('//t:div[@type="index-types-actes"]', namespaces=NS)
    assert len(index) == 1, 'Expected one types index'
    for old in index[0].xpath('t:list[@type="act-types"]', namespaces=NS):
        index[0].remove(old)
    listing = node('list', type='act-types')
    for nature, acts in sorted(types.items()):
        item = node('item')
        item.append(node('label', nature))
        links = node('list')
        for m in sorted(acts, key=lambda m: int(text(m, 't:front/t:docTitle/t:titlePart[@type="number"]'))):
            entry = node('item')
            entry.append(node('ref', text(m, 't:front/t:docTitle/t:titlePart[@type="number"]'), target='#' + m.get(XML_ID), type='act'))
            date = m.find('t:front/t:docDate/t:date', NS)
            assert date is not None and date.get('when'), 'Missing act date'
            # The historical types index shows the day and month, not the year.
            date_text = ' '.join(''.join(date.itertext()).split()).split(',', 1)[-1].strip()
            entry.append(node('date', date_text, when=date.get('when')))
            links.append(entry)
        item.append(links)
        listing.append(item)
    index[0].append(listing)
    months = root.xpath('//t:group[@type="month"]', namespaces=NS)
    for month in months:
        for old in month.xpath('t:argument[@type="month-index"]', namespaces=NS):
            month.remove(old)
        argument = node('argument', type='month-index', corresp='#' + month.get(XML_ID))
        argument.append(node('head', text(month, 't:head')))
        entries = node('list')
        for m in month.xpath('t:text[starts-with(@xml:id,"minute-")]', namespaces=NS):
            item = node('item')
            item.append(node('ref', text(m, 't:front/t:docTitle/t:titlePart[@type="number"]'), target='#' + m.get(XML_ID), type='act'))
            date = m.find('t:front/t:docDate/t:date', NS)
            assert date is not None and date.get('when'), 'Missing act date'
            item.append(node('date', ' '.join(''.join(date.itertext()).split()), when=date.get('when')))
            item.append(node('term', text(m, 't:front/t:index/t:term[@type="natureJuridique"]'), type='natureJuridique'))
            item.append(node('seg', text(m, 't:front/t:div[@type="summary"]/t:p'), type='summary'))
            entries.append(item)
        argument.append(entries)
        month.insert(list(month).index(month.find('t:head', NS)) + 1, argument)
    # Introduction : sommaire de ses parties, même principe que month-index.
    # L'<argument> est un enfant direct du <div>, donc il survit à
    # excludeFragments — c'est ce qui permet à la XSL de rendre un sommaire
    # alors que les parties, unités citables, sont retirées du fragment.
    intro = root.xpath('//t:div[@xml:id="introduction"]', namespaces=NS)
    assert len(intro) == 1, 'Expected one introduction'
    intro = intro[0]
    for old in intro.xpath('t:argument[@type="intro-index"]', namespaces=NS):
        intro.remove(old)
    argument = node('argument', type='intro-index', corresp='#introduction')
    argument.append(node('head', text(intro, 't:head')))
    parts = node('list')
    for part in intro.xpath('t:div[@xml:id]', namespaces=NS):
        item = node('item')
        item.append(node('ref', text(part, 't:head'), target='#' + part.get(XML_ID), type='section'))
        parts.append(item)
    argument.append(parts)
    # L'ÉLEC n'a pas de page d'accueil d'introduction : son entrée de menu mène
    # droit à partie-1.html. On embarque donc une copie de la première partie
    # dans l'<argument>, pour que ?refId=introduction affiche son texte alors
    # que les parties, unités citables, sont retirées du fragment servi.
    # La copie est refaite à chaque exécution : la source reste le <div>.
    first = intro.xpath('t:div[@xml:id]', namespaces=NS)[0]
    copy = E.fromstring(E.tostring(first))
    copy.tag = '{%s}div' % NS['t']
    copy.set('type', 'first-part')
    argument.append(copy)
    intro.insert(list(intro).index(intro.find('t:head', NS)) + 1, argument)

    # « Édition des notes » : sommaire des mois, avec le nombre d'actes et les
    # jours représentés. Même principe que les deux index précédents — un
    # <argument> enfant direct du <group>, qui survit à excludeFragments.
    notes = root.xpath('/t:TEI/t:text/t:group', namespaces=NS)
    assert len(notes) == 1, 'Expected one notes group'
    notes = notes[0]
    for old in notes.xpath('t:argument[@type="notes-index"]', namespaces=NS):
        notes.remove(old)
    argument = node('argument', type='notes-index', corresp='#' + notes.get(XML_ID))
    listing = node('list')
    for month in months:
        acts = month.xpath('t:text[starts-with(@xml:id,"minute-")]', namespaces=NS)
        item = node('item')
        item.append(node('ref', text(month, 't:head'), target='#' + month.get(XML_ID), type='month'))
        item.append(node('num', str(len(acts))))
        days = node('list', type='days')
        seen = []
        for m in acts:
            date = m.find('t:front/t:docDate/t:date', NS)
            when = date.get('when')
            if when in seen:
                continue
            seen.append(when)
            day = node('item')
            day.append(node('ref', ' '.join(''.join(date.itertext()).split()),
                            target='#' + m.get(XML_ID), type='day', n=when))
            days.append(day)
        item.append(days)
        listing.append(item)
    argument.append(listing)
    notes.insert(0, argument)

    # Navigation de l'ÉLEC reprise sur CHAQUE note : la barre des douze mois,
    # puis celle des jours du mois courant (cf. #months-list / #days-list de
    # notes/note-001.html). Chaque lien vise la première note du mois ou du jour,
    # comme sur le site historique ; le mois et le jour courants sont marqués.
    calendar = []
    for month in months:
        acts = month.xpath('t:text[starts-with(@xml:id,"minute-")]', namespaces=NS)
        days, seen = [], set()
        for m in acts:
            d = m.find('t:front/t:docDate/t:date', NS)
            when = d.get('when')
            if when not in seen:
                seen.add(when)
                days.append((when, m.get(XML_ID), ' '.join(''.join(d.itertext()).split())))
        calendar.append({'id': month.get(XML_ID), 'label': text(month, 't:head'),
                         'first': acts[0].get(XML_ID), 'days': days, 'acts': acts})

    for current in calendar:
        for m in current['acts']:
            for old in m.xpath('t:argument[@type="note-nav"]', namespaces=NS):
                m.remove(old)
            when = m.find('t:front/t:docDate/t:date', NS).get('when')
            nav = node('argument', type='note-nav', corresp='#' + m.get(XML_ID))
            mlist = node('list', type='months')
            for entry in calendar:
                item = node('item')
                ref = node('ref', entry['label'], target='#' + entry['first'], type='month')
                if entry['id'] == current['id']:
                    ref.set('ana', 'selected')
                item.append(ref)
                mlist.append(item)
            nav.append(mlist)
            dlist = node('list', type='days')
            for dwhen, dfirst, dlabel in current['days']:
                item = node('item')
                ref = node('ref', dlabel, target='#' + dfirst, type='day', n=dwhen)
                if dwhen == when:
                    ref.set('ana', 'selected')
                item.append(ref)
                dlist.append(item)
            nav.append(dlist)
            m.insert(0, nav)

    assert before == [edition_only(m) for m in minutes], 'Minute content changed'
    ids = set(root.xpath('//@xml:id', namespaces=NS))
    refs = root.xpath('//t:ref[@type="act" or @type="section"]', namespaces=NS)
    assert all(r.get('target', '')[1:] in ids for r in refs), 'Broken index target'
    return len(minutes), len(months), len(refs)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('output')
    args = parser.parse_args()
    raw = urlopen(args.source).read() if args.source.startswith(('http://', 'https://')) else Path(args.source).read_bytes()
    root = E.fromstring(raw, E.XMLParser(remove_blank_text=False))
    counts = enrich(root)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(E.tostring(root, encoding='UTF-8', xml_declaration=True))
    print('minutes=%s months=%s valid_index_links=%s' % counts)
