-- OPCIONAL Y DESTRUCTIVO: elimina datos del MVP y funciones; NO elimina auth.users.
-- Ejecutar SOLO si necesitas reinstalar desde cero, antes de esquema.sql.
-- Los usuarios Auth permanecen, por lo que datos_prueba.sql reconstituye sus perfiles.
drop trigger if exists auth_user_created on auth.users;
drop function if exists public.auth_new_user() cascade;
drop function if exists public.mi_rol() cascade;
drop function if exists public.listar_profesionales(bigint) cascade;
drop function if exists public.buscar_disponibilidad(bigint,bigint,date) cascade;
drop function if exists public.reservar_cita(bigint,text) cascade;
drop function if exists public.cambiar_estado_cita(bigint,text) cascade;
drop function if exists public.listar_citas() cascade;
drop function if exists public.indicadores(date,date) cascade;
drop function if exists public.admin_asignar_profesional(uuid,bigint,text,boolean) cascade;
drop function if exists public.admin_crear_horarios(bigint,date,time,time,integer) cascade;
drop function if exists public.admin_listar_usuarios() cascade;
drop function if exists public.admin_listar_profesionales() cascade;
drop function if exists public.admin_listar_horarios() cascade;
drop function if exists public.admin_editar_horario(bigint,date,time,time,boolean) cascade;
drop function if exists public.admin_activar_profesional(bigint,boolean) cascade;
drop function if exists public.admin_actualizar_usuario(uuid,text,boolean) cascade;
drop table if exists public.status_history cascade;
drop table if exists public.appointments cascade;
drop table if exists public.schedules cascade;
drop table if exists public.professionals cascade;
drop table if exists public.specialties cascade;
drop table if exists public.profiles cascade;
drop function if exists public.audit_record() cascade;
drop function if exists public.profile_guard() cascade;
drop function if exists public.guard_schedule() cascade;
drop function if exists public.appointment_transition() cascade;
drop function if exists public.appointment_history() cascade;
