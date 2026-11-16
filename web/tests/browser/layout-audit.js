// Geometric checks supplement visual inspection; they do not grade aesthetics.
const rect = node => node.getBoundingClientRect();
const near = (a,b,tolerance=1) => Math.abs(a-b)<=tolerance;
const visible = node => node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden';
const glyph = node => { const range=document.createRange();range.selectNodeContents(node);return range.getClientRects()[0]; };
export function auditLayout() {
  const results=[],check=(name,pass,details)=>results.push({name,pass:Boolean(pass),details});
  const panel=document.querySelector('.epass-auth-panel');
  if(panel){
    const style=getComputedStyle(panel);
    check('responsive surface',innerWidth<=1023 ? style.backgroundColor==='rgba(0, 0, 0, 0)' && style.borderRadius==='0px' : parseFloat(style.paddingLeft)>=24);
    const gutter=innerWidth<=640?40:innerWidth<=1023?60:16;
    check('form viewport gutters',rect(panel).left>=gutter && rect(panel).right<=innerWidth-gutter);
    if(innerWidth<=1023){const tools=document.querySelector('.epass-auth-tools');if(tools)check('phone/tablet utilities share form edges',near(rect(tools).left,rect(panel).left)&&near(rect(tools).right,rect(panel).right));}
  }
  for(const [index,field] of [...document.querySelectorAll('.rm-field')].filter(visible).entries()) {
    const label=field.querySelector(':scope > label'),frame=field.querySelector('.rm-field-frame');
    if(label&&frame)check(`field ${index} label/frame left edge`,near(rect(label).left,rect(frame).left));
  }
  for(const [index,button] of [...document.querySelectorAll('.rm-icon-button')].filter(visible).entries()) {
    const b=rect(button),icon=button.querySelector('svg');
    check(`icon action ${index} target`,near(b.width,44)&&near(b.height,44),b.toJSON());
    if(icon){const i=rect(icon);check(`icon action ${index} optical centre`,near(i.left+i.width/2,b.left+b.width/2)&&near(i.top+i.height/2,b.top+b.height/2));}
  }
  for(const [index,eye] of [...document.querySelectorAll('.epass-password-visibility')].filter(visible).entries()) {
    const frame=eye.parentElement.querySelector('.rm-field-frame');
    check(`password eye ${index} frame centre`,frame&&near(rect(eye).top+rect(eye).height/2,rect(frame).top+rect(frame).height/2));
  }
  const legal=document.querySelector('.epass-legal-check');
  if(legal){
    const text=[...legal.querySelectorAll('a,span')].filter(n=>n.childNodes.length===1&&n.firstChild.nodeType===Node.TEXT_NODE);
    const boxes=text.map(glyph).filter(Boolean),line=parseFloat(getComputedStyle(legal).lineHeight);
    check('agreement uses one text baseline per line',boxes.every(b=>near((b.top-boxes[0].top)/line,Math.round((b.top-boxes[0].top)/line),.03)),boxes.map(b=>b.toJSON()));
    const mark=legal.querySelector('.rm-check-visual');
    check('checkbox aligns with the first line',mark&&near(rect(mark).top+10,rect(legal.querySelector('span:last-child')).top+12));
  }
  const remember=document.querySelector('.epass-auth-remember-row');
  if(remember){
    const label=remember.querySelector('label > span:last-child'),prompt=remember.querySelector('p'),link=prompt?.querySelector('a');
    if(label&&prompt&&link){
      const range=document.createRange();range.selectNodeContents(prompt.firstChild);const p=range.getClientRects()[0],l=glyph(link);
      check('register prose and link share a baseline',near(p.top,l.top)&&near(p.bottom,l.bottom));
      check('remember/register line metrics match',getComputedStyle(label).fontSize===getComputedStyle(prompt).fontSize&&getComputedStyle(label).lineHeight===getComputedStyle(prompt).lineHeight);
      if(near(rect(label).top,rect(prompt).top))check('remember and register share the row baseline',near(glyph(label).top,p.top));
    }
  }
  for(const dialog of document.querySelectorAll('dialog[open]:not(.epass-dialog-navigation)')){
    const d=rect(dialog),viewport=window.visualViewport;
    check('dialog gutters',d.left>=19.5&&d.right<=innerWidth-19.5&&d.top>=(viewport?.offsetTop??0)+23.5&&d.bottom<=(viewport?.offsetTop??0)+(viewport?.height??innerHeight)-23.5,d.toJSON());
    check('dialog restrained width',d.width<=520.5 && d.height<=Math.min(680,innerHeight*.84)+1);
    check('long dialog scrolls internally',getComputedStyle(dialog).overflowY==='auto'&&d.height<=innerHeight-47);
    const buttons=[...dialog.querySelectorAll(':scope > footer .rm-button')].map(rect);
    if(buttons.length>1)check('dialog actions have consistent height',buttons.every(b=>near(b.height,buttons[0].height)));
  }
  return {passed:results.every(x=>x.pass),viewport:{width:innerWidth,height:innerHeight},results};
}
export function wireLayoutAudit(){
  const host=document.createElement('aside');host.style='position:fixed;inset:auto auto 0 0;z-index:99;background:white;color:black;max-height:20px;max-width:460px;overflow:auto;font:11px/1.4 monospace';
  const button=document.createElement('button'),report=document.createElement('pre');button.textContent='运行视觉布局检查';report.id='layout-audit-report';
  button.onclick=async()=>{delete report.dataset.ready;await document.fonts.ready;await new Promise(resolve=>setTimeout(resolve,280));report.textContent=JSON.stringify(auditLayout(),null,2);report.dataset.ready='true';};host.append(button,report);document.body.append(host);
}
