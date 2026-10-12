import {RichSpan,RichBlock} from '../agent/Markdown';
import {WebSource} from '../agent/WebTools';
import {Session,Task,ToolRecord} from '../agent/Types';

// 对话页时间线：把用户消息、助手说明、真实工具记录按时间合并，不伪造任何内容。
export interface TimelineItem {
 sources?:WebSource[];
 kind: string; // user | assistant | tool | footer
 key: string;
 time: number;
 text: string;
 id: string;
 name: string;
 label: string;
 summary: string;
 args: string;
 result: string;
 status: string;
 reasoning: string;
 observation: string;
 continued?: number; // 自动续写第几段（0.8.0.2）
}

export {RichSpan,RichBlock,parseRich} from '../agent/Markdown';


function blank(kind: string, key: string, time: number): TimelineItem {
 return {kind: kind, key: key, time: time, text: '', id: '', name: '', label: '', summary: '', args: '', result: '', status: '', reasoning: '', observation: ''};
}

export function toolItem(r: ToolRecord): TimelineItem {
 const item = blank('tool', 'r' + r.id, r.time);
 item.id = r.id;item.sources=r.sources;
 item.name = r.name;
 item.label = toolLabel(r.name);
 item.summary = r.targetLabel?(['click','click_element'].includes(r.name)?'点击「'+r.targetLabel+'」':'在「'+r.targetLabel+'」输入文字'):toolSummary(r.name, r.args);
 if(r.name==='launch_app'&&r.appName)item.summary='打开 '+r.appName;
 item.args = r.args;
 item.result = r.result+(r.verification==='unverified'?' · 效果未验证':'')+(r.errorCode?' · '+r.errorCode:'');
 item.status = r.status;
 item.reasoning = r.providerReasoning ?? '';
 item.observation = r.observation;item.label=r.appName??item.label;
 return item;
}

export function taskStart(t: Task): number {
 const n = parseInt(t.id.split('-')[0], 36);
 return Number.isFinite(n) ? n : 0;
}

function parseArgs(raw: string): Record<string, Object> {
 try {
  const v = JSON.parse(raw) as Record<string, Object>;
  return v ?? {};
 } catch (e) {
  return {};
 }
}

export function toolLabel(name: string): string {
 if(name==='web_search')return '搜索网页';if(name==='web_fetch')return '读取网页';
 if(name==='draw_path')return '手指绘制（无笔压力）';if(name==='click_element')return '定位点击';if(name==='insert_element')return '定位输入';if(name==='replace_element')return '定位替换';if(name==='wait_for')return '等待条件';if(name==='launch_app')return '打开应用';if(name==='finish_task')return '结束任务';
 if (name === 'click') return '点击';
 if (name === 'insert_text') return '输入文字';
 if (name === 'replace_text') return '替换文字';
 if (name === 'swipe') return '滑动';
 if (name === 'back') return '返回';
 if (name === 'home') return '回到桌面';
 if (name === 'observe') return '观察屏幕';
 if (name === 'request_confirmation') return '请求确认';
 if (name === 'skill_load') return '加载 Skill';
 if (name === 'skill_list') return '查看 Skill';
 if (name === 'skill_save') return '学会新技能';
 if (name === 'memory_save') return '记住';
 if (name === 'memory_forget') return '忘记';
 if (name === 'ask_user') return '提问';
 if (name === 'get_capabilities') return '查看能力';
 if (name === 'clipboard_write') return '写入剪贴板';
 if (name === 'file_write') return '写入文件';
 if (name === 'file_read') return '读取文件';
 if (name === 'file_edit') return '修改文件';
 if (name === 'todo_write') return '更新待办';
 if (name.startsWith('mcp_')) return '远程工具';
 return name;
}

export function toolSummary(name: string, raw: string): string {
 const a = parseArgs(raw);
 if(name==='web_search')return String(a.query??'');if(name==='web_fetch')return String(a.url??'');
 const num = (k: string): string => (typeof a[k] === 'number' ? Math.round(a[k] as number).toString() : '?');
 if(name==='draw_path')return '手指绘制（无笔压力）';if(name==='click_element')return '定位点击';if(name==='insert_element')return '定位输入';if(name==='replace_element')return '定位替换';if(name==='wait_for')return '等待条件';if(name==='launch_app')return '打开应用';if(name==='finish_task')return '结束任务';
 if (name === 'click') return '(' + num('x') + ', ' + num('y') + ')';
 if (name === 'swipe') return '(' + num('x') + ', ' + num('y') + ') → (' + num('x2') + ', ' + num('y2') + ')';
 if (name === 'insert_text' || name === 'replace_text' || name === 'request_confirmation') return typeof a['text'] === 'string' ? '「' + (a['text'] as string).slice(0, 60) + '」' : '';
 if (name === 'skill_load') return typeof a['name'] === 'string' ? a['name'] as string : '';
 if (name.startsWith('mcp_')) return name.split('_').slice(3).join('_');
 return '';
}

