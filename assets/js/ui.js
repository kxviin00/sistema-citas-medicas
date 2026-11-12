export function h(tag, attrs={}, ...children) {
 const node=document.createElement(tag);
 for (const [key,value] of Object.entries(attrs || {})) {
   if (value === null || value === undefined || value === false) continue;
   if (key==='class') node.className=value;
   else if (key==='text') node.textContent=String(value);
   else if (key==='onClick') node.addEventListener('click',value);
   else if (key==='onSubmit') node.addEventListener('submit',value);
   else if (key==='onChange') node.addEventListener('change',value);
   else if (key==='value') node.value=value;
   else if (key==='checked') node.checked=Boolean(value);
   else node.setAttribute(key,String(value));
 }
 for (const child of children.flat(Infinity)) {
   if(child===null || child===undefined || child===false) continue;
   node.append(child instanceof Node ? child : document.createTextNode(String(child)));
 }
 return node;
}
export const $ = (selector,root=document) => root.querySelector(selector);
export function campo(label,type,name,attrs={}) {
 const id='campo-'+name;
 return h('label',{class:'campo',for:id},h('span',{text:label}),h('input',{id,type,name,...attrs}));
}
export function seleccionar(label,name,items,placeholder='Seleccionar') {
 const id='campo-'+name;
 return h('label',{class:'campo',for:id},h('span',{text:label}),h('select',{id,name},
 h('option',{value:'',text:placeholder}),items.map(item=>h('option',{value:item.value,text:item.label}))));
}
export function boton(text,options={}) { return h('button',{type:'button',class:'btn',...options},text); }
export function vacio(mensaje) { return h('div',{class:'empty',role:'status'},h('span',{class:'empty-icon','aria-hidden':'true',text:'✦'}),h('p',{text:mensaje})); }
export function cargando() { return h('div',{class:'loading',role:'status','aria-live':'polite'},h('span',{class:'spinner','aria-hidden':'true'}),'Cargando información…'); }
export function notificar(texto,tipo='exito') {
 const region=$('#avisos'); if(!region) return;
 region.replaceChildren(h('div',{class:`aviso ${tipo}`,role:tipo==='error'?'alert':'status'},h('span',{text:texto}),boton('×',{class:'cerrar', 'aria-label':'Cerrar aviso',onClick:()=>region.replaceChildren()})));
}
export function fechaBonita(fecha) {
 if(!fecha)return '—';
 return new Date(`${fecha}T12:00:00`).toLocaleDateString('es-CO',{day:'numeric',month:'long',year:'numeric'});
}
export function hora(hora) { return String(hora || '').slice(0,5); }
export function titulo(texto,subtitulo='') { return h('header',{class:'page-head'},h('p',{class:'eyebrow',text:'CUIDAMOS TU TIEMPO'}),h('h1',{text:texto}),h('p',{class:'subtitle',text:subtitulo})); }
export function tabla(columnas,filas) {
 const table=h('table',{},h('thead',{},h('tr',{},columnas.map(c=>h('th',{scope:'col',text:c})))),h('tbody',{},filas));
 return h('div',{class:'tabla-scroll',tabindex:'0',role:'region','aria-label':'Tabla con desplazamiento'},table);
}
export function celda(texto) { return h('td',{text:String(texto ?? '—')}); }
export function estado(texto) { return h('span',{class:'pill estado-'+texto,text:String(texto).replaceAll('_',' ')}); }
