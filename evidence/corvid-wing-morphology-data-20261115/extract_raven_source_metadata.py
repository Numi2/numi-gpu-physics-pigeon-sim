#!/usr/bin/env python3
"""Read archived author XLSX cached cells using the standard library only."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
import json,hashlib,re
root=Path(__file__).resolve().parent;ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
def cells(path,sheet):
 with ZipFile(path) as z:
  shared=[]
  if 'xl/sharedStrings.xml' in z.namelist():shared=[''.join(x.itertext()) for x in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)]
  tree=ET.fromstring(z.read(f'xl/worksheets/sheet{sheet}.xml'));rows=[]
  for row in tree.findall('m:sheetData/m:row',ns):
   vals={}
   for c in row.findall('m:c',ns):
    v=c.find('m:v',ns);raw=v.text if v is not None else '';val=shared[int(raw)] if c.attrib.get('t')=='s' and raw else raw
    vals[re.match(r'[A-Z]+',c.attrib['r']).group()]=val
   rows.append(vals)
  header=rows[0];return [{header[k]:v for k,v in row.items() if k in header} for row in rows[1:]]
measure=root/'bird-measurements-ready.xlsx';assumptions=root/'assumption-tracking.xlsx';body=[r for r in cells(measure,1) if 'cor_cor_20_0908' in r.get('bird_id','').lower()];wing=[r for r in cells(measure,2) if 'cor_cor_20_0908' in r.get('bird_id','').lower()];notes=[r for r in cells(assumptions,1) if r.get('species','').lower()=='cor_cor' and r.get('BirdID','').lower()=='20_0908'];out={'sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (measure,assumptions)},'original_source':'https://doi.org/10.6084/m9.figshare.14935659.v2','note':'Unmodified cached workbook cell strings; validate scope and assumptions before model use.','body':body,'wing':wing,'assumptions':notes};(root/'raven-source-metadata.json').write_text(json.dumps(out,indent=2)+'\n');print('body rows',len(body),'wing rows',len(wing),'explicit assumption rows',len(notes));print('assumptions',json.dumps(notes,indent=2))