export function statusLabel(status: string): string {
 if (status === 'observing') return '正在观察';
 if (status === 'waiting') return '正在思考';
 if (status === 'running') return '正在执行';
 if (status === 'approval') return '等待确认';
 if (status === 'paused') return '已暂停';
 if (status === 'cancelled') return '已取消';
 if (status === 'completed') return '已结束';
 return '准备就绪';
}

export function recordStatusLabel(status: string): string {
 if (status === 'pending') return '执行中';
 if (status === 'success') return '✓';if(status==='error')return '没成功';if(status==='skipped')return '未执行';
 return '不确定';
}

export function formatDuration(ms: number): string {
 const s = Math.max(1, Math.round(ms / 1000));
 if (s < 60) return s + '秒';
 const m = Math.floor(s / 60);
 if (m < 60) return m + '分' + (s % 60) + '秒';
 return Math.floor(m / 60) + '小时' + (m % 60) + '分';
}

function isLive(status: string): boolean {
 return status === 'running' || status === 'observing' || status === 'waiting' || status === 'approval';
}

function firstLine(text: string, max: number): string {
 const line = text.split('\n').map((v: string) => v.trim()).filter((v: string) => v.length > 0)[0] ?? '';
 return line.length > max ? line.slice(0, max) + '…' : line;
}

// folded：被折叠的任务头（t:任务id）与工具组（g:首条记录id）。折叠任务只保留用户消息和最后一条助手回复。
export function buildTimeline(session: Session, folded: string[]): TimelineItem[] {
 const tasks: Task[] = session.tasks;
 const starts: number[] = tasks.map((t: Task) => taskStart(t));
 const owner = (time: number): number => {
  let index = 0;
  for (let i = 0; i < starts.length; i++) {
   if (starts[i] <= time) index = i;
  }
  return index;
 };
 const raw: TimelineItem[] = [];
 session.messages.forEach((m, i) => {if(m.toolCallId)return;
  const item = blank(m.role === 'user' ? 'user' : 'assistant', 'm' + i + m.time, m.time);
  item.text = m.text;item.continued=m.autoContinued;
  if(m.role==='assistant'&&m.autoContinued){const note=blank('note','ac'+i+m.time,m.time-1);note.text='↻ 回复较长，已自动续写（第 '+m.autoContinued+'/2 次）';raw.push(note);}if(m.role==='assistant'&&m.providerReasoning){const think=blank('think','km'+i+m.time,m.time);think.id='km:'+i;think.text=m.providerReasoning;think.summary=formatDuration(m.reasoningMs??1000);raw.push(think);}raw.push(item);
 });
 tasks.forEach((t: Task) => {
  t.records.forEach((r: ToolRecord) => {
   raw.push(toolItem(r));
  });
 });
 if (!tasks.length) return raw.sort((a: TimelineItem, b: TimelineItem) => a.time - b.time);
 const taskIndex: number[] = raw.map((it: TimelineItem) => owner(it.time));
 const order: number[] = raw.map((_it: TimelineItem, i: number) => i);
 order.sort((a: number, b: number) => (taskIndex[a] - taskIndex[b]) || (raw[a].time - raw[b].time) || (a - b));
 const out: TimelineItem[] = [];
 tasks.forEach((t: Task, ti: number) => {
  const items: TimelineItem[] = order.filter((i: number) => taskIndex[i] === ti).map((i: number) => raw[i]);
  const live = isLive(t.status);
  const foldedTask = folded.indexOf('t:' + t.id) >= 0;
  let lastAssistant = -1;
  items.forEach((it: TimelineItem, i: number) => {
   if (it.kind === 'assistant') lastAssistant = i;
  });
  const start = starts[ti] || (items.length ? items[0].time : 0);
  const end = live ? Date.now() : items.reduce((m: number, it: TimelineItem) => Math.max(m, it.time), start);
  const head = blank('taskhead', 'h' + t.id + t.status + (foldedTask ? 'f' : 'o') + Math.round((end - start) / 1000), 0);
  head.id = 't:' + t.id;
  head.status = t.status;
  head.summary = (live ? '执行中，已用 ' : (t.outcome==='success'?'已完成':t.outcome==='blocked'?'任务受阻':t.outcome==='needs_user'?'需要处理':t.status==='completed'&&!t.outcome?'已结束／结果未分类':statusLabel(t.status)) + '，用时 ') + formatDuration(end - start);
  const needHead = t.records.length > 0;
  const base = out.length;
  let headDone = false;
  let i = 0;
  while (i < items.length) {
   const it = items[i];
   if (it.kind === 'tool') {
    let j = i;
    while (j < items.length && items[j].kind === 'tool' && items[j].name.startsWith('web_')===it.name.startsWith('web_')) j++;
    if (!foldedTask) {
     const run = items.slice(i, j);
     const gid = 'g:' + run[0].id;
     const webRun=run.every(r=>r.name.startsWith('web_'));const closed = (webRun||run.length>=3)&&folded.indexOf('open:'+gid)<0;
     const group = blank('group', 'g' + run[0].id + run.length + (closed ? 'f' : 'o') + run.some((r: TimelineItem) => r.status === 'pending'), 0);
     group.id = gid;
     group.status = run.some((r: TimelineItem) => r.status === 'pending') ? 'pending' : '';
     const app=t.records.find(r=>r.id===run[0].id)?.appName??t.records.find(r=>!!r.appName)?.appName;group.summary = (app?'在 '+app+' 里':'')+(group.status === 'pending' ? '正在操作 ' : '操作了 ') + run.length + ' 步'+(run.every(r=>r.status==='success')?' ✓':'');
     run.forEach((r:TimelineItem)=>{if(r.reasoning){const think=blank('think','k'+r.id,r.time);think.id='k:'+r.id;think.text=r.reasoning;think.summary=formatDuration(t.records.find(v=>v.id===r.id)?.reasoningMs??1000);out.push(think);}});
     if(webRun){const seen:string[]=[];run.forEach(r=>(r.sources??[]).forEach(source=>{if(!seen.includes(source.url))seen.push(source.url);}));group.summary='查了 '+seen.length+' 个网页'+(group.status==='pending'?' · 查询中':'');}if (webRun||run.length >=3) out.push(group);
     if (!closed)run.forEach((r:TimelineItem)=>out.push(r));
    }
    i = j;
    continue;
   }
   if (!(foldedTask && (it.kind === 'note' || it.kind === 'assistant' && i !== lastAssistant))) out.push(it);
   if (it.kind === 'assistant' && i === lastAssistant && ['completed','paused','cancelled'].includes(t.status)) {
    const acts = blank('actions', 'a' + t.id + (t.usage ? t.usage.total : 0), it.time);
    acts.id = t.id;
    let full = it.text;let k = i;let cur = it;while (cur.continued) {let j = k - 1;while (j >= 0 && items[j].kind !== 'assistant') j--;if (j < 0) break;full = items[j].text + full;cur = items[j];k = j;}
    acts.text = full;
    out.push(acts);if(t.finalObservation){const screen=blank('screen','screen'+t.id,it.time);screen.id='screen:'+t.id;screen.result=t.finalObservation.path;screen.summary='结束时的屏幕';out.push(screen);}
   }
   if (!headDone && it.kind === 'user') {
    headDone = true;
    if (needHead) out.push(head);
   }
   i++;
  }
  if (!headDone && needHead) out.splice(base, 0, head);
  if ((t.status === 'paused' || t.status === 'cancelled') && t.reason) {
   const note = blank('note', 'n' + t.id + t.status, 0);
   note.status = t.status;
   note.text = statusLabel(t.status) + '：' + t.reason;
   out.push(note);
  }
 });
 return out;
}

