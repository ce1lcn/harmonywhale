const {spawnSync}=require('child_process'),assert=require('assert/strict');
const script=String.raw`
import runpy
b=runpy.run_path('scripts/bench-0850.py');clear=b['clear_composer'];g=clear.__globals__;calls=[]
def field(text):return {'bundle':b['SELF'],'type':'TextArea','text':text,'box':[900,1000,2000,1100]}
g['safe']=lambda *a:calls.append(a);g['hide_keyboard']=lambda:None
# An inserted space / broken-up old draft is still nonempty: abort before typing/sending.
responses=iter([[field('old draft')],[field('old dr aft')]])
g['nodes']=lambda name:next(responses)
try:clear();raise AssertionError('Nonempty composer accepted')
except RuntimeError as e:assert 'not actually empty' in str(e)
assert [a[0] for a in calls]==['click','key','key']
assert calls[1][1]=='2072 2017' and calls[2][1]=='2055'
calls.clear();responses=iter([[field('old draft')],[field('')]])
g['nodes']=lambda name:next(responses)
assert clear()['text']==''
calls.clear();g['nodes']=lambda name:[field('')]
assert clear()['text']=='' and not calls
g['nodes']=lambda name:[field(''),field('')]
try:clear();raise AssertionError('Ambiguous composer accepted')
except RuntimeError:pass
print('PASS: actual empty composer required, residual/ambiguous text aborts; Ctrl+A/Delete used instead of inserted space.')
`;
const r=spawnSync('python',['-c',script],{encoding:'utf8'});process.stdout.write(r.stdout);process.stderr.write(r.stderr);assert.equal(r.status,0);
