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
    before = [E.tostring(m) for m in minutes]
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
    assert before == [E.tostring(m) for m in minutes], 'Minute content changed'
    ids = set(root.xpath('//@xml:id', namespaces=NS))
    refs = root.xpath('//t:ref[@type="act"]', namespaces=NS)
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