export interface SessionGroup { label: string; items: Session[]; }

function bucket(time: number): number {
 const day = new Date();
 day.setHours(0, 0, 0, 0);
 const today = day.getTime();
 if (time >= today) return 0;
 if (time >= today - 86400000) return 1;
 if (time >= today - 6 * 86400000) return 2;
 if (time >= today - 29 * 86400000) return 3;
 return 4;
}

export function groupSessions(sessions: Session[], query: string): SessionGroup[] {
 const labels: string[] = ['置顶', '今天', '昨天', '7 天内', '30 天内', '更早'];
 const q = query.trim().toLowerCase();
 const groups: SessionGroup[] = labels.map((l: string) => ({label: l, items: []} as SessionGroup));
 sessions.slice().sort((a: Session, b: Session) => sessionTime(b) - sessionTime(a)).forEach((s: Session) => {
  if (q && s.title.toLowerCase().indexOf(q) < 0 && !s.messages.some((m) => m.text.toLowerCase().indexOf(q) >= 0)) return;
  groups[s.pinned ? 0 : bucket(sessionTime(s)) + 1].items.push(s);
 });
 return groups.filter((g: SessionGroup) => g.items.length > 0);
}

export function ago(time: number): string {
 const s = Math.max(0, Math.floor((Date.now() - time) / 1000));
 if (s < 60) return '刚刚';
 if (s < 3600) return Math.floor(s / 60) + '分钟';
 if (s < 86400) return Math.floor(s / 3600) + '小时';
 return Math.floor(s / 86400) + '天';
}

export function sessionTime(session: Session): number {
 const touched = session.touched ?? 0;
 if (session.messages.length) return Math.max(touched, session.messages[session.messages.length - 1].time);
 if (touched) return touched;
 const n = parseInt(session.id.split('-')[0], 36);
 return Number.isFinite(n) ? n : 0;
}

export function formatTokens(n: number): string {
 if (n < 1000) return n.toString();
 if (n < 1000000) return (n < 10000 ? (n / 1000).toFixed(1) : Math.round(n / 1000).toString()) + 'K';
 return (n / 1000000).toFixed(1) + 'M';
}

export function groupDigits(n: number): string {
 return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function formatClock(time: number): string {
 const d = new Date(time);
 const p = (v: number): string => (v < 10 ? '0' + v : v.toString());
 const hm = p(d.getHours()) + ':' + p(d.getMinutes());
 const now = new Date();
 if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()) return hm;
 return p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + hm;
}
