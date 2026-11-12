# MediNova 2.1 — Estadísticas + campanita

Esta entrega parte del ZIP **MediNova 2.0**. Conserva el sistema de pacientes, médicos, administradores y las funciones actuales de reservas y reprogramación.

## Cambios

- **Administrador / Estadísticas:** tarjetas de citas totales, programadas, confirmadas, atendidas, canceladas y ocupación de franjas; gráficos por especialidad, profesional, mes y estado; rango de fechas, acceso rápido a últimos 30 días, y **Exportar CSV**.
- **Campanita:** persistencia en tabla `public.notifications`, contador de no leídas, listado con fechas, botón individual de lectura y botón para marcar todas. Se refresca al abrirla, al navegar y cada 60 segundos con la pestaña visible.
- **Eventos:** al crear una reserva o cambiar el estado de una cita, se envía un aviso al paciente, al profesional y a los administradores activos. Una reprogramación genera aviso de cancelación y de nueva reserva. No se envían correos, SMS ni WhatsApp.
- **Seguridad:** estadísticas por función SQL con validación administrativa; RLS por destinatario para notificaciones, sin `INSERT`/`DELETE` desde el navegador. Los avisos no incluyen nombre, correo, motivo ni datos clínicos del paciente.

## Orden de instalación recomendado

1. Conservar un respaldo del ZIP original y de los datos/esquema de Supabase.
2. En **Supabase → SQL Editor**, ejecutar **solo** `sql/actualizacion_v3_estadisticas_notificaciones.sql` como propietario. No ejecutar `esquema.sql`, `limpieza.sql`, `datos_prueba.sql` ni de nuevo `actualizacion_v2_reprogramacion.sql`.
3. Comprobar en Table Editor que existe `notifications` y que hay una función `indicadores_v3`.
4. Probar el frontend desde un servidor local, por ejemplo `python -m http.server 5500` en la carpeta raíz. Usar cuenta de administrador para ver estadísticas.
5. En una cuenta de paciente de prueba, crear/cambiar una reserva de prueba, y revisar la campanita de paciente, médico y administrador (recargar/abrir la campanita si hace falta). Los eventos anteriores a instalar la migración **no aparecen retroactivamente**.
6. Publicar los archivos mediante una rama y Pull Request a `main` en GitHub Pages, verificando antes que no haya secretos ni exportaciones de datos médicos. En GitHub puede ser más cómodo utilizar Git local para subir las carpetas con rutas correctas.

## Métricas — definiciones

- Las cifras se filtran según la **fecha de la cita** (`schedules.fecha`), no por fecha de creación del registro.
- **Citas registradas** incluye las canceladas y las reprogramadas (registros históricos).
- **Ocupación de franjas activas** = franjas con estado `reservada` / franjas con estado `reservada` o `disponible`. No es la tasa de asistencia ni la ocupación física en tiempo real.
- Las notificaciones **no envían correos** y los avisos de citas anteriores a la instalación no se generan de forma retroactiva.
- El panel es visible solamente para administradores autenticados. No existe información ficticia: sus números provienen de Supabase.

## Comprobaciones antes de publicar

- Paciente: inicio de sesión, reserva, campanita, marcar leído y reprogramación.
- Médico: agenda y campanita de citas asignadas.
- Administrador: gráficos con y sin rango de fechas, exportación CSV, avisos y lectura.
- Verificar en Supabase que una notificación para usuario A no sea visible ni editable por usuario B.

**No se han ejecutado las migraciones en la base de datos del usuario desde este entorno.** Es necesario probarlas con su Supabase antes de desplegar a producción.
