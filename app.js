const STORAGE='guyTimeDataV3';
const SUPABASE_URL='https://xmegfobzciqsokjmgmib.supabase.co';
const SUPABASE_KEY='sb_publishable_pSHG07sRyfzHOjdqDDuSDQ_fH6DNLiy';
const sb=window.supabase?.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,detectSessionInUrl:true}});
let cloud={session:null,familyId:null,familyCode:null,channel:null,syncing:false};
let data=load();
let deferredPrompt=null;
let chartDays=7;
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];

function initialData(){return {events:[],deletedIds:[],active:null,lastSide:null,pumpDraft:null}}
function exportBackup(){
  haptic(12);
  const payload={app:'Guy Time',version:'1.9',exportedAt:new Date().toISOString(),data};
  const blob=new Blob([JSON.stringify(payload,null,2)],{type:'application/json'});
  const url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;a.download=`guy-time-backup-${todayKey()}.json`;document.body.appendChild(a);a.click();a.remove();URL.revokeObjectURL(url);
  toast('קובץ הגיבוי נוצר');
}
async function importBackup(file){
  if(!file)return;
  try{
    const parsed=JSON.parse(await file.text());
    const incoming=parsed.data||parsed;
    if(!incoming||!Array.isArray(incoming.events))throw new Error('invalid');
    if(!confirm('להחליף את הנתונים במכשיר בנתוני הגיבוי?'))return;
    data={...initialData(),...incoming};save();toast('הגיבוי שוחזר');
  }catch{toast('קובץ הגיבוי אינו תקין')}
}

function load(){
  try{
    const current=JSON.parse(localStorage.getItem(STORAGE));
    if(current) return {...initialData(),...current};
    const v2=JSON.parse(localStorage.getItem('guyTimeDataV2'));
    if(v2)return {...initialData(),...v2};
    const legacy=JSON.parse(localStorage.getItem('guyTimeDataV1'));
    return legacy?{...initialData(),...legacy}:initialData();
  }catch{return initialData()}
}
function save(){localStorage.setItem(STORAGE,JSON.stringify(data));render();queueCloudSync()}
function uid(){return crypto.randomUUID?crypto.randomUUID():Date.now().toString(36)+Math.random().toString(36).slice(2)}
function todayKey(d=new Date()){return d.toLocaleDateString('en-CA')}
function fmtDuration(sec){sec=Math.max(0,Math.floor(sec));const h=String(Math.floor(sec/3600)).padStart(2,'0'),m=String(Math.floor(sec%3600/60)).padStart(2,'0'),s=String(sec%60).padStart(2,'0');return `${h}:${m}:${s}`}
function haptic(pattern=18){try{if(navigator.vibrate)navigator.vibrate(pattern)}catch{}}
function toast(t){const e=$('#toast');e.textContent=t;e.classList.add('show');setTimeout(()=>e.classList.remove('show'),1800)}
function addEvent(ev){data.events.push({id:uid(),createdAt:Date.now(),updatedAt:Date.now(),...ev});data.events.sort((a,b)=>b.start-a.start)}
function latestFeed(){return data.events.filter(e=>e.type==='nursing'||e.type==='bottle').sort((a,b)=>(b.end||b.start)-(a.end||a.start))[0]}
function isVitaminToday(){return data.events.some(e=>e.type==='vitamin'&&todayKey(new Date(e.start))===todayKey())}
function secondsSinceLastFeed(at=Date.now()) {const last=latestFeed();return last?Math.max(0,(at-(last.end||last.start))/1000):null}

function startStop(side){
  haptic();
  if(data.active){
    const end=Date.now();
    const active=data.active;
    addEvent({type:'nursing',side:active.side,start:active.start,end,duration:Math.max(1,Math.round((end-active.start)/1000))});
    data.lastSide=active.side;
    data.active=null;
    save();
    toast('ההנקה נשמרה');
    return;
  }
  data.active={side,start:Date.now(),pausedSince:secondsSinceLastFeed()};
  save();
}

function setTimerText(value){
  const el=$('#sinceLast');
  if(el.textContent===value)return;
  el.classList.add('tick-fade');
  requestAnimationFrame(()=>{
    el.textContent=value;
    requestAnimationFrame(()=>el.classList.remove('tick-fade'));
  });
}

