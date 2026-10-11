import { MemoryRouter, useLocation } from 'react-router-dom';
import { Link, changePage, pageMotionFor } from '../../src/design/NavigationMotion';
import { RouteEffects } from '../../src/components/RouteEffects';
import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {flushSync} from 'react-dom';
import {AnimatePresence} from 'motion/react';
import {MotionPreferences,MotionToggle} from '../../src/design/MotionPreferences';
import {SelectionGroup,SelectionContent} from '../../src/design/SelectionMotion';
import {Dialog} from '../../src/components/Dialog';
import {RosemarySelect} from '../../src/components/ui';
import '../../src/styles.css';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const frame=()=>new Promise(r=>requestAnimationFrame(r));
const timing=el=>el?.getAnimations().map(a=>({duration:a.effect.getTiming().duration,easing:a.effect.getTiming().easing,frames:a.effect.getKeyframes()}))||[];
function App(){
 const {pathname}=useLocation();
 const [selection,setSelection]=useState(0),[open,setOpen]=useState(false),[value,setValue]=useState('email'),[report,setReport]=useState('等待验证');
 async function run(){
  const results=[]; const assert=(name,pass,detail)=>results.push({name,pass,detail});
  const toggle=document.querySelector('.epass-motion');
  if(toggle.getAttribute('aria-pressed')==='true'){flushSync(()=>toggle.click());await frame();}
  const panel=document.querySelector('.test-panel');
  assert('first render has no panel entrance',timing(panel).length===0);
  flushSync(()=>setSelection(1));
  const initial=timing(panel)[0];
  assert('panel 240ms / standard / 12px',initial?.duration===240&&initial.easing==='cubic-bezier(0.2, 0, 0, 1)'&&initial.frames[0].transform==='translateX(12px)',initial);
  assert('single live form',document.querySelectorAll('.test-panel form').length===1);
  await pause(65);
  const before=getComputedStyle(panel).transform;
  flushSync(()=>setSelection(0));
  const after=timing(panel)[0];
  assert('interrupted panel resumes current position',after?.frames[0].transform===before,{before,after:after?.frames[0].transform});
  flushSync(()=>toggle.click());
  assert('reduced motion cancels running panel',timing(panel).length===0);
  flushSync(()=>setSelection(1));
  assert('reduced motion suppresses next panel',timing(panel).length===0);
  flushSync(()=>toggle.click());
  const select=document.querySelector('[role="combobox"]');
  flushSync(()=>select.click());await frame();
  const list=document.querySelector('[role="listbox"]');
  assert('select enters 180ms',getComputedStyle(list).transitionDuration.split(',').every(s=>s.trim()==='0.18s'),getComputedStyle(list).transitionDuration);
  flushSync(()=>select.click());
  assert('select exit is inert and hidden immediately',list.inert&&list.getAttribute('aria-hidden')==='true'&&select.getAttribute('aria-expanded')==='false');
  assert('select exits 120ms',getComputedStyle(list).transitionDuration==='0.12s');
  await pause(160);
  assert('select removed after exit',!document.querySelector('[role="listbox"]'));
  const opener=document.getElementById('open');opener.focus();
  flushSync(()=>setOpen(true));await frame();
  const dialog=document.querySelector('dialog');
  assert('dialog is native modal with input focus',dialog.matches(':modal')&&document.activeElement.tagName==='INPUT');
  assert('dialog enters 180ms',getComputedStyle(dialog).transitionDuration==='0.18s');
  flushSync(()=>setOpen(false));await frame();
  assert('dialog releases semantics and restores focus immediately',!dialog.open&&dialog.inert&&dialog.getAttribute('aria-hidden')==='true'&&document.activeElement===opener);
  assert('dialog exits 120ms',getComputedStyle(dialog).transitionDuration.split(',')[0]==='0.12s');
  await pause(160);
  assert('dialog removed after exit',!document.querySelector('dialog'));
  flushSync(()=>setOpen(true));await pause(40);flushSync(()=>setOpen(false));await frame();flushSync(()=>setOpen(true));await pause(160);
  assert('reopen cancels stale exit',document.querySelector('dialog')?.matches(':modal'));
  flushSync(()=>setOpen(false));await pause(160);
  assert('page relationship direction', pageMotionFor('/login','/register')==='peer-forward'&&pageMotionFor('/register','/login')==='peer-back'&&pageMotionFor('/docs','/docs/oidc')==='deeper'&&pageMotionFor('/docs/oidc','/docs')==='parent');
  document.getElementById('next-page').click();
  const observed=[];
  for(let i=0;i<24;i++){await frame();for(const a of document.getAnimations()){const t=a.effect.getTiming();if(a.animationName?.startsWith('epass-page-')) observed.push({name:a.animationName,duration:t.duration,delay:t.delay});}}
  assert('native page snapshot exits 80ms then enters 180ms',observed.some(a=>a.name==='epass-page-out'&&a.duration===80)&&observed.some(a=>a.name==='epass-page-in'&&a.duration===180&&a.delay===80),observed);
  assert('route focus and page update',document.querySelector('main').contains(document.activeElement)&&document.getElementById('route-name').textContent==='/register');
  const updates=[];
  changePage('/register','/login',()=>updates.push('stale'));
  changePage('/register','/forgot-password',()=>updates.push('latest'));
  await pause(350);
  assert('rapid route ignores stale callback',updates.length===1&&updates[0]==='latest',updates);
  setReport(JSON.stringify({passed:results.every(r=>r.pass),results},null,2));
 }
 return <main style={{padding:32,maxWidth:800}}><h1>Rosemary motion verification</h1><p id="route-name">{pathname}</p><Link id="next-page" to="/register">测试注册导航</Link><SelectionGroup label="test selection" value={selection}>{['A','B'].map((label,i)=><button key={label} aria-pressed={selection===i} onClick={()=>setSelection(i)}>{label}</button>)}</SelectionGroup><SelectionContent value={selection} index={selection} className="test-panel"><form><label>Current {selection}<input aria-label="Current"/></label></form></SelectionContent><RosemarySelect value={value} onChange={setValue} label="选择方式" options={[{value:'email',label:'邮箱'},{value:'phone',label:'手机'}]}/><button id="open" className="btn-secondary" onClick={()=>setOpen(true)}>打开弹窗</button><AnimatePresence>{open&&<Dialog key="test" title="测试弹窗" onClose={()=>setOpen(false)}><input aria-label="测试输入"/></Dialog>}</AnimatePresence><MotionToggle/><button className="btn-primary" onClick={run}>运行动效验收</button><pre role="status">{report}</pre></main>
}
createRoot(document.getElementById('root')).render(<MotionPreferences><MemoryRouter initialEntries={['/login']}><RouteEffects/><App/></MemoryRouter></MotionPreferences>);
