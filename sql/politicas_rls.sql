-- 2/3. Ejecutar después de esquema.sql. La autoridad es public.profiles, nunca JWT metadata.
-- MATRIZ rol/recurso/operación (S=SELECT, I=INSERT, U=UPDATE, D=DELETE; RPC=función controlada)
-- paciente: profiles S/U propio; specialties S activos; professionals/schedules lectura por RPC;
--           appointments lectura RPC, I/U mediante RPC, D nunca; status_history nunca.
-- profesional: profiles S propio; specialties S activos; agenda y citas propias por RPC;
--              cambiar estados por RPC; sin I/U/D directos de citas.
-- admin: profiles S todos/U rol-activo; specialties S/I/U; professionals S/I/U por RPC;
--        schedules S/I/U por RPC; appointments S/U por RPC; history S por RPC.
-- Ningún rol autenticado puede DELETE; anon no accede a tablas ni RPC.

alter table public.profiles enable row level security;
alter table public.specialties enable row level security;
alter table public.professionals enable row level security;
alter table public.schedules enable row level security;
alter table public.appointments enable row level security;
alter table public.status_history enable row level security;

create function public.mi_rol() returns text language sql stable security definer set search_path = '' as $$
 select p.rol from public.profiles p where p.id=auth.uid() and p.activo=true limit 1
$$;
revoke all on function public.mi_rol() from public,anon;
grant execute on function public.mi_rol() to authenticated;

create policy profiles_read on public.profiles for select to authenticated
 using (id=auth.uid() or public.mi_rol()='admin');
create policy profiles_update on public.profiles for update to authenticated
 using (id=auth.uid() or public.mi_rol()='admin')
 with check (id=auth.uid() or public.mi_rol()='admin');
create policy specialties_read on public.specialties for select to authenticated
 using (activo or public.mi_rol()='admin');
create policy specialties_admin_insert on public.specialties for insert to authenticated
 with check (public.mi_rol()='admin');
create policy specialties_admin_update on public.specialties for update to authenticated
 using (public.mi_rol()='admin') with check (public.mi_rol()='admin');
-- professionals, schedules, appointments, status_history: NO policies client write/read.
-- Todos los accesos controlados se realizan mediante RPC; funciones validan cada actor.

revoke all on all tables in schema public from public,anon,authenticated;
revoke all on all sequences in schema public from public,anon,authenticated;
grant usage on schema public to authenticated;
grant select on public.profiles,public.specialties to authenticated;
grant update(nombres,documento,telefono,fecha_nacimiento,rol,activo) on public.profiles to authenticated;
grant insert(nombre,descripcion,activo) on public.specialties to authenticated;
grant update(nombre,descripcion,activo) on public.specialties to authenticated;
-- Evita asignación masiva: trigger valida rol/activo aun mediante UPDATE SQL directo.
-- La función RPC de administración usa una comprobación adicional antes de cambiar roles.

