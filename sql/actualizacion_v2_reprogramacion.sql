-- MEDINOVA 2.0 · MIGRACIÓN ADITIVA (NO DESTRUCTIVA)
-- Ejecutar UNA VEZ en Supabase SQL Editor con rol propietario, DESPUÉS de verificar un respaldo.
-- No ejecutar limpieza.sql ni esquema.sql sobre la base existente.
-- El reemplazo de cita se hace en la MISMA transacción: si algo falla, TODO se revierte.

create or replace function public.reprogramar_cita(p_cita_id bigint, p_nueva_franja bigint)
returns bigint
language plpgsql security definer set search_path = ''
as $$
declare
  anterior public.appointments%rowtype;
  comienzo_anterior timestamptz;
  id_nuevo_horario bigint;
  id_nuevo_profesional bigint;
  id_nueva_cita bigint;
begin
  if public.mi_rol() <> 'paciente' then
    raise exception 'Solo los pacientes pueden reprogramar' using errcode='42501';
  end if;

  -- Bloqueo de la cita anterior para impedir cambios concurrentes de esa reserva.
  select * into anterior from public.appointments
  where id = p_cita_id for update;
  if not found or anterior.patient_id <> auth.uid() then
    raise exception 'No autorizado para esta cita' using errcode='42501';
  end if;
  if anterior.estado not in ('programada','confirmada') then
    raise exception 'No puedes reprogramar una cita finalizada o cancelada';
  end if;
  if p_nueva_franja = anterior.schedule_id then
    raise exception 'Selecciona un horario diferente';
  end if;

  select (s.fecha + s.hora_inicio) at time zone 'America/Bogota'
    into comienzo_anterior from public.schedules s
    where s.id = anterior.schedule_id;
  if comienzo_anterior < now() + interval '12 hours' then
    raise exception 'La reprogramación requiere al menos 12 horas de anticipación';
  end if;

  -- Bloqueo exclusivo/atómico de un cupo disponible, con validación de profesional.
  update public.schedules s set estado='reservada', updated_by=auth.uid()
  where s.id=p_nueva_franja and s.estado='disponible'
    and s.professional_id=anterior.professional_id
    and (s.fecha + s.hora_inicio) at time zone 'America/Bogota' > now()
    and exists (
      select 1 from public.professionals pr
      join public.profiles pp on pp.id=pr.profile_id
      join public.specialties sp on sp.id=pr.specialty_id
      where pr.id=s.professional_id and pr.activo and pp.activo and sp.activo
    )
  returning s.id,s.professional_id into id_nuevo_horario,id_nuevo_profesional;
  if id_nuevo_horario is null then
    raise exception 'La franja ya no está disponible';
  end if;

  -- El registro previo no se borra; sus transiciones quedan en status_history.
  update public.appointments
    set estado='cancelada', updated_by=auth.uid()
    where id=anterior.id;
  update public.schedules
    set estado='disponible', updated_by=auth.uid()
    where id=anterior.schedule_id;
  insert into public.appointments
    (patient_id, professional_id, schedule_id, motivo, created_by, updated_by)
  values
    (auth.uid(),id_nuevo_profesional,id_nuevo_horario,anterior.motivo,auth.uid(),auth.uid())
  returning id into id_nueva_cita;

  return id_nueva_cita;
end;
$$;

revoke all on function public.reprogramar_cita(bigint,bigint) from public,anon;
grant execute on function public.reprogramar_cita(bigint,bigint) to authenticated;
