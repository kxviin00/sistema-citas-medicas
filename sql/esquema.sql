-- 1/3. Ejecutar una vez en SQL Editor. Zona horaria de aplicación: America/Bogota.
-- Para reinstalar NO ejecutar de nuevo este archivo: utilizar primero la limpieza del README.
create extension if not exists btree_gist with schema extensions;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete restrict,
 nombres text not null default '', documento text unique, telefono text,
 fecha_nacimiento date, rol text not null default 'paciente' check (rol in ('paciente','profesional','admin')),
 activo boolean not null default true, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
 constraint nombres_longitud check (length(nombres)<=120), constraint documento_longitud check (documento is null or length(documento)<=30)
);
create table public.specialties (
 id bigint generated always as identity primary key, nombre text not null unique, descripcion text not null default '',
 activo boolean not null default true, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
 check (length(trim(nombre)) between 2 and 100)
);
create table public.professionals (
 id bigint generated always as identity primary key,
 profile_id uuid not null unique references public.profiles(id) on delete restrict,
 specialty_id bigint not null references public.specialties(id) on delete restrict,
 registro_profesional text, activo boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id), updated_by uuid references auth.users(id)
);
create table public.schedules (
 id bigint generated always as identity primary key,
 professional_id bigint not null references public.professionals(id) on delete restrict,
 fecha date not null, hora_inicio time not null, hora_fin time not null,
 estado text not null default 'disponible' check (estado in ('disponible','reservada','inactiva')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
 unique (professional_id,fecha,hora_inicio,hora_fin), check (hora_fin>hora_inicio),
 exclude using gist (professional_id with =, tsrange((fecha + hora_inicio),(fecha + hora_fin),'[)') with &&)
);
create table public.appointments (
 id bigint generated always as identity primary key,
 patient_id uuid not null references public.profiles(id) on delete restrict,
 professional_id bigint not null references public.professionals(id) on delete restrict,
 schedule_id bigint not null references public.schedules(id) on delete restrict,
 motivo text not null default '', observaciones_administrativas text not null default '',
 estado text not null default 'programada' check (estado in ('programada','confirmada','atendida','cancelada','no_asistio')),
 cancelled_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
 check (length(motivo)<=250), check (length(observaciones_administrativas)<=500),
 check ((estado='cancelada')=(cancelled_at is not null))
);
create unique index appointments_schedule_ocupada_idx on public.appointments(schedule_id) where estado <> 'cancelada';
create table public.status_history (
 id bigint generated always as identity primary key,
 appointment_id bigint not null references public.appointments(id) on delete restrict,
 estado_anterior text, estado_nuevo text not null, changed_by uuid references auth.users(id),
 changed_at timestamptz not null default now(),
 check (estado_anterior is null or estado_anterior in ('programada','confirmada','atendida','cancelada','no_asistio')),
 check (estado_nuevo in ('programada','confirmada','atendida','cancelada','no_asistio'))
);
create index professionals_specialty_idx on public.professionals(specialty_id);
create index schedules_fecha_estado_idx on public.schedules(fecha,estado,professional_id);
create index appointments_patient_idx on public.appointments(patient_id,created_at desc);
create index appointments_professional_idx on public.appointments(professional_id,created_at desc);
create index history_appointment_idx on public.status_history(appointment_id,changed_at);

create function public.auth_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,nombres,rol,activo,created_by,updated_by)
 values (new.id, left(coalesce(new.raw_user_meta_data->>'nombres',''),120),'paciente',true,new.id,new.id);
 return new;
end $$;
create trigger auth_user_created after insert on auth.users for each row execute function public.auth_new_user();

create function public.audit_record() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if TG_OP='INSERT' then
   if new.created_by is null then new.created_by := auth.uid(); end if;
 else
   new.created_at := old.created_at;
   new.created_by := old.created_by;
 end if;
 new.updated_at:=now(); new.updated_by:=coalesce(auth.uid(),new.updated_by);
 return new;