create function public.listar_profesionales(p_especialidad bigint default null)
returns table(id bigint,nombres text,especialidad_id bigint,especialidad text,registro_profesional text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if public.mi_rol() is null then raise exception 'Acceso denegado' using errcode='42501'; end if;
 return query select pr.id, p.nombres,sp.id,sp.nombre,pr.registro_profesional
 from public.professionals pr join public.profiles p on p.id=pr.profile_id
 join public.specialties sp on sp.id=pr.specialty_id
 where pr.activo and p.activo and sp.activo and (p_especialidad is null or sp.id=p_especialidad)
 order by p.nombres;
end $$;

create function public.buscar_disponibilidad(p_especialidad bigint default null,p_profesional bigint default null,p_fecha date default null)
returns table(id bigint,professional_id bigint,nombres text,especialidad text,fecha date,hora_inicio time,hora_fin time)
language plpgsql stable security definer set search_path = '' as $$
begin
 if public.mi_rol() is null then raise exception 'Acceso denegado' using errcode='42501'; end if;
 return query select s.id,pr.id,p.nombres,sp.nombre,s.fecha,s.hora_inicio,s.hora_fin
 from public.schedules s join public.professionals pr on pr.id=s.professional_id
 join public.profiles p on p.id=pr.profile_id join public.specialties sp on sp.id=pr.specialty_id
 where s.estado='disponible' and pr.activo and p.activo and sp.activo
 and (s.fecha+s.hora_inicio) at time zone 'America/Bogota'>now()
 and (p_especialidad is null or sp.id=p_especialidad)
 and (p_profesional is null or pr.id=p_profesional)
 and (p_fecha is null or s.fecha=p_fecha)
 order by s.fecha,s.hora_inicio limit 200;
end $$;

create function public.reservar_cita(p_schedule_id bigint,p_motivo text default '') returns bigint
language plpgsql security definer set search_path = '' as $$
declare sid bigint; pid bigint; booked_id bigint;
begin
 if public.mi_rol()<>'paciente' then raise exception 'Solo los pacientes pueden reservar' using errcode='42501'; end if;
 if length(coalesce(p_motivo,''))>250 then raise exception 'Motivo demasiado extenso'; end if;
 -- UPDATE atómico y bloqueo de fila; a lo sumo una sesión pasa de disponible a reservada.
 update public.schedules s set estado='reservada'
 where s.id=p_schedule_id and s.estado='disponible'
 and (s.fecha+s.hora_inicio) at time zone 'America/Bogota'>now()
 and exists(select 1 from public.professionals pr join public.profiles pp on pp.id=pr.profile_id
            join public.specialties sp on sp.id=pr.specialty_id
            where pr.id=s.professional_id and pr.activo and pp.activo and sp.activo)
 returning s.id,s.professional_id into sid,pid;
 if sid is null then raise exception 'La franja ya no está disponible'; end if;
 insert into public.appointments(patient_id,professional_id,schedule_id,motivo,created_by,updated_by)
 values(auth.uid(),pid,sid,coalesce(p_motivo,''),auth.uid(),auth.uid()) returning id into booked_id;
 return booked_id;
end $$;

create function public.cambiar_estado_cita(p_cita_id bigint,p_estado text) returns void
language plpgsql security definer set search_path = '' as $$
declare a public.appointments%rowtype; actor text; inicio timestamptz;
begin
 actor:=public.mi_rol();
 select * into a from public.appointments where id=p_cita_id for update;
 if not found then raise exception 'Cita no encontrada'; end if;
 select (s.fecha+s.hora_inicio) at time zone 'America/Bogota' into inicio
 from public.schedules s where s.id=a.schedule_id;
 if actor='paciente' then
   if a.patient_id<>auth.uid() or p_estado<>'cancelada' then
      raise exception 'No autorizado para esta cita' using errcode='42501'; end if;
   if inicio<now()+interval '12 hours' then raise exception 'Cancelación requiere 12 horas de anticipación'; end if;
 elsif actor='profesional' then
   if not exists(select 1 from public.professionals pr where pr.id=a.professional_id and pr.profile_id=auth.uid() and pr.activo) then
     raise exception 'Agenda ajena' using errcode='42501'; end if;
 elsif actor<>'admin' then raise exception 'Acceso denegado' using errcode='42501';
 end if;
 update public.appointments set estado=p_estado,updated_by=auth.uid() where id=a.id;
 if p_estado='cancelada' then
    update public.schedules set estado='disponible',updated_by=auth.uid() where id=a.schedule_id;
 end if;
end $$;

create function public.listar_citas()
returns table(id bigint,patient_id uuid,paciente text,professional_id bigint,profesional text,especialidad text,
 schedule_id bigint,fecha date,hora_inicio time,hora_fin time,estado text,motivo text,observaciones_administrativas text)
language plpgsql stable security definer set search_path = '' as $$
declare actor text;
begin
 actor:=public.mi_rol(); if actor is null then raise exception 'Acceso denegado' using errcode='42501'; end if;
 return query select a.id,a.patient_id,pa.nombres,a.professional_id,pp.nombres,sp.nombre,
 a.schedule_id,s.fecha,s.hora_inicio,s.hora_fin,a.estado,a.motivo,a.observaciones_administrativas
 from public.appointments a join public.profiles pa on pa.id=a.patient_id
 join public.professionals pr on pr.id=a.professional_id
 join public.profiles pp on pp.id=pr.profile_id
 join public.specialties sp on sp.id=pr.specialty_id join public.schedules s on s.id=a.schedule_id
 where (actor='admin' or (actor='paciente' and a.patient_id=auth.uid())
 or (actor='profesional' and pr.profile_id=auth.uid()))
 order by s.fecha desc,s.hora_inicio desc limit 500;
end $$;

create function public.indicadores(p_desde date default null,p_hasta date default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 select jsonb_build_object(
  'total',count(*),
  'estados',coalesce((select jsonb_agg(jsonb_build_object('nombre',e.estado,'cantidad',e.cantidad)) from
    (select a2.estado,count(*) cantidad from public.appointments a2 join public.schedules s2 on s2.id=a2.schedule_id
      where (p_desde is null or s2.fecha>=p_desde) and (p_hasta is null or s2.fecha<=p_hasta) group by a2.estado) e),'[]'::jsonb),
  'especialidades',coalesce((select jsonb_agg(jsonb_build_object('nombre',e.nombre,'cantidad',e.cantidad)) from
    (select sp.nombre,count(*) cantidad from public.appointments a2 join public.schedules s2 on s2.id=a2.schedule_id
      join public.professionals pr on pr.id=a2.professional_id join public.specialties sp on sp.id=pr.specialty_id
      where (p_desde is null or s2.fecha>=p_desde) and (p_hasta is null or s2.fecha<=p_hasta) group by sp.nombre) e),'[]'::jsonb),
  'periodos',coalesce((select jsonb_agg(jsonb_build_object('nombre',e.periodo,'cantidad',e.cantidad)) from
    (select to_char(s2.fecha,'YYYY-MM') periodo,count(*) cantidad from public.appointments a2 join public.schedules s2 on s2.id=a2.schedule_id
      where (p_desde is null or s2.fecha>=p_desde) and (p_hasta is null or s2.fecha<=p_hasta)
      group by to_char(s2.fecha,'YYYY-MM') order by 1) e),'[]'::jsonb)) into resultado
 from public.appointments a join public.schedules s on s.id=a.schedule_id
 where (p_desde is null or s.fecha>=p_desde) and (p_hasta is null or s.fecha<=p_hasta);
 return resultado;
end $$;

create function public.admin_asignar_profesional(p_profile_id uuid,p_especialidad bigint,p_registro text default null,p_activo boolean default true)
returns bigint language plpgsql security definer set search_path = '' as $$
declare prof_id bigint;
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 if p_profile_id=auth.uid() then raise exception 'No se puede reasignar el propio rol'; end if;
 if not exists(select 1 from public.specialties where id=p_especialidad) then raise exception 'Especialidad inexistente'; end if;
 if not exists(select 1 from public.profiles where id=p_profile_id) then raise exception 'Usuario no encontrado'; end if;
 update public.profiles set rol='profesional',updated_by=auth.uid() where id=p_profile_id;
 insert into public.professionals(profile_id,specialty_id,registro_profesional,activo,created_by,updated_by)
 values(p_profile_id,p_especialidad,p_registro,p_activo,auth.uid(),auth.uid())
 on conflict(profile_id) do update set specialty_id=excluded.specialty_id,
 registro_profesional=excluded.registro_profesional,activo=excluded.activo,updated_by=auth.uid()
 returning id into prof_id;
 return prof_id;
end $$;

create function public.admin_crear_horarios(p_profesional bigint,p_fecha date,p_inicio time,p_fin time,p_minutos integer default 30)
returns integer language plpgsql security definer set search_path = '' as $$
declare actual time; siguiente time; n integer:=0;
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 if p_minutos not in (15,20,30,45,60) or p_fin<=p_inicio or p_fecha<(current_timestamp at time zone 'America/Bogota')::date then
   raise exception 'Fecha, intervalo o duración inválidos'; end if;
 if not exists(select 1 from public.professionals where id=p_profesional and activo) then raise exception 'Profesional no disponible'; end if;
 actual:=p_inicio;
 while (actual + make_interval(mins=>p_minutos))::time<=p_fin loop
   siguiente:=(actual + make_interval(mins=>p_minutos))::time;
   insert into public.schedules(professional_id,fecha,hora_inicio,hora_fin,created_by,updated_by)
   values(p_profesional,p_fecha,actual,siguiente,auth.uid(),auth.uid())
   on conflict(professional_id,fecha,hora_inicio,hora_fin) do nothing;
   n:=n+1; actual:=siguiente;
 end loop;
 return n;
end $$;

-- Funciones administrativas adicionales para mantener edición de horarios/profesionales bajo validación de rol.
create function public.admin_listar_usuarios() returns table(id uuid,nombres text,rol text,activo boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 return query select p.id,p.nombres,p.rol,p.activo from public.profiles p order by p.nombres;
end $$;
create function public.admin_listar_profesionales() returns table(id bigint,profile_id uuid,nombres text,specialty_id bigint,especialidad text,registro_profesional text,activo boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 return query select pr.id,pr.profile_id,p.nombres,pr.specialty_id,sp.nombre,pr.registro_profesional,pr.activo
 from public.professionals pr join public.profiles p on p.id=pr.profile_id join public.specialties sp on sp.id=pr.specialty_id order by p.nombres;
end $$;
create function public.admin_listar_horarios() returns table(id bigint,professional_id bigint,nombres text,fecha date,hora_inicio time,hora_fin time,estado text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 return query select s.id,s.professional_id,p.nombres,s.fecha,s.hora_inicio,s.hora_fin,s.estado
 from public.schedules s join public.professionals pr on pr.id=s.professional_id
 join public.profiles p on p.id=pr.profile_id order by s.fecha desc,s.hora_inicio desc limit 400;
end $$;
create function public.admin_editar_horario(p_id bigint,p_fecha date,p_inicio time,p_fin time,p_activo boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 if p_fin<=p_inicio then raise exception 'Intervalo inválido'; end if;
 update public.schedules set fecha=p_fecha,hora_inicio=p_inicio,hora_fin=p_fin,
 estado=case when p_activo then 'disponible' else 'inactiva' end,updated_by=auth.uid()
 where id=p_id and estado<>'reservada';
 if not found then raise exception 'Horario inexistente o reservado'; end if;
end $$;
create function public.admin_activar_profesional(p_id bigint,p_activo boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 update public.professionals set activo=p_activo,updated_by=auth.uid() where id=p_id;
 if not found then raise exception 'Profesional inexistente'; end if;
end $$;
create function public.admin_actualizar_usuario(p_id uuid,p_rol text,p_activo boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if public.mi_rol()<>'admin' then raise exception 'Acceso denegado' using errcode='42501'; end if;
 if p_id=auth.uid() then raise exception 'No puedes cambiar tu propio acceso'; end if;
 if p_rol not in ('paciente','profesional','admin') then raise exception 'Rol inválido'; end if;
 if p_rol='profesional' and not exists(select 1 from public.professionals where profile_id=p_id) then
   raise exception 'Primero debe asignarse el profesional a una especialidad'; end if;
 update public.profiles set rol=p_rol,activo=p_activo,updated_by=auth.uid() where id=p_id;
 if not found then raise exception 'Usuario inexistente'; end if;
end $$;

revoke execute on all functions in schema public from public,anon;
grant execute on function public.mi_rol() to authenticated;
grant execute on function public.listar_profesionales(bigint),public.buscar_disponibilidad(bigint,bigint,date),
public.reservar_cita(bigint,text),public.cambiar_estado_cita(bigint,text),public.listar_citas(),
public.indicadores(date,date),public.admin_asignar_profesional(uuid,bigint,text,boolean),
public.admin_crear_horarios(bigint,date,time,time,integer),public.admin_listar_usuarios(),
public.admin_listar_profesionales(),public.admin_listar_horarios(),public.admin_editar_horario(bigint,date,time,time,boolean),
public.admin_activar_profesional(bigint,boolean),public.admin_actualizar_usuario(uuid,text,boolean) to authenticated;
-- Nota: funciones trigger tampoco ejecutables directamente por authenticated.
