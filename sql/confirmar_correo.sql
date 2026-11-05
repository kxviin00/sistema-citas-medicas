-- OPCIONAL, EJECUCIÓN PRIVILEGIADA EN SQL EDITOR.
-- Sustituye exclusivamente un correo de DEMOSTRACIÓN previamente creado.
-- No ejecutes esto con un email de otra persona.
update auth.users
set email_confirmed_at=coalesce(email_confirmed_at,now()),
    updated_at=now()
where email='paciente.demo@example.com' and email_confirmed_at is null;
-- Para otra cuenta demo, sustituye el correo por el suyo. Preferir Auto Confirm al crear usuario.
