import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './config.js';
// Librería oficial cargada como ESM remoto, sin framework ni build.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
export const db = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { storage: sessionStorage, persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
});
const revisar = ({ data, error }) => { if (error) throw error; return data; };
export const api = {
  sesion: async () => revisar(await db.auth.getSession()).session,
  entrar: async (email, password) => revisar(await db.auth.signInWithPassword({ email, password })),
  registrar: async (email, password, nombres) => revisar(await db.auth.signUp({ email, password, options: { data: { nombres } } })),
  salir: async () => revisar(await db.auth.signOut({ scope: 'local' })),
  recuperar: async (email) => revisar(await db.auth.resetPasswordForEmail(email)),
  perfil: async (id) => revisar(await db.from('profiles').select('id,nombres,documento,telefono,fecha_nacimiento,rol,activo').eq('id', id).single()),
  guardarPerfil: async (id, cambios) => revisar(await db.from('profiles').update(changesSafe(changes)).eq('id',id).select().single()),
  especialidades: async () => revisar(await db.from('specialties').select('id,nombre,descripcion,activo').order('nombre')),
  crearEspecialidad: async (obj) => revisar(await db.from('specialties').insert(obj).select().single()),
  editarEspecialidad: async (id,obj) => revisar(await db.from('specialties').update(obj).eq('id',id).select().single()),
  profesionales: async (p_especialidad=null) => revisar(await db.rpc('listar_profesionales',{p_especialidad})),
  disponibilidad: async ({p_especialidad=null,p_profesional=null,p_fecha=null}) => revisar(await db.rpc('buscar_disponibilidad',{p_especialidad,p_profesional,p_fecha})),
  reservar: async (p_schedule_id,p_motivo) => revisar(await db.rpc('reservar_cita',{p_schedule_id,p_motivo})),
  reprogramar: async (p_cita_id,p_nueva_franja) => revisar(await db.rpc('reprogramar_cita',{p_cita_id,p_nueva_franja})),
  citas: async () => revisar(await db.rpc('listar_citas')),
  estado: async (p_cita_id,p_estado) => revisar(await db.rpc('cambiar_estado_cita',{p_cita_id,p_estado})),
  indicadores: async (p_desde=null,p_hasta=null) => revisar(await db.rpc('indicadores',{p_desde,p_hasta})),
  estadisticasV3: async (p_desde=null,p_hasta=null) => revisar(await db.rpc('indicadores_v3',{p_desde,p_hasta})),
  notificaciones: async () => revisar(await db.from('notifications').select('id,titulo,mensaje,tipo,appointment_id,created_at,read_at').order('created_at',{ascending:false}).limit(40)),
  marcarNotificacion: async id => revisar(await db.from('notifications').update({read_at:new Date().toISOString()}).eq('id',id).is('read_at',null)),
  marcarNotificaciones: async () => revisar(await db.from('notifications').update({read_at:new Date().toISOString()}).is('read_at',null)),
  crearHorarios: async (args) => revisar(await db.rpc('admin_crear_horarios',args)),
  asignarProfesional: async (args) => revisar(await db.rpc('admin_asignar_profesional',args)),
  usuarios: async () => revisar(await db.rpc('admin_listar_usuarios')),
  profesionalesAdmin: async () => revisar(await db.rpc('admin_listar_profesionales')),
  horariosAdmin: async () => revisar(await db.rpc('admin_listar_horarios')),
  editarHorario: async (args) => revisar(await db.rpc('admin_editar_horario',args)),
  activarProfesional: async (p_id,p_activo) => revisar(await db.rpc('admin_activar_profesional',{p_id,p_activo})),
  actualizarUsuario: async (p_id,p_rol,p_activo) => revisar(await db.rpc('admin_actualizar_usuario',{p_id,p_rol,p_activo}))
};
function changesSafe(obj) { return Object.fromEntries(['nombres','documento','telefono','fecha_nacimiento'].filter(k=>Object.hasOwn(obj,k)).map(k=>[k,obj[k]])); }
export function mensajeError(error) {
 const msg=String(error?.message || error || 'Error desconocido');
 if (/Email not confirmed/i.test(msg)) return 'Confirma tu correo electrónico antes de iniciar sesión.';
 if (/Invalid login credentials/i.test(msg)) return 'Correo o contraseña incorrectos.';
 if (/User already registered/i.test(msg)) return 'Este correo ya está registrado.';
 if (/Password should be at least/i.test(msg)) return 'La contraseña debe tener mínimo 8 caracteres.';
 if (/already registered|already exists|duplicate key/i.test(msg)) return 'Ese registro ya existe.';
 if (/franja ya no está disponible|unique constraint|appointments_schedule_ocupada/i.test(msg)) return 'Ese horario acaba de ocuparse. Elige otro.';
 if (/reprogramaci[oó]n|No puedes reprogramar/i.test(msg)) return msg;
 if (/12 horas/i.test(msg)) return 'Solo puedes cancelar con al menos 12 horas de anticipación.';
 if (/agenda ajena|acceso denegado|no autorizado|permission denied|row-level security/i.test(msg)) return 'No tienes permisos para realizar esta acción.';
 if (/transición de estado/i.test(msg)) return 'No puedes realizar ese cambio de estado.';
 if (/todavía no ha iniciado/i.test(msg)) return 'Debes esperar a que comience la cita.';
 if (/Failed to fetch|NetworkError/i.test(msg)) return 'No hay conexión con el servidor. Inténtalo nuevamente.';
 return msg;
}