function tick(){
  if(data.active){
    setTimerText(fmtDuration((Date.now()-data.active.start)/1000));
    $('.hero-card').classList.add('paused');
    $('.sub').textContent='משך ההנקה';
    $('#timerState').textContent=data.active.side==='right'?'ימין פעיל':'שמאל פעיל';
    $('#activeTimer').classList.remove('hidden');
    const paused=data.active.pausedSince==null?'לא הייתה האכלה קודמת':`השעון מאז ההאכלה נעצר ב־${fmtDuration(data.active.pausedSince)}`;
    $('#activeTimer').textContent=paused;
  }else{
    const elapsed=secondsSinceLastFeed();
    setTimerText(elapsed==null?'--:--:--':fmtDuration(elapsed));
    $('.hero-card').classList.remove('paused');
    $('.sub').textContent='מאז ההאכלה האחרונה';
    $('#timerState').textContent=elapsed==null?'מוכנים להאכלה הראשונה':'מוכן להאכלה הבאה';
    $('#activeTimer').classList.add('hidden');
  }
}

function render(){
  $$('.feed-btn').forEach(b=>{
    const s=b.dataset.side;
    const running=data.active && data.active.side===s;
    const last=!data.active && data.lastSide===s;
    b.classList.toggle('running',!!running);
    b.classList.toggle('last',!!last);
    b.querySelector('small').textContent=running?'לחיצה לסיום':last?'האכלה אחרונה':'לחיצה להתחלה';
    b.querySelector('small').classList.toggle('last-feed-label',!!last);
  });
  const vit=isVitaminToday();$('#vitaminBtn').classList.toggle('done',vit);$('#vitaminState').textContent=vit?'ניתן היום ✓ · לחצי לביטול':'טרם ניתן היום';
  const todays=data.events.filter(e=>todayKey(new Date(e.start))===todayKey());
  $('#todayFeeds').textContent=todays.filter(e=>['nursing','bottle'].includes(e.type)).length;
  $('#todayMinutes').textContent=Math.round(todays.filter(e=>e.type==='nursing').reduce((a,e)=>a+(e.duration||0),0)/60);
  $('#todayMl').textContent=todays.filter(e=>e.type==='bottle').reduce((a,e)=>a+(+e.ml||0),0);
  renderHistory();renderStats();tick();
}
function sideLabel(side){return side==='both'?'דו״צ':side==='right'?'ימין':'שמאל'}
function eventTitle(e){if(e.type==='nursing')return e.side==='both'?'הנקה דו״צ':`הנקה ${sideLabel(e.side)}`;if(e.type==='pumping')return `שאיבה ${sideLabel(e.side)}`;if(e.type==='bottle')return `בקבוק · ${e.milk}`;return 'ויטמין D'}
function eventDetail(e){const d=new Date(e.start);const t=d.toLocaleTimeString('he-IL',{hour:'2-digit',minute:'2-digit'});if(e.type==='nursing')return `${t} · ${Math.max(1,Math.round((e.duration||0)/60))} דקות`;if(e.type==='pumping')return `${t} · ${Math.max(1,Math.round((e.duration||0)/60))} דקות · ${e.ml||0} מ״ל`;if(e.type==='bottle')return `${t} · ${e.ml} מ״ל`;return `${t} · ניתן`}
function renderHistory(){
  const list=$('#historyList');
  const ev=[...data.events].sort((a,b)=>b.start-a.start);
  if(!ev.length){list.innerHTML='<div class="empty">עדיין אין אירועים<br>ההאכלה הראשונה תופיע כאן 💗</div>';return}
  const groups=new Map();
  ev.forEach(e=>{
    const key=todayKey(new Date(e.start));
    if(!groups.has(key))groups.set(key,[]);
    groups.get(key).push(e);
  });
  const today=todayKey(),y=new Date();y.setDate(y.getDate()-1);const yesterday=todayKey(y);
  const dayTitle=key=>key===today?'היום':key===yesterday?'אתמול':new Date(key+'T12:00:00').toLocaleDateString('he-IL',{weekday:'long',day:'numeric',month:'long'});
  list.innerHTML=[...groups].map(([key,items])=>`<section class="day-group"><h3 class="day-heading">${dayTitle(key)}</h3><div class="timeline">${items.map(e=>{
    const time=new Date(e.start).toLocaleTimeString('he-IL',{hour:'2-digit',minute:'2-digit'});
    const detail=e.type==='nursing'?`${Math.max(1,Math.round((e.duration||0)/60))} דקות`:e.type==='pumping'?`${Math.max(1,Math.round((e.duration||0)/60))} דקות · ${e.ml||0} מ״ל`:e.type==='bottle'?`${e.ml} מ״ל · ${e.milk}`:'ניתן';
    return `<article class="event"><div class="event-time">${time}</div><div class="event-icon">${e.type==='nursing'?'🤱':e.type==='pumping'?'◉':e.type==='bottle'?'🍼':'☀️'}</div><div><h4>${eventTitle(e)}</h4><p>${detail}</p></div><div class="event-actions"><button data-edit="${e.id}" aria-label="עריכה">✎</button><button data-delete="${e.id}" aria-label="מחיקה">⌫</button></div></article>`
  }).join('')}</div></section>`).join('');
  $$('[data-delete]').forEach(b=>b.onclick=()=>{haptic(12);if(confirm('למחוק את האירוע?')){data.events=data.events.filter(e=>e.id!==b.dataset.delete);data.deletedIds=[...new Set([...(data.deletedIds||[]),b.dataset.delete])];save()}});
  $$('[data-edit]').forEach(b=>b.onclick=()=>{haptic(12);openEdit(b.dataset.edit)});
}
function filtered(days){if(!days)return data.events;const cutoff=Date.now()-days*86400000;return data.events.filter(e=>e.start>=cutoff)}
function renderStats(){const ev=filtered(chartDays),nur=ev.filter(e=>e.type==='nursing'),bot=ev.filter(e=>e.type==='bottle'),pumps=ev.filter(e=>e.type==='pumping');$('#statNursing').textContent=nur.length;$('#statMinutes').textContent=Math.round(nur.reduce((a,e)=>a+(e.duration||0),0)/60);$('#statBottles').textContent=bot.length;$('#statMl').textContent=bot.reduce((a,e)=>a+(+e.ml||0),0);$('#statPumps').textContent=pumps.length;$('#statPumpMl').textContent=pumps.reduce((a,e)=>a+(+e.ml||0),0);drawFeeds(ev);drawSides([...nur,...pumps])}
function prepCanvas(c){const dpr=devicePixelRatio||1,rect=c.getBoundingClientRect();if(!rect.width)return{x:null,w:0,h:0};c.width=rect.width*dpr;c.height=(parseInt(c.getAttribute('height'))/700*rect.width)*dpr;const x=c.getContext('2d');x.scale(dpr,dpr);return{x,w:rect.width,h:c.height/dpr}}
function drawFeeds(ev){const c=$('#feedsChart'),{x,w,h}=prepCanvas(c);if(!x)return;x.clearRect(0,0,w,h);let n=chartDays||Math.min(30,Math.max(7,Math.ceil((Date.now()-Math.min(...ev.map(e=>e.start),Date.now()))/86400000)));const days=[...Array(n)].map((_,i)=>{const d=new Date();d.setHours(0,0,0,0);d.setDate(d.getDate()-(n-1-i));return d});const vals=days.map(d=>ev.filter(e=>['nursing','bottle'].includes(e.type)&&todayKey(new Date(e.start))===todayKey(d)).length),max=Math.max(1,...vals),gap=5,bw=(w-30)/n-gap;x.font='11px -apple-system';x.textAlign='center';days.forEach((d,i)=>{const bh=(h-42)*vals[i]/max,px=15+i*(bw+gap);x.fillStyle='#f48fb1';x.beginPath();x.roundRect(px,h-24-bh,bw,bh,6);x.fill();if(n<=7){x.fillStyle=getComputedStyle(document.body).color;x.fillText(d.toLocaleDateString('he-IL',{weekday:'short'}),px+bw/2,h-6)}})}
function drawSides(sideEvents){const c=$('#sidesChart'),{x,w,h}=prepCanvas(c);if(!x)return;let rightSec=0,leftSec=0;sideEvents.forEach(e=>{const d=+e.duration||0;if(e.side==='right')rightSec+=d;else if(e.side==='left')leftSec+=d;else if(e.side==='both'){rightSec+=d;leftSec+=d}});const total=Math.max(1,rightSec+leftSec);x.clearRect(0,0,w,h);const barW=w-60;x.fillStyle='#f0f1f3';x.beginPath();x.roundRect(30,65,barW,45,20);x.fill();x.fillStyle='#f48fb1';x.beginPath();x.roundRect(30,65,barW*rightSec/total,45,20);x.fill();x.fillStyle='#8fd39d';x.beginPath();x.roundRect(30+barW*rightSec/total,65,barW*leftSec/total,45,20);x.fill();x.fillStyle=getComputedStyle(document.body).color;x.font='bold 16px -apple-system';x.textAlign='center';x.fillText(`ימין ${Math.round(rightSec/60)} דק׳`,w*.27,145);x.fillText(`שמאל ${Math.round(leftSec/60)} דק׳`,w*.73,145)}
function openEdit(id){const e=data.events.find(x=>x.id===id);if(!e)return;$('#editId').value=id;const dt=new Date(e.start-e.start%60000);$('#editDate').value=new Date(dt.getTime()-dt.getTimezoneOffset()*60000).toISOString().slice(0,16);const box=$('#editDynamic');if(e.type==='nursing')box.innerHTML=`<label>צד</label><select id="editSide"><option value="right" ${e.side==='right'?'selected':''}>ימין</option><option value="left" ${e.side==='left'?'selected':''}>שמאל</option></select><label>משך בדקות</label><input id="editDuration" type="number" min="1" value="${Math.max(1,Math.round(e.duration/60))}">`;else if(e.type==='pumping')box.innerHTML=`<label>צד</label><select id="editSide"><option value="right" ${e.side==='right'?'selected':''}>ימין</option><option value="left" ${e.side==='left'?'selected':''}>שמאל</option></select><label>משך בדקות</label><input id="editDuration" type="number" min="1" value="${Math.max(1,Math.round(e.duration/60))}"><label>כמות במ״ל</label><input id="editMl" type="number" min="0" value="${e.ml||0}">`;else if(e.type==='bottle')box.innerHTML=`<label>סוג חלב</label><select id="editMilk"><option ${e.milk==='חלב אם שאוב'?'selected':''}>חלב אם שאוב</option><option ${e.milk==='תמ״ל'?'selected':''}>תמ״ל</option></select><label>כמות במ״ל</label><input id="editMl" type="number" min="0" value="${e.ml}">`;else box.innerHTML='<p>ניתן לערוך את מועד מתן הוויטמין.</p>';$('#editDialog').showModal()}
$('#editForm').addEventListener('submit',e=>{e.preventDefault();const ev=data.events.find(x=>x.id===$('#editId').value);if(!ev)return;ev.start=new Date($('#editDate').value).getTime();ev.updatedAt=Date.now();if(ev.type==='nursing'||ev.type==='pumping'){ev.side=$('#editSide').value;ev.duration=+$('#editDuration').value*60;ev.end=ev.start+ev.duration*1000;if(ev.type==='pumping')ev.ml=+$('#editMl').value}if(ev.type==='bottle'){ev.milk=$('#editMilk').value;ev.ml=+$('#editMl').value}haptic();save();$('#editDialog').close();toast('האירוע עודכן')});

