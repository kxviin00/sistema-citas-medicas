# MediNova — MVP de reserva de citas médicas

Sistema de agenda médica ambulatoria ficticia para el Proyecto Integrador de Análisis y Diseño de Software. Frontend SPA en HTML5, CSS3 y JavaScript nativo (ES modules), base de datos PostgreSQL/Supabase Auth/RLS y despliegue estático en GitHub Pages.

**Autor:** Kevin Talero Ortega
**Docente:** Ing. Mg. José Javier Zapata Polo  
**URL publicada:** Configurar en GitHub → Settings → Pages (enlace sujeto a publicación)  
**Repositorio:** https://github.com/kxviin00/sistema-citas-medicas

## Funciones del MVP

- Paciente: crear cuenta, iniciar sesión, recuperar contraseña, buscar cupos, reservar, ver citas, cancelar hasta 12 horas antes, editar perfil.
- Profesional: consultar únicamente su agenda, confirmar y cerrar citas como atendidas/no asistió cuando hayan comenzado, cancelar bajo transiciones autorizadas.
- Administrador: indicadores por estado/especialidad/mes, gestionar especialidades, asignar profesionales, cambiar activación, crear/editar/desactivar horarios sin reserva, consultar y gestionar citas, gestionar roles y estado de usuarios.
- PostgreSQL: reserva mediante actualización atómica de franja y restricción única parcial, exclusión de solapamientos, validación de estados, registros de auditoría e historial, protección RLS.

## Configuración paso a paso

