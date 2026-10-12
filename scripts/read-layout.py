import json,sys
sys.stdout.reconfigure(encoding='utf-8')
def walk(n):
 a=n.get('attributes',{});t=a.get('text','');kind=a.get('type','')
 if t or kind in ['TextArea','SymbolGlyph']:
  print(kind,repr(t)[:150],a.get('bounds'),a.get('id'))
 for c in n.get('children',[]):walk(c)
walk(json.load(open(sys.argv[1],encoding='utf-8')))