end $$;
create trigger audit_profiles before insert or update on public.profiles for each row execute function public.audit_record();
create trigger audit_specialties before insert or update on public.specialties for each row execute function public.audit_record();
create trigger audit_professionals before insert or update on public.professionals for each row execute function public.audit_record();
create trigger audit_schedules before insert or update on public.schedules for each row execute function public.audit_record();
create trigger audit_appointments before insert or update on public.appointments for each row execute function public.audit_record();

create function public.profile_guard() returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_role text;
begin
 if TG_OP='INSERT' then
   -- Ni el cliente ni los metadatos pueden designar roles privilegiados al registrarse.
   new.rol:='paciente'; new.activo:=true;
 else
   if new.rol is distinct from old.rol or new.activo is distinct from old.activo then
     select rol into actor_role from public.profiles where id=auth.uid() and activo;
     if actor_role is distinct from 'admin' then
       raise exception 'Solo un administrador puede cambiar rol o activo' using errcode='42501';
     end if;
   end if;
 end if;
 return new;
end $$;
create trigger guard_profiles before insert or update on public.profiles for each row execute function public.profile_guard();

create function public.guard_schedule() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if TG_OP='DELETE' then
  if old.estado='reservada' or exists (select 1 from public.appointments a where a.schedule_id=old.id and a.estado<>'cancelada') then
   raise exception 'No se puede eliminar una franja reservada'; end if;
  return old;
 end if;
 if (old.estado='reservada' or exists (select 1 from public.appointments a where a.schedule_id=old.id and a.estado<>'cancelada'))
    and (new.professional_id,new.fecha,new.hora_inicio,new.hora_fin) is distinct from
        (old.professional_id,old.fecha,old.hora_inicio,old.hora_fin) then
   raise exception 'No se puede mover una franja reservada';
 end if;
 return new;
end $$;
create trigger guard_schedules before update or delete on public.schedules for each row execute function public.guard_schedule();

create function public.appointment_transition() returns trigger language plpgsql security definer set search_path = '' as $$
declare starts_at timestamptz;
begin
 if TG_OP='INSERT' then
   if new.estado <> 'programada' then raise exception 'Una cita inicia programada'; end if;
   if new.cancelled_at is not null then raise exception 'Cancelación inválida'; end if;
   select (s.fecha+s.hora_inicio) at time zone 'America/Bogota' into starts_at
     from public.schedules s where s.id=new.schedule_id;
   if starts_at<=now() then raise exception 'No es posible reservar en el pasado'; end if;
   if not exists(select 1 from public.schedules s where s.id=new.schedule_id and s.professional_id=new.professional_id) then
     raise exception 'Profesional y franja no coinciden'; end if;
 else
   if (new.patient_id,new.professional_id,new.schedule_id) is distinct from (old.patient_id,old.professional_id,old.schedule_id) then
     raise exception 'No se puede reasignar una cita'; end if;
   if new.estado is distinct from old.estado then
     if not ((old.estado='programada' and new.estado in ('confirmada','cancelada'))
          or (old.estado='confirmada' and new.estado in ('atendida','no_asistio','cancelada'))) then
       raise exception 'Transición de estado no permitida';
     end if;
     select (s.fecha+s.hora_inicio) at time zone 'America/Bogota' into starts_at
       from public.schedules s where s.id=new.schedule_id;
     if new.estado in ('atendida','no_asistio') and now()<starts_at then
       raise exception 'La cita todavía no ha iniciado'; end if;
     if new.estado='cancelada' then new.cancelled_at:=now(); else new.cancelled_at:=null; end if;
   end if;
 end if;
 return new;
end $$;
create trigger appointment_transitions before insert or update on public.appointments for each row execute function public.appointment_transition();

create function public.appointment_history() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if TG_OP='INSERT' or new.estado is distinct from old.estado then
   insert into public.status_history(appointment_id,estado_anterior,estado_nuevo,changed_by)
   values (new.id,case when TG_OP='INSERT' then null else old.estado end,new.estado,auth.uid());
 end if;
 return new;
end $$;
create trigger appointment_history after insert or update on public.appointments for each row execute function public.appointment_history();