$$('.feed-btn').forEach(b=>b.onclick=()=>startStop(b.dataset.side));
$('#bottleBtn').onclick=()=>{haptic(12);$('#bottleDialog').showModal()};
$('#vitaminBtn').onclick=()=>{haptic(12);const todayEvent=data.events.find(e=>e.type==='vitamin'&&todayKey(new Date(e.start))===todayKey());if(todayEvent){data.events=data.events.filter(e=>e.id!==todayEvent.id);data.deletedIds=[...new Set([...(data.deletedIds||[]),todayEvent.id])];save();toast('ויטמין D בוטל');return}addEvent({type:'vitamin',start:Date.now()});save();toast('ויטמין D נשמר')};
$('#minus').onclick=()=>{haptic(10);$('#amount').value=Math.max(0,+$('#amount').value-5)};$('#plus').onclick=()=>{haptic(10);$('#amount').value=Math.min(500,+$('#amount').value+5)};$$('[data-ml]').forEach(b=>b.onclick=()=>{haptic(10);$('#amount').value=b.dataset.ml});
$('#cancelBottle').onclick=()=>{$('#bottleDialog').close();haptic(8)};
$('#bottleForm').addEventListener('submit',e=>{e.preventDefault();const ml=+$('#amount').value;if(ml<=0)return toast('יש להזין כמות');const now=Date.now();addEvent({type:'bottle',milk:$('input[name=milk]:checked').value,ml,start:now,end:now});save();$('#bottleDialog').close();haptic();toast('הבקבוק נשמר')});


