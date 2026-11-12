import { api, db, mensajeError } from './api.js';
import { configurado } from './config.js';
import { h, $, campo, seleccionar, boton, vacio, cargando, notificar, fechaBonita, hora, titulo, tabla, celda, estado } from './ui.js';

const app=$('#app');
const rutas={
 paciente:[['inicio','Inicio'],['reservar','Reservar cita'],['mis-citas','Mis citas'],['perfil','Mi perfil']],
 profesional:[['inicio','Inicio'],['agenda','Mi agenda'],['perfil','Mi perfil']],
 admin:[['resumen','Resumen'],['especialidades','Especialidades'],['profesionales','Profesionales'],['horarios','Horarios'],['citas','Citas'],['usuarios','Usuarios'],['perfil','Mi perfil']]
};
const estadoApp={usuario:null,perfil:null,renderId:0};
const iconos={inicio:'⌂',reservar:'▦','mis-citas':'◷',agenda:'▤',resumen:'▥',especialidades:'✳',profesionales:'♙',horarios:'◫',citas:'▣',usuarios:'♧',perfil:'◉'};
const esFutura=c=>`${c.fecha}T${hora(c.hora_inicio)}`>=`${hoy()}T00:00`;
const citasOrdenadas=items=>[...items].sort((a,b)=>`${a.fecha} ${a.hora_inicio}`.localeCompare(`${b.fecha} ${b.hora_inicio}`));
const hoy=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Bogota',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const formData=form=>Object.fromEntries(new FormData(form));
const numero=v=>v===''||v===null?null:Number(v);
function enviar(form,fn){form.addEventListener('submit',async e=>{
 e.preventDefault();const btn=$('button[type="submit"]',form);if(btn){btn.disabled=true;btn.dataset.previous=btn.textContent;btn.textContent='Procesando…';}
 try{await fn(formData(form));}catch(err){notificar(mensajeError(err),'error');}finally{if(btn){btn.disabled=false;btn.textContent=btn.dataset.previous;}}
});return form;}
function botonSubmit(texto){return h('button',{type:'submit',class:'btn primaria',text:texto});}
function seccion(...child){return h('section',{class:'contenido'},...child);}
function card(...child){return h('article',{class:'panel'},...child);}
function linea(text,value){return h('div',{class:'detalle'},h('span',{text}),h('strong',{text:String(value??'—')}));}
function cargador(host){host.replaceChildren(cargando());}
async function load(host,cb){cargador(host);try{const result=await cb(); if(host.isConnected)host.replaceChildren(result);}catch(err){if(host.isConnected)host.replaceChildren(h('div',{class:'error-box',role:'alert'},h('strong',{text:'No pudimos cargar esta sección.'}),h('p',{text:mensajeError(err)}),boton('Volver a intentar',{onClick:()=>load(host,cb)})));}}
function navigate(route){location.hash='#/'+route;}
function navDefault(){return rutas[estadoApp.perfil?.rol]?.[0]?.[0]||'reservar';}
function authShell(children){app.replaceChildren(h('main',{id:'principal',class:'auth-layout'},h('section',{class:'auth-intro'},h('a',{href:'#/login',class:'marca'},h('span',{class:'marca-simbolo',text:'✚'}),' MediNova'),h('p',{class:'eyebrow',text:'TU SALUD, TU TIEMPO'}),h('h1',{text:'Tu bienestar comienza con una cita.'}),h('p',{text:'Agenda tus consultas, encuentra profesionales y mantén tus citas organizadas desde un solo lugar.'}),h('div',{class:'decor-ticket','aria-hidden':'true'},h('span',{text:'MEDINOVA · AGENDA DIGITAL'}),h('strong',{text:'Un espacio para cuidarte'}),h('span',{text:'ATENCIÓN · CONFIANZA · BIENESTAR'}))),h('section',{class:'auth-form'},children)));
}
function loginVista(modo='login'){
 const login=modo==='login',registro=modo==='registro';
 const form=h('form',{class:'formulario'},...(registro?[campo('Nombre completo','text','nombres',{required:true,maxlength:120,autocomplete:'name'})]:[]),
 campo('Correo electrónico','email','email',{required:true,autocomplete:'email'}),
 ...(modo==='recuperar'?[]:[campo('Contraseña','password','password',{
 required:true,...(registro?{minlength:8}:{}),autocomplete:registro?'new-password':'current-password'})]),
 botonSubmit(login?'Iniciar sesión':registro?'Crear cuenta':'Enviar instrucciones'));
 enviar(form,async d=>{
 if(registro){await api.registrar(d.email,d.password,d.nombres);notificar('Cuenta creada. Revisa tu correo si se requiere confirmación.');navigate('login');}
 else if(login){await api.entrar(d.email,d.password);const session=await api.sesion();if(session?.user)await actualizarSesion(session.user);}
 else{await api.recuperar(d.email);notificar('Si el correo está registrado, recibirás instrucciones para recuperar el acceso.');navigate('login');}
 });
 authShell(card(h('p',{class:'eyebrow',text:'BIENVENIDO A MEDINOVA'}),h('h2',{text:login?'Inicia sesión':registro?'Crea tu cuenta':'Recupera tu acceso'}),
 h('p',{class:'muted',text:login?'Tu agenda está lista para ti.':registro?'Todos los registros nuevos comienzan como pacientes.':'Te enviaremos un enlace a tu correo.'}),form,
 h('p',{class:'privacy-note',text:'Tus datos de acceso se gestionan mediante autenticación de Supabase.'}),h('div',{class:'auth-links'},h('a',{href:login?'#/registro':'#/login',text:login?'Crear cuenta':'Volver al inicio de sesión'}),
 ...(login?[h('a',{href:'#/recuperar',text:'Olvidé mi contraseña'})]:[]))));
}
function layout(route){
 const perfil=estadoApp.perfil;
 const items=rutas[perfil.rol];
 app.replaceChildren(h('div',{class:'layout'},h('aside',{class:'sidebar'},h('a',{href:'#/'+navDefault(),class:'marca'},h('span',{class:'marca-simbolo',text:'✚'}),' MediNova'),
 h('p',{class:'sidebar-label',text:perfil.rol==='admin'?'ADMINISTRACIÓN':perfil.rol==='profesional'?'EQUIPO MÉDICO':'ESPACIO PACIENTE'}),
 h('nav',{'aria-label':'Menú principal'},items.map(([path,label])=>h('a',{href:'#/'+path,class:'nav-link'+(path===route?' activo':''),...(path===route?{'aria-current':'page'}:{})},h('span',{class:'nav-icon','aria-hidden':'true',text:iconos[path]||'•'}),h('span',{text:label})))),
 h('div',{class:'sidebar-bottom'},h('span',{class:'avatar',text:(perfil.nombres||'U').slice(0,1).toUpperCase()}),h('div',{},h('strong',{text:perfil.nombres||'Usuario'}),h('small',{text:perfil.rol})),boton('Salir',{class:'btn salir',onClick:async()=>{try{await api.salir();estadoApp.usuario=null;estadoApp.perfil=null;navigate('login');render();}catch(err){notificar(mensajeError(err),'error');}}}))),
 h('div',{class:'main-wrapper'},h('header',{class:'topbar'},h('span',{text:'MediNova  /  Portal de atención'}),h('span',{class:'topbar-right',text:'●  Agenda en horario de Bogotá'})),h('main',{id:'principal',tabindex:'-1'},h('div',{id:'contenido-vista'})))));
 return $('#contenido-vista');
}
async function render(){const token=++estadoApp.renderId;
 if(!configurado){app.replaceChildren(h('main',{id:'principal',class:'config-error'},titulo('Falta conectar Supabase','Completa la URL y la clave publishable en assets/js/config.js.')));return;}
 if(!estadoApp.usuario){loginVista(location.hash==='#/registro'?'registro':location.hash==='#/recuperar'?'recuperar':'login');return;}
 if(!estadoApp.perfil){app.replaceChildren(h('main',{id:'principal'},cargando()));return;}
 if(!estadoApp.perfil.activo){app.replaceChildren(h('main',{id:'principal'},titulo('Cuenta desactivada','Consulta con la administración.')));return;}
 const role=estadoApp.perfil.rol;
 let route=location.hash.replace(/^#\//,'');
 if(!rutas[role]?.some(([name])=>name===route)){route=navDefault();history.replaceState(null,'','#/'+route);}
 const main=layout(route);if(token!==estadoApp.renderId)return;
 const views={inicio:vistaInicio,reservar:vistaReservar,'mis-citas':()=>vistaCitas(false),perfil:vistaPerfil,agenda:()=>vistaCitas(false),
 resumen:vistaResumen,especialidades:vistaEspecialidades,profesionales:vistaProfesionales,horarios:vistaHorarios,citas:()=>vistaCitas(true),usuarios:vistaUsuarios};
 await load(main,views[route]);
}
async function actualizarSesion(user){estadoApp.usuario=user;estadoApp.perfil=user?await api.perfil(user.id):null;
 if(user&& !estadoApp.perfil)throw new Error('No se encontró un perfil asociado a la cuenta.');
 await render();}
function sinDatos(items,mensaje){return items?.length?null:vacio(mensaje);}

async function vistaInicio(){
 const perfil=estadoApp.perfil;
 const citas=citasOrdenadas(await api.citas());
 const futuras=citas.filter(c=>esFutura(c)&&['programada','confirmada'].includes(c.estado));
 const terminadas=citas.filter(c=>['atendida','no_asistio'].includes(c.estado));
 const proxima=futuras[0];
 const saludo=(perfil.nombres||'').trim().split(/\s+/)[0]||'bienvenido';
 const stats=h('div',{class:'summary-grid'},
   h('article',{class:'summary-card'},h('span',{text:'Citas próximas'}),h('strong',{text:String(futuras.length)}),h('small',{text:'Por realizar'})),
   h('article',{class:'summary-card'},h('span',{text:'Citas registradas'}),h('strong',{text:String(citas.length)}),h('small',{text:'Historial total'})),
   h('article',{class:'summary-card'},h('span',{text:'Atenciones cerradas'}),h('strong',{text:String(terminadas.length)}),h('small',{text:'Atendidas o no asistidas'})));
 const resumen=proxima?card(h('div',{class:'section-overline',text:'PRÓXIMA CITA'}),
   h('div',{class:'cita-head'},h('h2',{text:perfil.rol==='paciente'?proxima.profesional:proxima.paciente}),estado(proxima.estado)),
   h('p',{class:'muted',text:proxima.especialidad}),
   h('div',{class:'data-chips'},h('span',{text:'◷  '+fechaBonita(proxima.fecha)}),h('span',{text:hora(proxima.hora_inicio)+' – '+hora(proxima.hora_fin)})),
   h('a',{class:'btn secundaria link-button',href:perfil.rol==='paciente'?'#/mis-citas':'#/agenda',text:'Ver mis citas →'})):
   card(h('div',{class:'section-overline',text:'TU AGENDA'}),h('h2',{text:'Sin citas próximas'}),
   h('p',{class:'muted',text:perfil.rol==='paciente'?'Explora la disponibilidad médica y reserva tu próxima consulta.':'Las próximas citas asignadas aparecerán aquí.'}),
   ...(perfil.rol==='paciente'?[h('a',{class:'btn primaria link-button',href:'#/reservar',text:'Explorar horarios →'})]:[]));
 return seccion(h('div',{class:'welcome-hero'},h('span',{class:'eyebrow',text:'TU ESPACIO PERSONAL'}),
   h('h1',{text:`Hola, ${saludo} 👋`}),h('p',{text:perfil.rol==='paciente'?'Organiza tus citas y dedica más tiempo a lo que importa: tu bienestar.':'Consulta tu agenda del día y mantén tu atención organizada.'}),
   ...(perfil.rol==='paciente'?[h('a',{class:'btn hero-action',href:'#/reservar',text:'＋  Reservar una cita'})]:[])),stats,resumen);
}
async function vistaReservar(){
 const [especialidades,profesionales]=await Promise.all([api.especialidades(),api.profesionales()]);
 const cont=h('div',{class:'slots-grid'});
 const contador=h('p',{class:'result-count',role:'status','aria-live':'polite'});
 const form=h('form',{class:'filtros'},seleccionar('Especialidad','especialidad',especialidades.filter(s=>s.activo).map(s=>({value:s.id,label:s.nombre})),'Todas las especialidades'),
 seleccionar('Profesional','profesional',profesionales.map(p=>({value:p.id,label:p.nombres})),'Todos los profesionales'),
 campo('Fecha','date','fecha',{min:hoy(),value:hoy()}),botonSubmit('Buscar horarios'));
 let filtros={p_especialidad:null,p_profesional:null,p_fecha:hoy()};
 const dibujar=async()=>{cargador(cont);try{
 const franjas=await api.disponibilidad(filtros);contador.textContent=`${franjas.length} horario${franjas.length===1?'':'s'} disponible${franjas.length===1?'':'s'}`;cont.replaceChildren(...(franjas.length?franjas.map(s=>h('article',{class:'ticket'},
 h('div',{class:'ticket-main'},h('span',{class:'eyebrow',text:s.especialidad}),h('strong',{text:s.nombres}),h('span',{text:fechaBonita(s.fecha)})),
 h('div',{class:'ticket-time'},h('strong',{text:`${hora(s.hora_inicio)} – ${hora(s.hora_fin)}`}),boton('Reservar',{class:'btn primaria',onClick:()=>confirmarReserva(s,dibujar)})))):[vacio('No hay franjas para estos filtros. Prueba otro día o especialidad.') ]));
 }catch(e){contador.textContent='';cont.replaceChildren(vacio(mensajeError(e)));}};
 enviar(form,async d=>{filtros={p_especialidad:numero(d.especialidad),p_profesional:numero(d.profesional),p_fecha:d.fecha||null};await dibujar();});
 const dateInput=$('input[name="fecha"]',form);dateInput.value=hoy();
 const espSelect=$('select[name="especialidad"]',form);
 espSelect.addEventListener('change',()=>{const id=numero(espSelect.value);const pSelect=$('select[name="profesional"]',form);pSelect.replaceChildren(h('option',{value:'',text:'Todos los profesionales'}),...profesionales.filter(p=>!id||p.especialidad_id===id).map(p=>h('option',{value:p.id,text:p.nombres})));});
 const accesos=h('div',{class:'quick-dates','aria-label':'Fechas rápidas'});
 [['Hoy',0],['Mañana',1],['En 7 días',7]].forEach(([label,offset])=>accesos.append(boton(label,{class:'btn quick-date',onClick:()=>{
   const valor=new Date(`${hoy()}T12:00:00`);valor.setDate(valor.getDate()+offset);
   const fecha=[valor.getFullYear(),String(valor.getMonth()+1).padStart(2,'0'),String(valor.getDate()).padStart(2,'0')].join('-');
   dateInput.value=fecha;filtros={p_especialidad:numero(espSelect.value),p_profesional:numero($('select[name="profesional"]',form).value),p_fecha:fecha};void dibujar();
 }})));
 void dibujar();
 return seccion(titulo('Reserva tu próxima cita','Elige especialidad, profesional y fecha. Solo mostramos horarios disponibles.'),card(h('div',{class:'form-intro'},h('h2',{text:'Encuentra el horario ideal'}),h('p',{class:'muted',text:'Selecciona tus preferencias para consultar los cupos.'})),form,h('p',{class:'quick-label',text:'Buscar por fecha rápida'}),accesos),h('div',{class:'section-row'},h('h2',{class:'section-title',text:'Horarios disponibles'}),contador),cont);
}
function confirmarReserva(s,actualizar){
 const dialog=h('dialog',{class:'dialogo'},h('div',{class:'dialog-inner'},h('p',{class:'eyebrow',text:'CONFIRMAR RESERVA'}),h('h2',{text:'¿Confirmamos tu cita?'}),
 linea('Profesional',s.nombres),linea('Día',fechaBonita(s.fecha)),linea('Horario',`${hora(s.hora_inicio)} a ${hora(s.hora_fin)}`),
 h('form',{},campo('Motivo breve (opcional)','text','motivo',{maxlength:250}),h('div',{class:'dialog-buttons'},boton('Volver',{onClick:()=>dialog.close()}),botonSubmit('Confirmar reserva')))));
 document.body.append(dialog);
 dialog.addEventListener('close',()=>dialog.remove());
 enviar($('form',dialog),async d=>{await api.reservar(s.id,d.motivo);dialog.close();notificar('Tu cita quedó programada.');await actualizar();});dialog.showModal();
}
async function dialogoReprogramar(c){
 const dialog=h('dialog',{class:'dialogo'},h('div',{class:'dialog-inner'},
   h('p',{class:'eyebrow',text:'CAMBIAR MI RESERVA'}),h('h2',{text:'Reprogramar cita'}),
   h('p',{class:'muted',text:'Conservaremos el historial de la cita anterior. Solo se realizará el cambio cuando el nuevo horario esté disponible.'}),
   h('div',{class:'loading',text:'Consultando horarios del profesional…'})));
 document.body.append(dialog);dialog.addEventListener('close',()=>dialog.remove());dialog.showModal();
 try{
   const franjas=(await api.disponibilidad({p_especialidad:null,p_profesional:c.professional_id,p_fecha:null}))
     .filter(s=>s.id!==c.schedule_id);
   const cuerpo=$('.dialog-inner',dialog);
   if(!franjas.length){cuerpo.append(vacio('No hay otros horarios disponibles para este profesional.'));
     cuerpo.append(boton('Cerrar',{onClick:()=>dialog.close()}));$('.loading',cuerpo).remove();return;}
   const opciones=franjas.map(s=>({value:s.id,label:`${fechaBonita(s.fecha)} · ${hora(s.hora_inicio)} – ${hora(s.hora_fin)}`}));
   const form=h('form',{class:'formulario'},seleccionar('Nuevo horario','nuevo_horario',opciones,'Selecciona una franja disponible'),
     h('div',{class:'dialog-buttons'},boton('Volver',{onClick:()=>dialog.close()}),botonSubmit('Confirmar reprogramación')));
   $('.loading',cuerpo).replaceWith(form);
   enviar(form,async datos=>{
     if(!datos.nuevo_horario)throw new Error('Selecciona el nuevo horario.');
     await api.reprogramar(c.id,Number(datos.nuevo_horario));dialog.close();
     notificar('Tu cita fue reprogramada. La anterior permanece en el historial.');await render();
   });
 }catch(err){if(dialog.isConnected){$('.loading',dialog)?.replaceWith(h('p',{class:'error-box',text:mensajeError(err)}));
   $('.dialog-inner',dialog)?.append(boton('Cerrar',{onClick:()=>dialog.close()}));}}
}
async function vistaCitas(esAdmin){
 const citas=citasOrdenadas(await api.citas());const rol=estadoApp.perfil.rol;
 const filtro=h('label',{class:'campo filtro-estado'},h('span',{text:'Filtrar por estado'}),h('select',{name:'estado'},h('option',{value:'',text:'Todos'}),['programada','confirmada','atendida','cancelada','no_asistio'].map(s=>h('option',{value:s,text:s.replaceAll('_',' ')}))));
 const buscar=campo('Buscar por nombre o especialidad','search','buscar-citas',{placeholder:'Ej. pediatría, Juan…',autocomplete:'off'});
 const listado=h('div',{class:'lista-citas'});
 const encontrados=h('p',{class:'result-count',role:'status','aria-live':'polite'});
 function actualizarVista(){const chosen=$('select',filtro).value;const consulta=String($('input',buscar).value||'').trim().toLocaleLowerCase('es');const visibles=citas.filter(c=>(!chosen||c.estado===chosen)&&(!consulta||[c.especialidad,c.profesional,c.paciente,c.estado].some(v=>String(v||'').toLocaleLowerCase('es').includes(consulta))));encontrados.textContent=`${visibles.length} cita${visibles.length===1?'':'s'} encontrada${visibles.length===1?'':'s'}`;
 listado.replaceChildren(...(visibles.length?visibles.map(c=>{
 const acciones=[];
 if(rol==='paciente'&&['programada','confirmada'].includes(c.estado)){
   acciones.push(boton('Reprogramar',{class:'btn secundaria',onClick:()=>void dialogoReprogramar(c)}));
   acciones.push(boton('Cancelar cita',{class:'btn secundaria',onClick:()=>cambiar(c,'cancelada')}));
 }
 if(rol!=='paciente'){
 const opciones=c.estado==='programada'?['confirmada','cancelada']:c.estado==='confirmada'?['atendida','no_asistio','cancelada']:[];
 acciones.push(...opciones.map(op=>boton(op.replaceAll('_',' '),{class:'btn secundaria',onClick:()=>cambiar(c,op)})));
 }
 return card(h('div',{class:'cita-head'},h('div',{},h('span',{class:'eyebrow',text:c.especialidad}),h('h3',{text:rol==='paciente'?c.profesional:c.paciente})),estado(c.estado)),
 h('div',{class:'cita-meta'},linea('Fecha',fechaBonita(c.fecha)),linea('Hora',`${hora(c.hora_inicio)} – ${hora(c.hora_fin)}`),...(esAdmin?[linea('Profesional',c.profesional)]:[]),...(c.motivo?[linea('Motivo',c.motivo)]:[])),
 h('div',{class:'acciones'},acciones));
 }):[vacio('No hay citas con este filtro.') ]));}
 async function cambiar(c,siguiente){if(!confirm(`¿Cambiar la cita a “${siguiente.replaceAll('_',' ')}”?`))return;
 try{await api.estado(c.id,siguiente);notificar('Estado actualizado correctamente.');await render();}catch(err){notificar(mensajeError(err),'error');}}
 $('select',filtro).addEventListener('change',actualizarVista);$('input',buscar).addEventListener('input',actualizarVista);actualizarVista();
 return seccion(titulo(rol==='profesional'?'Mi agenda':esAdmin?'Todas las citas':'Mis citas',rol==='profesional'?'Gestiona exclusivamente tus citas asignadas.':'Consulta el estado de las reservas y los movimientos permitidos.'),h('div',{class:'filter-toolbar'},filtro,buscar),encontrados,listado);
}
async function vistaPerfil(){
 const p=estadoApp.perfil;
 const form=h('form',{class:'formulario perfil-form'},campo('Nombres','text','nombres',{required:true,maxlength:120,value:p.nombres||''}),
 campo('Documento','text','documento',{maxlength:30,value:p.documento||''}),campo('Teléfono','tel','telefono',{maxlength:30,value:p.telefono||''}),
 campo('Fecha de nacimiento','date','fecha_nacimiento',{value:p.fecha_nacimiento||''}),botonSubmit('Guardar cambios'));
 enviar(form,async d=>{const actualizado=await api.guardarPerfil(p.id,{nombres:d.nombres,documento:d.documento||null,telefono:d.telefono||null,fecha_nacimiento:d.fecha_nacimiento||null});estadoApp.perfil={...p,...actualizado};notificar('Tus datos se actualizaron correctamente.');});
 return seccion(titulo('Mi perfil','Tu información básica, sin datos clínicos sensibles.'),card(h('span',{class:'eyebrow',text:'DATOS PERSONALES'}),h('p',{class:'muted',text:`Rol de acceso: ${p.rol}`}),form));
}
async function vistaResumen(){
 const resumen=await api.indicadores();
 const agrupar=(etiqueta,items)=>{const max=Math.max(1,...(items||[]).map(x=>Number(x.cantidad)||0));return card(h('h2',{text:etiqueta}),...(items?.length?items.map(x=>h('div',{class:'indicator-item'},h('div',{class:'indicador-linea'},h('span',{text:x.nombre.replaceAll('_',' ')}),h('strong',{text:String(x.cantidad)})),h('div',{class:'progress-track'},h('div',{class:'progress-fill',style:`width:${Math.min(100,Math.max(0,100*(Number(x.cantidad)||0)/max))}%`,'aria-hidden':'true'})))):[vacio('Aún no hay datos para mostrar.') ]));};
 return seccion(titulo('Visión general','Indicadores calculados con información actual de la base de datos.'),
 h('div',{class:'kpi'},h('p',{class:'eyebrow',text:'CITAS REGISTRADAS'}),h('strong',{text:String(resumen.total||0)}),h('span',{text:'Total histórico'})),
 h('div',{class:'dashboard-grid'},agrupar('Por estado',resumen.estados),agrupar('Por especialidad',resumen.especialidades),agrupar('Por periodo',resumen.periodos)));
}
async function vistaEspecialidades(){
 const items=await api.especialidades();
 const form=h('form',{class:'formulario inline-form'},campo('Nombre','text','nombre',{required:true,minlength:2,maxlength:100}),campo('Descripción','text','descripcion',{maxlength:200}),botonSubmit('Crear especialidad'));
 enviar(form,async d=>{await api.crearEspecialidad({nombre:d.nombre.trim(),descripcion:d.descripcion});notificar('Especialidad creada.');await render();});
 const rows=items.map(s=>h('tr',{},celda(s.nombre),celda(s.descripcion),celda(s.activo?'Activa':'Inactiva'),h('td',{},boton('Editar',{class:'btn mini',onClick:async()=>{
 const nombre=prompt('Nombre',s.nombre);if(nombre===null)return;const descripcion=prompt('Descripción',s.descripcion);if(descripcion===null)return;
 try{await api.editarEspecialidad(s.id,{nombre,descripcion});notificar('Especialidad actualizada.');await render();}catch(err){notificar(mensajeError(err),'error');}
 }}),boton(s.activo?'Desactivar':'Activar',{class:'btn mini secundaria',onClick:async()=>{
 try{await api.editarEspecialidad(s.id,{activo:!s.activo});notificar('Estado actualizado.');await render();}catch(err){notificar(mensajeError(err),'error');}
 }}))));
 return seccion(titulo('Especialidades','Administra las áreas de atención disponibles.'),card(h('h2',{text:'Nueva especialidad'}),form),card(h('h2',{text:'Catálogo'}),items.length?tabla(['Nombre','Descripción','Estado','Acciones'],rows):vacio('No se han creado especialidades.')));
}
async function vistaProfesionales(){
 const [usuarios,especialidades,profesionales]=await Promise.all([api.usuarios(),api.especialidades(),api.profesionalesAdmin()]);
 const posibles=usuarios.filter(u=>u.rol!=='admin');
 const form=h('form',{class:'formulario inline-form'},seleccionar('Usuario','profile',posibles.map(u=>({value:u.id,label:`${u.nombres} (${u.rol})`})),'Selecciona usuario'),
 seleccionar('Especialidad','especialidad',especialidades.map(s=>({value:s.id,label:s.nombre}))),
 campo('Registro profesional (opcional)','text','registro',{maxlength:80}),botonSubmit('Asignar profesional'));
 enviar(form,async d=>{if(!d.profile||!d.especialidad)throw Error('Selecciona usuario y especialidad.');
 await api.asignarProfesional({p_profile_id:d.profile,p_especialidad:Number(d.especialidad),p_registro:d.registro||null,p_activo:true});
 notificar('Profesional asignado.');await render();});
 return seccion(titulo('Profesionales','Vincula cuentas existentes con sus especialidades.'),card(h('h2',{text:'Asignar o cambiar especialidad'}),form),card(h('h2',{text:'Equipo médico'}),profesionales.length?
 tabla(['Profesional','Especialidad','Registro','Estado','Acción'],profesionales.map(p=>h('tr',{},celda(p.nombres),celda(p.especialidad),celda(p.registro_profesional),celda(p.activo?'Activo':'Inactivo'),h('td',{},boton(p.activo?'Desactivar':'Activar',{class:'btn mini',onClick:async()=>{
 try{await api.activarProfesional(p.id,!p.activo);notificar('Profesional actualizado.');await render();}catch(err){notificar(mensajeError(err),'error');}
 }}))))):vacio('No hay profesionales asignados.')));
}
async function vistaHorarios(){
 const [profesionales,horarios]=await Promise.all([api.profesionalesAdmin(),api.horariosAdmin()]);
 const form=h('form',{class:'formulario inline-form'},seleccionar('Profesional','profesional',profesionales.filter(p=>p.activo).map(p=>({value:p.id,label:p.nombres}))),
 campo('Fecha','date','fecha',{required:true,min:hoy(),value:hoy()}),campo('Desde','time','inicio',{required:true,value:'08:00'}),
 campo('Hasta','time','fin',{required:true,value:'12:00'}),seleccionar('Duración','minutos',[15,20,30,45,60].map(n=>({value:n,label:`${n} minutos`}))),botonSubmit('Generar franjas'));
 $('input[name="fecha"]',form).value=hoy();
 enviar(form,async d=>{if(!d.profesional||!d.minutos)throw Error('Selecciona profesional y duración.');
 await api.crearHorarios({p_profesional:Number(d.profesional),p_fecha:d.fecha,p_inicio:d.inicio,p_fin:d.fin,p_minutos:Number(d.minutos)});
 notificar('Franjas creadas (los duplicados se omiten).');await render();});
 return seccion(titulo('Horarios de atención','Cada franja corresponde a un único cupo.'),card(h('h2',{text:'Generar franjas'}),form),
 card(h('h2',{text:'Franjas registradas'}),horarios.length?tabla(['Profesional','Fecha','Hora','Estado','Acción'],horarios.map(s=>h('tr',{},celda(s.nombres),celda(fechaBonita(s.fecha)),celda(`${hora(s.hora_inicio)}–${hora(s.hora_fin)}`),h('td',{},estado(s.estado)),h('td',{},s.estado==='reservada'?h('small',{text:'Bloqueada por reserva'}):boton('Editar',{class:'btn mini',onClick:async()=>{
 const fecha=prompt('Fecha AAAA-MM-DD',s.fecha);if(fecha===null)return;
 const inicio=prompt('Inicio HH:MM',hora(s.hora_inicio));if(inicio===null)return;
 const fin=prompt('Fin HH:MM',hora(s.hora_fin));if(fin===null)return;
 try{await api.editarHorario({p_id:s.id,p_fecha:fecha,p_inicio:inicio,p_fin:fin,p_activo:s.estado==='disponible'});notificar('Horario editado.');await render();}catch(err){notificar(mensajeError(err),'error');}
 }}),s.estado==='reservada'?null:boton(s.estado==='inactiva'?'Activar':'Desactivar',{class:'btn mini secundaria',onClick:async()=>{
 try{await api.editarHorario({p_id:s.id,p_fecha:s.fecha,p_inicio:s.hora_inicio,p_fin:s.hora_fin,p_activo:s.estado==='inactiva'});notificar('Horario actualizado.');await render();}catch(err){notificar(mensajeError(err),'error');}
 }}))))):vacio('No existen franjas.')));
}
async function vistaUsuarios(){
 const usuarios=await api.usuarios();
 return seccion(titulo('Usuarios','Gestiona el acceso de pacientes, médicos y administradores.'),card(usuarios.length?tabla(['Nombre','Rol','Acceso','Acciones'],usuarios.map(u=>h('tr',{},celda(u.nombres),celda(u.rol),celda(u.activo?'Activo':'Inactivo'),h('td',{},u.id===estadoApp.usuario.id?'Tu cuenta':boton('Cambiar',{class:'btn mini',onClick:async()=>{
 const rol=prompt('Rol: paciente, profesional, admin',u.rol);if(rol===null)return;
 const activo=confirm('¿Mantener la cuenta activa? Aceptar = activa; Cancelar = inactiva.');
 try{await api.actualizarUsuario(u.id,rol,activo);notificar('Permisos actualizados.');await render();}catch(err){notificar(mensajeError(err),'error');}
 }}))))):vacio('Sin usuarios.')));
}

window.addEventListener('hashchange',()=>{void render();});
// Nunca ejecutar funciones Supabase ni retornar una promesa dentro del callback Auth.
db.auth.onAuthStateChange((event,session)=>{
 if(event==='SIGNED_IN'||event==='SIGNED_OUT'){
   setTimeout(()=>{
     if(event==='SIGNED_OUT'){estadoApp.usuario=null;estadoApp.perfil=null;void render();}
     else if(session?.user && (!estadoApp.usuario || session.user.id!==estadoApp.usuario.id)){
       void actualizarSesion(session.user).catch(e=>{notificar(mensajeError(e),'error');estadoApp.usuario=null;estadoApp.perfil=null;void render();});
     }
   },0);
 }
});
async function iniciar(){if(!configurado){await render();return;}
 try{const sesion=await api.sesion();if(sesion?.user){await actualizarSesion(sesion.user);}else{await render();}}
 catch(err){notificar(mensajeError(err),'error');estadoApp.usuario=null;estadoApp.perfil=null;await render();}
}
void iniciar();