1. Crear un proyecto nuevo en [Supabase](https://supabase.com/dashboard). Abrir **SQL Editor**, pegar **todo** `sql/esquema.sql` y ejecutar. Después pegar **todo** `sql/politicas_rls.sql` y ejecutar. Estos scripts están diseñados para ejecutarse completos **una vez y en ese orden**; no reejecutar esquema si ya existen tablas.
2. En Supabase > **Authentication > Users > Add user**, crear cuatro cuentas con la opción **Auto Confirm** habilitada:

   | Cuenta de demostración | Rol después de ejecutar los datos |
   | --- | --- |
   | `admin.demo@example.com` | Administrador |
   | `medico1.demo@example.com` | Profesional (Medicina general) |
   | `medico2.demo@example.com` | Profesional (Pediatría) |
   | `paciente.demo@example.com` | Paciente |

   **Contraseñas de demostración:** [PENDIENTE: crear contraseñas distintas de 8+ caracteres en Supabase, registrarlas por un canal seguro para el docente; no guardarlas en GitHub]. Los correos `example.com` no reciben mensajes reales; Auto Confirm es esencial para estas cuentas. El login admite contraseñas existentes sin exigir longitud mínima.
3. Pegar **todo** `sql/datos_prueba.sql` y ejecutar. Puede repetirse; si las cuentas no existen, crea solo las especialidades. Para reinstalación destructiva usar primero `sql/limpieza.sql` (borra información del MVP pero NO usuarios de Auth) y repetir los pasos 1 a 3. Si se requiere una confirmación manual excepcional, consultar `sql/confirmar_correo.sql`.
4. En `assets/js/config.js`, remplazar `https://TU-PROYECTO.supabase.co` con la **Project URL** y `sb_publishable_REEMPLAZAR` con la **publishable key** (`sb_publishable_...`) que se obtiene en Supabase > Project Settings > API Keys. **Nunca** colocar clave `secret`, `service_role`, contraseña de BD o JWT secreto en archivos web.
5. Crear repositorio GitHub **sin** generar README ni .gitignore automáticos. Cargar el **contenido de la carpeta** (no el ZIP). El archivo `index.html` debe quedar en la raíz. Activar GitHub > Settings > Pages > Deploy from a branch > `main` / `/(root)`. Abrir la URL publicada.
6. Probar en pestañas independientes, cada una con una cuenta diferente; cada pestaña tiene su propia sesión (`sessionStorage`). Para cerrar se usa `signOut({ scope: 'local' })`. Documentar capturas de pruebas por rol.

### Despliegue y red

La página requiere internet para cargar la librería pública de Supabase desde jsDelivr y las tipografías desde Google Fonts. No necesita `npm`, compilación ni servidor Node.js; para desarrollo local se recomienda un servidor estático sencillo (por ejemplo `python -m http.server 8080`) porque los módulos ES no funcionan correctamente abriendo `index.html` con `file://`.

### Seguridad

- No existen políticas INSERT, UPDATE ni DELETE directas para `appointments`. Cualquier escritura ocurre por funciones RPC `SECURITY DEFINER` con `search_path = ''` y permisos comprobados contra `public.profiles`.
- `profiles` asigna siempre el rol inicial `paciente` desde trigger sobre `auth.users`. Una comprobación en base de datos impide cambiar roles o `activo` sin permisos de administrador. El bootstrap del admin demo se realiza únicamente desde SQL Editor privilegiado.
- Franjas unipersonales; al cancelar, la cita permanece en `cancelada` y la franja se marca `disponible`. Se conservan las citas canceladas históricas y sus transiciones. Índice único parcial asegura una única cita NO cancelada por franja.
- Las fechas y los horarios se interpretan con `America/Bogota`; los timestamps de auditoría se almacenan como `timestamptz`.
- No se utilizan datos de historia clínica, diagnósticos, pruebas médicas ni datos reales. El campo motivo debe mantenerse genérico en las demostraciones.
- La marca `publishable` está diseñada para ser visible en el navegador; la protección efectiva depende de los permisos, políticas y funciones de la base de datos, no de la ocultación de botones.
- `created_by`, `updated_by`, `created_at` y `updated_at` auditan las entidades mutables; `status_history` registra cambios de estado, actor y tiempo. El esquema restringe los borrados en relaciones y la app no ofrece eliminación destructiva.

### Restricciones del MVP y pendientes del taller

- No se han suministrado los nombres de integrantes, el enlace de GitHub Pages, el repositorio ni las contraseñas de las cuatro cuentas: son campos **pendientes** que se completan durante el despliegue, sin publicar contraseñas en GitHub.
- No se ha desplegado ni conectado a un proyecto real de Supabase, por lo que **no se afirma que se hayan ejecutado las consultas SQL, pruebas de concurrencia o pruebas E2E en infraestructura real**. Es indispensable ejecutar y verificar en el proyecto de destino, incluyendo RLS y dos sesiones reservando simultáneamente.
- La administración de pacientes se limita a listado, activación y roles; no incluye búsqueda avanzada, exportaciones ni eliminación. Edición de especialidad y horario se realiza mediante diálogos nativos sencillos.
- La reasignación de especialidad a un profesional existente no migra las citas históricas; las consultas históricas presentan la especialidad actual del profesional. Evitar reasignar profesionales con citas existentes o ampliar el modelo de datos en una siguiente versión.
- No incluye notificaciones SMS/email transaccionales de reservas, historias clínicas, pagos, multi-sede, festivos, gestión de múltiples consultorios ni programación recurrente de excepciones.
- La **Fase 2 documental**, solicitada solo bajo nueva instrucción, sigue pendiente: investigación comparativa, descripción del problema, objetivos, AS IS/TO BE, 15 RF, 8 RNF, ocho casos de uso detallados, diagramas, diccionario de datos, matriz de trazabilidad, quince casos de prueba ejecutados con evidencias, bibliografía y bitácora de IA. El taller también requiere commits significativos por integrante y sustentación.

## Archivos

```text
index.html
assets/css/styles.css
assets/js/config.js
assets/js/api.js
assets/js/ui.js
assets/js/app.js
sql/esquema.sql
sql/politicas_rls.sql
sql/datos_prueba.sql
sql/limpieza.sql            (mantenimiento opcional, destructivo)
sql/confirmar_correo.sql    (mantenimiento opcional)
README.md
.gitignore
```

## Checklist para validar tras desplegar

1. Registro nuevo queda con rol `paciente`, aunque se envíe `rol=admin` en metadatos.
2. Admin ve indicadores y asigna cuentas médicas; paciente no ve los paneles admin.
3. Paciente reserva un cupo, desaparece del buscador y aparece en Mis citas.
4. Dos pacientes simultáneos intentan la misma franja: solo uno tiene éxito.
5. Paciente no puede ver ni actualizar cita de otro usuario modificando IDs; médico tampoco puede modificar la agenda ajena.
6. La cancelación con más de 12 horas conserva el registro y libera el cupo; con menos de 12 horas se rechaza al paciente.
7. `atendida` y `no_asistio` están bloqueados antes de la hora de inicio, incluso usando RPC directamente.
8. La pantalla a 360 px no desborda horizontalmente y se puede usar con teclado.
9. Al recargar una pestaña con sesión, no aparece pantalla blanca.
10. Supabase RLS está activo para las seis tablas y no hay secretos en el repositorio.

## Apoyo de IA

Se utilizó asistencia de IA para elaborar el código y el texto inicial del MVP. **Pendiente**: registrar prompts, decisiones, revisiones, fuentes y resultados verificables en la bitácora de la Fase 2. Los autores del proyecto deben comprobar y explicar cada parte durante la sustentación.