let pumpUi={side:'both',start:null,end:null};
function resetPumpUi(){pumpUi={side:'both',start:null,end:null};$('#pumpClock').textContent='00:00:00';$('#pumpAmount').value=0;$('#pumpAmountWrap').classList.add('hidden');$('#savePump').classList.add('hidden');$('#pumpStartStop').textContent='התחילי';$('#pumpStartStop').classList.remove('running');$$('[data-pump-side]').forEach(b=>b.classList.toggle('selected',b.dataset.pumpSide==='both'))}
function updatePumpClock(){if(!pumpUi.start)return;const end=pumpUi.end||Date.now();$('#pumpClock').textContent=fmtDuration((end-pumpUi.start)/1000)}
$('#pumpBtn').onclick=()=>{haptic(12);resetPumpUi();$('#pumpDialog').showModal()};
$$('[data-pump-side]').forEach(b=>b.onclick=()=>{if(pumpUi.start&&!pumpUi.end)return toast('יש לסיים את השאיבה לפני שינוי צד');haptic(10);pumpUi.side=b.dataset.pumpSide;$$('[data-pump-side]').forEach(x=>x.classList.toggle('selected',x===b))});
$('#pumpStartStop').onclick=()=>{haptic();if(!pumpUi.start){pumpUi.start=Date.now();pumpUi.end=null;$('#pumpStartStop').textContent='סיימי שאיבה';$('#pumpStartStop').classList.add('running');return}if(!pumpUi.end){pumpUi.end=Date.now();$('#pumpStartStop').textContent='השאיבה הסתיימה';$('#pumpStartStop').classList.remove('running');$('#pumpAmountWrap').classList.remove('hidden');$('#savePump').classList.remove('hidden');updatePumpClock()}};
$('#pumpMinus').onclick=()=>{haptic(8);$('#pumpAmount').value=Math.max(0,+$('#pumpAmount').value-5)};
$('#pumpPlus').onclick=()=>{haptic(8);$('#pumpAmount').value=Math.min(1000,+$('#pumpAmount').value+5)};
$('#cancelPump').onclick=()=>{if(pumpUi.start&&!pumpUi.end&&!confirm('לבטל את השאיבה הפעילה? הנתונים לא יישמרו.'))return;resetPumpUi();$('#pumpDialog').close();haptic(8)};
$('#pumpForm').addEventListener('submit',e=>{e.preventDefault();if(!pumpUi.start||!pumpUi.end)return toast('יש להתחיל ולסיים את השאיבה');const duration=Math.max(1,Math.round((pumpUi.end-pumpUi.start)/1000));addEvent({type:'pumping',side:pumpUi.side,start:pumpUi.start,end:pumpUi.end,duration,ml:+$('#pumpAmount').value||0});save();resetPumpUi();$('#pumpDialog').close();haptic();toast('השאיבה נשמרה')});
setInterval(updatePumpClock,1000);

