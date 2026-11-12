-- MEDINOVA 2.1 · ESTADÍSTICAS ADMINISTRATIVAS Y CAMPANITA
-- Migración aditiva para el esquema existente. Ejecutar una vez en Supabase SQL Editor.
-- No elimina citas ni cambia los datos existentes. Nuevas notificaciones: eventos futuros, no retroactivos.
-- Ejecutar como propietario de las tablas (SQL Editor). Mantener el archivo como respaldo.

-- 1. Indicadores completos: toda la agregación se hace en PostgreSQL, con comprobación de rol.
create or replace function public.indicadores_v3(p_desde date default null, p_hasta date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
  if public.mi_rol() is distinct from 'admin' then
    raise exception 'Acceso denegado' using errcode='42501';
  end if;
  if p_desde is not null and p_hasta is not null and p_desde > p_hasta then
    raise exception 'Rango de fechas no válido';
  end if;
  with base as (
    select a.estado, s.fecha, sp.nombre especialidad, pp.nombres medico
    from public.appointments a
    join public.schedules s on s.id = a.schedule_id
    join public.professionals pr on pr.id = a.professional_id
    join public.profiles pp on pp.id = pr.profile_id
    join public.specialties sp on sp.id = pr.specialty_id
    where (p_desde is null or s.fecha >= p_desde)
      and (p_hasta is null or s.fecha <= p_hasta)
  ), agenda as (
    select count(*) filter (where s.estado = 'reservada')::int ocupadas,
           count(*)::int total
    from public.schedules s
    where s.estado in ('disponible','reservada')
      and (p_desde is null or s.fecha >= p_desde)
      and (p_hasta is null or s.fecha <= p_hasta)
  )
  select jsonb_build_object(
    'total', (select count(*) from base),
    'programadas', (select count(*) from base where estado='programada'),
    'confirmadas', (select count(*) from base where estado='confirmada'),
    'atendidas', (select count(*) from base where estado='atendida'),
    'canceladas', (select count(*) from base where estado='cancelada'),
    'no_asistio', (select count(*) from base where estado='no_asistio'),
    'ocupacion', (select coalesce(round(100.0 * ocupadas / nullif(total,0)),0) from agenda),
    'franjas_activas', (select total from agenda),
    'franjas_ocupadas', (select ocupadas from agenda),
    'especialidades',coalesce((select jsonb_agg(jsonb_build_object('nombre',nombre,'cantidad',cantidad) order by cantidad desc,nombre)
      from (select especialidad nombre,count(*) cantidad from base group by 1) x),'[]'::jsonb),
    'medicos',coalesce((select jsonb_agg(jsonb_build_object('nombre',nombre,'cantidad',cantidad) order by cantidad desc,nombre)
      from (select medico nombre,count(*) cantidad from base group by 1) x),'[]'::jsonb),
    'periodos',coalesce((select jsonb_agg(jsonb_build_object('nombre',nombre,'cantidad',cantidad) order by nombre)
      from (select to_char(fecha,'YYYY-MM') nombre,count(*) cantidad from base group by 1) x),'[]'::jsonb),
    'estados',coalesce((select jsonb_agg(jsonb_build_object('nombre',nombre,'cantidad',cantidad) order by cantidad desc,nombre)
      from (select estado nombre,count(*) cantidad from base group by 1) x),'[]'::jsonb)
  ) into resultado;
  return resultado;
end;
$$;
revoke all on function public.indicadores_v3(date,date) from public,anon;
grant execute on function public.indicadores_v3(date,date) to authenticated;

-- 2. Bandeja de notificaciones persistentes, visible únicamente para el destinatario.
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  appointment_id bigint references public.appointments(id) on delete set null,
  tipo text not null check (tipo in ('nueva_cita','cambio_estado')),
  titulo text not null check (char_length(titulo) between 1 and 120),
  mensaje text not null check (char_length(mensaje) between 1 and 500),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists notifications_recipient_recent_idx on public.notifications(recipient_id,created_at desc);
alter table public.notifications enable row level security;
revoke all on public.notifications from public,anon,authenticated;
revoke all on sequence public.notifications_id_seq from public,anon,authenticated;
grant select on public.notifications to authenticated;
grant update(read_at) on public.notifications to authenticated;

-- La función de rol valida también perfiles activos.
drop policy if exists notifications_read_self on public.notifications;
create policy notifications_read_self on public.notifications
  for select to authenticated using (recipient_id=auth.uid() and public.mi_rol() is not null);
drop policy if exists notifications_update_self on public.notifications;
create policy notifications_update_self on public.notifications
  for update to authenticated
  using (recipient_id=auth.uid() and public.mi_rol() is not null)
  with check (recipient_id=auth.uid() and public.mi_rol() is not null);
-- No se conceden INSERT/DELETE al cliente.

-- 3. Generación automática de avisos al crear una cita o cambiar su estado.
-- No incluye nombres, motivos ni información clínica en los mensajes.
create or replace function public.notificar_movimiento_cita()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  destinatario_medico uuid;
  fecha_hora text;
  titulo_aviso text;
  cuerpo text;
  clase text;
begin
  if TG_OP='UPDATE' and new.estado is not distinct from old.estado then
    return new;
  end if;
  select pr.profile_id, to_char(s.fecha,'DD/MM/YYYY')||' a las '||to_char(s.hora_inicio,'HH24:MI')
    into destinatario_medico, fecha_hora
  from public.professionals pr
  join public.schedules s on s.id=new.schedule_id
  where pr.id=new.professional_id;
  if TG_OP='INSERT' then
    clase:='nueva_cita';titulo_aviso:='Nueva cita programada';
    cuerpo:='Se registró una cita para el '||coalesce(fecha_hora,'horario indicado')||'.';
  else
    clase:='cambio_estado';titulo_aviso:='Cambio de estado de cita';
    cuerpo:='La cita del '||coalesce(fecha_hora,'horario indicado')||' ahora está '||replace(new.estado,'_',' ')||'.';
  end if;
  insert into public.notifications(recipient_id,appointment_id,tipo,titulo,mensaje)
    select destinatario,new.id,clase,titulo_aviso,cuerpo
    from (select new.patient_id as destinatario union select destinatario_medico) d
    where destinatario is not null;
  -- Administradores activos reciben aviso sin información identificable del paciente.
  insert into public.notifications(recipient_id,appointment_id,tipo,titulo,mensaje)
    select p.id,new.id,clase,titulo_aviso,cuerpo
    from public.profiles p where p.rol='admin' and p.activo
      and p.id not in (new.patient_id,coalesce(destinatario_medico,new.patient_id));
  return new;
end;
$$;
-- Se reemplaza exclusivamente el trigger de notificaciones de esta migración.
drop trigger if exists medinova_notifications_appointments on public.appointments;
create trigger medinova_notifications_appointments
  after insert or update of estado on public.appointments
  for each row execute function public.notificar_movimiento_cita();
revoke all on function public.notificar_movimiento_cita() from public,anon,authenticated;
