-- 3/3. Repetible: crea catálogos ficticios y, si existen cuentas demo, les asigna roles y horarios.
-- Crear antes en Authentication > Users con Auto Confirm:
-- admin.demo@example.com, medico1.demo@example.com, medico2.demo@example.com, paciente.demo@example.com
-- No agrega credenciales ni usuarios auth. Nunca usar datos clínicos reales.
insert into public.specialties(nombre,descripcion) values
 ('Medicina general','Atención ambulatoria general'),
 ('Pediatría','Consulta ambulatoria pediátrica'),
 ('Dermatología','Consulta dermatológica')
on conflict(nombre) do update set descripcion=excluded.descripcion,activo=true;

do $$
declare a uuid; m1 uuid; m2 uuid; pa uuid; esp1 bigint; esp2 bigint; pr1 bigint; pr2 bigint; dia date; i integer;
begin
 select id into a from auth.users where email='admin.demo@example.com';
 select id into m1 from auth.users where email='medico1.demo@example.com';
 select id into m2 from auth.users where email='medico2.demo@example.com';
 select id into pa from auth.users where email='paciente.demo@example.com';
 insert into public.profiles(id,nombres) select id,coalesce(raw_user_meta_data->>'nombres','Demo') from auth.users
 where email in ('admin.demo@example.com','medico1.demo@example.com','medico2.demo@example.com','paciente.demo@example.com')
 on conflict(id) do nothing;
 -- Se deshabilita temporalmente SOLO durante la migración privilegiada SQL Editor.
 -- La protección vuelve a estar activa antes de finalizar la transacción.
 execute 'alter table public.profiles disable trigger guard_profiles';
 if a is not null then update public.profiles set nombres='Alicia Administradora',rol='admin',activo=true where id=a; end if;
 if m1 is not null then update public.profiles set nombres='María Ficticia',rol='profesional',activo=true where id=m1; end if;
 if m2 is not null then update public.profiles set nombres='Carlos Ejemplo',rol='profesional',activo=true where id=m2; end if;
 if pa is not null then update public.profiles set nombres='Patricia Demo',rol='paciente',activo=true where id=pa; end if;
 execute 'alter table public.profiles enable trigger guard_profiles';
 select id into esp1 from public.specialties where nombre='Medicina general';
 select id into esp2 from public.specialties where nombre='Pediatría';
 if m1 is not null then
  insert into public.professionals(profile_id,specialty_id,registro_profesional) values(m1,esp1,'DEMO-001')
  on conflict(profile_id) do update set specialty_id=excluded.specialty_id,activo=true
  returning id into pr1;
 end if;
 if m2 is not null then
  insert into public.professionals(profile_id,specialty_id,registro_profesional) values(m2,esp2,'DEMO-002')
  on conflict(profile_id) do update set specialty_id=excluded.specialty_id,activo=true
  returning id into pr2;
 end if;
 for i in 1..10 loop
  dia := (now() at time zone 'America/Bogota')::date+i;
  if pr1 is not null then
   insert into public.schedules(professional_id,fecha,hora_inicio,hora_fin) values
    (pr1,dia,'08:00','08:30'),(pr1,dia,'08:30','09:00'),(pr1,dia,'09:00','09:30'),(pr1,dia,'09:30','10:00')
    on conflict(professional_id,fecha,hora_inicio,hora_fin) do nothing;
  end if;
  if pr2 is not null then
   insert into public.schedules(professional_id,fecha,hora_inicio,hora_fin) values
    (pr2,dia,'14:00','14:30'),(pr2,dia,'14:30','15:00'),(pr2,dia,'15:00','15:30')
    on conflict(professional_id,fecha,hora_inicio,hora_fin) do nothing;
  end if;
 end loop;
end $$;