$$('.tab').forEach(t=>t.onclick=()=>{haptic(8);$$('.tab,.page').forEach(x=>x.classList.remove('active'));t.classList.add('active');$('#'+t.dataset.page).classList.add('active');render()});$$('.range').forEach(r=>r.onclick=()=>{haptic(8);$$('.range').forEach(x=>x.classList.remove('active'));r.classList.add('active');chartDays=+r.dataset.days;renderStats()});
$('#clearAll').onclick=()=>{haptic(15);if(confirm('למחוק את כל ההיסטוריה? לא ניתן לבטל.')){const ids=data.events.map(e=>e.id);data={...initialData(),deletedIds:[...new Set([...(data.deletedIds||[]),...ids])]};save()}};
$('#exportBtn').onclick=exportBackup;
$('#importFile').onchange=e=>{importBackup(e.target.files?.[0]);e.target.value=''};


async function queueCloudSync(){if(!sb||!cloud.session||!cloud.familyId||cloud.syncing)return;cloud.syncing=true;try{const deleted=[...(data.deletedIds||[])];if(deleted.length){const {error}=await sb.from('events').delete().eq('family_id',cloud.familyId).in('id',deleted);if(error)throw error;data.deletedIds=[];localStorage.setItem(STORAGE,JSON.stringify(data))}const rows=data.events.map(e=>({id:e.id,family_id:cloud.familyId,event_data:e,updated_at:new Date(e.updatedAt||Date.now()).toISOString()}));if(rows.length){const {error}=await sb.from('events').upsert(rows,{onConflict:'id'});if(error)throw error}setCloudBadge(true)}catch(err){console.error(err);setCloudBadge(false)}finally{cloud.syncing=false}}
async function pullCloud(){if(!cloud.familyId)return;const {data:rows,error}=await sb.from('events').select('event_data').eq('family_id',cloud.familyId);if(error){console.error(error);return}const remote=(rows||[]).map(r=>r.event_data);const merged=new Map(data.events.map(e=>[e.id,e]));remote.forEach(e=>{const old=merged.get(e.id);if(!old||(e.updatedAt||0)>=(old.updatedAt||0))merged.set(e.id,e)});data.events=[...merged.values()].sort((a,b)=>b.start-a.start);localStorage.setItem(STORAGE,JSON.stringify(data));render()}
function setCloudBadge(ok){const b=$('#syncBadge');b.textContent=ok?'מסונכרן':'לא מסונכרן';b.classList.toggle('local',!ok);b.classList.toggle('connected',ok)}
async function refreshFamilyUi(){const signed=!!cloud.session;$('#authCard').classList.toggle('hidden',signed);$('#familyActions').classList.toggle('hidden',!signed||!!cloud.familyId);$('#connectedCard').classList.toggle('hidden',!cloud.familyId);$('#familyStatusTitle').textContent=cloud.familyId?'שיתוף פעיל':signed?'מחוברת לחשבון':'מצב מקומי';$('#familyStatusText').textContent=cloud.familyId?'כל אירוע מסתנכרן בין בני המשפחה. גם ללא אינטרנט הנתונים נשמרים מקומית.':signed?'צרי משפחה או הצטרפי באמצעות קוד.':'הנתונים נשמרים במכשיר הזה. אפשר להתחבר כדי לשתף ולעדכן בשני הטלפונים.';$('#familyCode').textContent=cloud.familyCode||'—';setCloudBadge(!!cloud.familyId)}
async function loadMembership(){if(!cloud.session)return;const {data:m}=await sb.from('family_members').select('family_id,families(invite_code)').eq('user_id',cloud.session.user.id).maybeSingle();cloud.familyId=m?.family_id||null;cloud.familyCode=m?.families?.invite_code||null;refreshFamilyUi();if(cloud.familyId){await pullCloud();await queueCloudSync();if(cloud.channel)await sb.removeChannel(cloud.channel);cloud.channel=sb.channel('guytime-events').on('postgres_changes',{event:'*',schema:'public',table:'events',filter:`family_id=eq.${cloud.familyId}`},()=>pullCloud()).subscribe()}}
async function initCloud(){if(!sb)return;const {data:{session}}=await sb.auth.getSession();cloud.session=session;await loadMembership();sb.auth.onAuthStateChange(async(_event,session)=>{cloud.session=session;cloud.familyId=null;cloud.familyCode=null;await loadMembership();refreshFamilyUi()})}
$('#sendMagicLink').onclick=async()=>{const email=$('#authEmail').value.trim();if(!email)return toast('יש להזין אימייל');const {error}=await sb.auth.signInWithOtp({email,options:{emailRedirectTo:location.origin+location.pathname}});toast(error?'לא ניתן לשלוח כרגע':'קישור כניסה נשלח לאימייל')};
$('#createFamilyBtn').onclick=async()=>{const {data:code,error}=await sb.rpc('create_family',{family_name:'Guy Time'});if(error)return toast('יצירת המשפחה נכשלה');toast('המשפחה נוצרה');await loadMembership();await navigator.clipboard?.writeText(code)};
$('#joinFamilyBtn').onclick=async()=>{const code=$('#joinCode').value.trim().toUpperCase();if(!code)return toast('יש להזין קוד');const {error}=await sb.rpc('join_family',{join_code:code});if(error)return toast('הקוד אינו תקין');toast('הצטרפת למשפחה');await loadMembership()};
$('#copyFamilyCode').onclick=async()=>{await navigator.clipboard?.writeText(cloud.familyCode||'');toast('הקוד הועתק')};
$('#signOutBtn').onclick=async()=>{await sb.auth.signOut();cloud={session:null,familyId:null,familyCode:null,channel:null,syncing:false};refreshFamilyUi();toast('התנתקת')};
initCloud();

window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();deferredPrompt=e;$('#installBtn').classList.remove('hidden')});$('#installBtn').onclick=async()=>{haptic(10);if(deferredPrompt){deferredPrompt.prompt();await deferredPrompt.userChoice;deferredPrompt=null;$('#installBtn').classList.add('hidden')}else toast('ב־Safari: שיתוף ← הוספה למסך הבית')};
if('serviceWorker'in navigator)window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js'));
window.addEventListener('resize',()=>renderStats());setInterval(tick,1000);setTimeout(()=>{$('#splash').style.opacity='0';setTimeout(()=>{$('#splash').remove();$('#app').classList.remove('hidden');render()},400)},900);
