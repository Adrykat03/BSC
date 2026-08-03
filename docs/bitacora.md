# Bitácora de avance

Registro cronológico de trabajos, decisiones y fixes relevantes. Orden: más reciente arriba.

---

## 2026-08-03 — Alertas: columnas congeladas + fix de layout global + bugs en cadena

### Qué se hizo

**1. Total del día en el tooltip de "Alertas vs Tiempo".**
- Al pasar el cursor sobre un segmento de Reportería/Con novedad/Sin novedad, `beforeBody` del tooltip de Chart.js muestra primero el total de alertas de ese tramo (día/semana/mes, según agrupamiento activo) antes de la línea del segmento y del hint de descarga. Error Proceso queda sin ese total (no se pidió).

**2. Columnas congeladas en la tabla del Listado de Alertas.**
- Acciones, Fecha, Estado, Prioridad, Categoría y Asunto quedan fijas a la izquierda al hacer scroll horizontal; el resto (Descripción, Notificados, Fecha Resolución, Usuario Resolución, Notas Resolución, Origen) se desplaza por debajo. Anchos fijos con offsets `left` acumulados (100/150/130/120/170/flexible), borde de separación tras Asunto.

### Bug real (el importante): `.layout__main` sin `min-width: 0`

- **Síntoma:** las columnas "congeladas" no se quedaban fijas — se movían con el resto del scroll, como si `position: sticky` no existiera.
- **Diagnóstico:** en vez de asumir por CSS, se instaló Playwright (el proyecto ya tenía `playwright/screenshot.js` pero sin `node_modules`) y se hizo login real contra la app local para medir. Resultado: `.payroll-sticky-table` (el contenedor con `overflow:auto`) tenía `scrollWidth === clientWidth` — es decir, **no tenía overflow real**, nada que scrollear dentro de sí mismo. Subiendo la medición por la cadena de ancestros: `.layout__main` (flex child de `.layout`, junto al sidebar) medía 2250px de ancho en un viewport de 1400px — el layout entero se había estirado.
- **Causa raíz:** `.layout__main { flex: 1; ... }` sin `min-width: 0`. Comportamiento por defecto de flexbox: un flex item con contenido ancho adentro (nuestra tabla, con columnas de ancho fijo más rígido que antes) **no se deja achicar** por debajo de su contenido a menos que se le declare `min-width: 0` explícito — entonces en vez de que la tabla scrollee internamente, es TODA la página la que crece para acomodarlo. Bug preexistente (afecta cualquier página con contenido ancho), nunca antes visible porque ninguna tabla había llegado a este ancho mínimo.
- **Fix:** una línea en `frontend/src/styles/components.css` → `.layout__main { min-width: 0; }`.
- **Lección:** cuando un contenedor con `overflow:auto` "no scrollea" pese a tener contenido más ancho que su caja, medir `scrollWidth` vs `clientWidth` del contenedor ANTES de sospechar de `position:sticky` o de los anchos de columna — si son iguales, el problema está más arriba en la cadena de layout (casi siempre un flex/grid item sin `min-width:0`), no en el elemento que "no se pega".

### Bugs secundarios (aparecieron al arreglar el bug real, todos verificados con Playwright antes de darlos por resueltos)

1. **Fondo semi-transparente en columnas congeladas de filas críticas.** Las alertas urgentes (prioridad Alta + Con novedad, resaltadas en rojo) usan `background-color: rgba(239,68,68,0.1)` en el `<td>`. Esa regla le ganaba en especificidad CSS a mi fondo opaco pensado para las columnas congeladas, así que el contenido de las columnas no congeladas se veía "flotando" (doble texto) al pasar por debajo durante el scroll. Fix: overrides específicos con el equivalente **opaco** del mismo tinte (`--color-error-bg` = `#FEE2E2`; `#FCDDDD` para el hover), con selectores lo bastante específicos para ganar sin depender del orden de las reglas en el archivo.
2. **Título de categoría (modo Agrupado) no se congelaba horizontalmente**, aunque su sticky vertical (para quedar debajo del header al hacer scroll hacia abajo) sí funciona. Se probó `position:sticky;left:0` en el `<td colSpan>` de la fila-cabecera y en un `<button>` hijo directo — en ambos casos Chromium reportaba el computed style correcto (`position:sticky`, `left:0px`) pero el elemento se movía 1:1 con el scroll, sin "pegarse" nunca. Se descartó como causa el propio `colSpan`, el `position:sticky` del padre y la ausencia de `transform`/`contain`/`isolation` en toda la cadena de ancestros (se verificó cada uno). Conclusión práctica: limitación puntual de Chromium con sticky horizontal dentro de una celda de tabla con `colSpan` (o un hijo suyo), no reproducible con las reglas normales de CSS. Se resolvió con JS: `onScroll` en el contenedor de la tabla (con `requestAnimationFrame` para no saturar de renders) desplaza un elemento con `transform: translateX(scrollLeft)`.
3. **La primera versión del fix por JS generaba scroll infinito con espacio en blanco.** El elemento al que se le aplicaba `translateX` era el `<button>` completo, del ancho de toda la fila (colSpan, ~2000px). Un elemento transformado SÍ cuenta para el cálculo del área de scroll ("scrollable overflow") de su contenedor — así que mover ese botón 900px a la derecha hacía que el contenedor reportara 900px MÁS de `scrollWidth`, permitiendo scrollear 900px más, lo que volvía a mover el botón, en bucle. Fix: separar el `<button>` (área de click, ancho real de la fila, **sin** transformar) del `<span>` interno angosto (solo ícono + nombre + contador) que sí lleva el `transform`. Verificado pidiendo `scrollLeft = 5000` (muy por encima del máximo real): el navegador lo recorta correctamente al máximo real y `scrollWidth` se mantiene estable en vez de seguir creciendo.

### Decisiones y trade-offs

- **JS en vez de seguir insistiendo con CSS puro para el sticky del título de grupo.** Después de descartar colspan, sticky del padre y containment de ancestros como causa, seguir buscando una solución 100% CSS tenía retorno decreciente. Un `onScroll` con `transform` es un patrón bien conocido para "sticky" cuando `position:sticky` no es confiable en un caso puntual, y es barato en rendimiento con `requestAnimationFrame` + `will-change:transform`.
- **Verificar todo con Playwright + login real en vez de razonar solo por CSS.** Este entorno no tiene navegador para probar visualmente. Instalar Playwright (una sola vez, `playwright/` ya existía con un script pero sin dependencias) y automatizar login + mediciones (`getBoundingClientRect`, `scrollWidth`/`clientWidth`, computed styles) permitió encontrar la causa real (el bug de `.layout__main`) en vez de perseguir síntomas en el CSS de la tabla, que en realidad estaba bien desde el principio.

### Pendientes / próximos pasos

- Desplegar a producción (todo probado hasta ahora es build local).
- Sigue pendiente decidir el resto de SPs modificados/nuevos en `SP/` de sesiones anteriores (no tocados hoy).

---

## 2026-07-30 — Catálogo de Alertas (reporte standalone) + columna "Cargado por" en export de Tareas

### Qué se hizo

**1. Catálogo de Alertas del Monitor — reporte HTML standalone (`SP/reporte_alertas_monitor.html`).**
- Documento informativo, **no integrado en la app** (mismo estilo visual que `SP/reporte_SP_nomina.html`, un ejemplo provisto por el usuario). Cataloga cada alerta real registrada en `Avisos.notificacionesConsolidadas`: SP de origen o clase .NET, qué hace, categoría/prioridad, asunto y destinatarios del último envío, y vista previa del HTML de correo real.
- Datos obtenidos consultando `Avisos.notificacionesConsolidadas` vía la API REST de DAB (`bsc_dab:5000/api/NotificacionesConsolidadas`, alcanzable desde el contenedor `bsc_frontend` que tiene `curl`) — 6206 filas agregadas por `spOrigen`/`origen` → 120 alertas distintas.
- De esas 120: ~62 son SPs de SQL (`C:\Proyectos\BSC\SP\*.sql`; se repartió el análisis de descripciones entre 3 sub-agentes en paralelo para ir más rápido) y ~56 son clases .NET (`AvisosMarcajes.*`, `AvisosJerarquias.Jerarquia_01..35`, `VerificadorAlertas`, etc.) cuyo código fuente **no vive en este repo** sino en `C:\Proyectos\avisos` (proyecto separado del backend de Nómina) — se documentaron a partir de los asuntos/categorías reales de la BD, no del código fuente.
- Excluida "CONSULTA ERRORES MASIVO": no es una alerta distinta, es el registro de error (catch) del propio `pa_consultaErroresMasivo` — quedó 119.
- A pedido del usuario: se reordenó por categoría (alfabético) y, dentro de cada categoría, por asunto (alfabético), con encabezado de sección visual por categoría.
- Se generó además `SP/alertas_monitor.xlsx` con el mismo listado (columnas SP/.NET, nombre, categoría, asunto, destinatarios, fecha y hora de última ejecución, prioridad, registros) para compartir sin abrir el HTML.

**2. Tareas — columna "Cargado por" en el export XLSX.**
- `Tasks.jsx` → `handleExportXlsx`: nueva columna `'Cargado por': t.createdBy`. El backend ya exponía `createdBy` en `TaskItemDto`/`TaskItemMapper` — cero cambios de backend.

**3. `scripts/consultar-tareas-prod.sh` — consulta ad-hoc de solo lectura contra Mongo de producción.**
- Nace de un caso real: el usuario pidió validar quién había creado una tarea puntual ("Envío de valores preliminares de pago..."). La base Mongo **local** de desarrollo no sirve para esto — su dato más reciente es de 2026-06-02 y no tiene a los colaboradores de producción (confirmado: 0 resultados buscando "Danilo Cadena" ahí). Hubo que consultar producción directo.
- El script busca por texto (case-insensitive) en `title` y `description` de `TaskItems` y muestra estado, `createdBy`, `createdAt`, líder/colaborador asignado y fecha de entrega. Pide la contraseña SSH de forma interactiva en cada uso — no la guarda en ningún archivo.

### Decisiones y trade-offs

- **Reporte de alertas fuera de la app, no un endpoint nuevo.** El usuario lo pidió explícitamente como documento aparte ("no debe estar integrado en nomina2"). Evita exponer una superficie nueva en el backend solo para un catálogo de referencia.
- **Clasificación "envía correo" basada en el HTML real de la BD, no en análisis estático del código.** Ver bug abajo — la primera versión confiaba en si el agente veía un `sp_send_dbmail` en el SP, y eso puede fallar si el agente no lee la rama correcta. La verdad de negocio (¿hay contenido real que mostrar?) siempre gana sobre la inferencia de código. Al final esa distinción se **eliminó del todo** de la UI porque, con 119/120 alertas mostrando "envía correo", ya no aportaba señal.
- **Excel del catálogo como entregable aparte, generado por script, no a mano.** Con 119 filas de datos reales (asuntos, destinatarios, categorías, fechas) escribirlas a mano habría sido lento y propenso a error de transcripción; se reutilizó la misma data ya extraída para el HTML.
- **Script de consulta prod interactivo (pide password cada vez) en lugar de guardar credenciales.** Ya hubo un incidente previo de credenciales mal manejadas en este proyecto (ver memoria del asistente); pedir la contraseña en cada ejecución es más trabajo por uso pero cero riesgo de filtración en el repo o en logs.

### Bug encontrado y fix (x2)

- **Síntoma 1:** el reporte mostraba "Sin correo" para 2 SPs (`pa_avisos_biometricosDiel`, `pa_vacacionesPtosE3`) que el usuario confirmó SÍ tenían HTML real en la tabla.
  - **Causa raíz:** el generador confiaba en el flag `sendsEmail` que devolvió el sub-agente de análisis estático de código — y el agente no vio la rama del SP que sí hace `INSERT` con HTML (multi-rama, reportes condicionados por parámetro).
  - **Fix:** se cambió la fuente de verdad a `!!sample.descripcionHtml?.trim()` — el HTML real del último registro en BD, no una inferencia de código.
  - **Lección:** cuando hay datos reales disponibles (la BD), preferirlos sobre análisis estático de código para decidir "¿esto pasa o no?" — el código puede tener ramas que un agente (o una persona) no vea completas; el dato ya resume el resultado real de ejecutar todas las ramas.

- **Síntoma 2:** las tildes en la vista previa del correo salían corruptas (`dÃ­a` en vez de `día`), pese a que los archivos en disco ya estaban en UTF-8 correcto (verificado con grep de los bytes exactos).
  - **Causa raíz:** el `<iframe src="data:text/html;base64,...">` no declaraba `charset` en el data URI. El navegador, al no tener esa pista y el HTML embebido (el cuerpo del correo del SP) tampoco traer su propio `<meta charset>`, adivinaba mal la codificación de los bytes decodificados del base64.
  - **Fix:** `data:text/html;charset=utf-8;base64,...`.
  - **Lección:** un mojibake tipo `Ã­` es casi siempre "UTF-8 leído como Latin-1" — antes de sospechar de los datos/archivos, verificar los bytes en disco (`grep` por la secuencia UTF-8 exacta) para descartar que el problema esté en el punto de renderizado, no en el origen.

- **Síntoma 3 (operativo, no de código):** `sshpass -p 'password' ssh ...` fallaba con `Permission denied` en este entorno (Windows, Git Bash) pese a que la contraseña era correcta (el usuario confirmó que él sí podía conectarse manualmente con la misma).
  - **Causa raíz:** `ssh -vvv` mostró `read_passphrase: can't open /dev/tty` — el cliente OpenSSH moderno intenta abrir `/dev/tty` directamente para el prompt de password en vez de leer el pipe que `sshpass` (el puerto para Windows, sin pty real) le da.
  - **Fix:** usar el mecanismo `SSH_ASKPASS` en vez de `sshpass -p`: variable `SSH_ASKPASS_REQUIRE=force` + `SSH_ASKPASS` apuntando a un script temporal (`echo 'password'`) + stdin del `ssh` redirigido de `/dev/null`. El script temporal se borra apenas termina el uso.
  - **Lección:** en Windows/Git Bash, `sshpass` clásico (que depende de emular un tty) puede no funcionar con versiones recientes de OpenSSH; `SSH_ASKPASS_REQUIRE=force` es el mecanismo soportado oficialmente por OpenSSH ≥ 8.4 para forzar un askpass externo sin tty, y es más confiable en este entorno. Documentado en los comentarios de `scripts/consultar-tareas-prod.sh` para no tener que re-descubrirlo.

### Pendientes / próximos pasos

- El cambio de "Cargado por" en Tareas está probado en build local; falta desplegar a producción (mismo flujo de siempre: build → copiar a `html/` → restart `bsc_frontend`).
- Quedan sin decisión un grupo de SPs modificados/nuevos en `SP/` de sesiones anteriores (no tocados en esta sesión) y un archivo `nul` suelto en la raíz — pendiente de sesión previa, no relacionado a este trabajo.

---

## 2026-05-29 — Fix iframe sandbox, manual de usuario Alertas (HTML) y carpeta docs/ al repo

### Qué se hizo

**1. Fix: links en preview del correo no abrían en nueva pestaña.**
- `AlertaModal` usaba `sandbox=""` en el `<iframe>` del preview — atributo más restrictivo posible, bloquea toda navegación.
- Solución: `sandbox="allow-popups allow-popups-to-escape-sandbox allow-top-navigation-by-user-activation"`. Scripts siguen bloqueados.
- Commit: `cb86fb2`.

**2. Manual de usuario del módulo Alertas Payroll.**
- Generado en dos formatos: `docs/manual-usuario-alertas-payroll.md` y `docs/manual-usuario-alertas-payroll.html`.
- HTML con sidebar de navegación fija, badges de estado/prioridad en colores reales, tablas con formato blue-header, demo de fila crítica, FAQ como acordeón y script de resaltado de sección activa.
- Commit: `24dc081` (primera versión) + commit posterior con el HTML.

**3. Carpeta `docs/` incluida al repositorio.**
- El `.gitignore` tenía `*.md` sin excepción para `docs/`. Se agregó `!docs/*.md`.
- Todos los archivos técnicos de `docs/` (arquitectura, DAB, bitácora, reglas, deploy, modelo de datos) quedaron trackeados a partir de este commit.

### Decisiones

- El HTML se elige sobre Word/PDF porque cualquier usuario lo puede abrir sin instalar nada y puede ser alojado en el servidor estático sin build adicional.
- Se mantuvo el `.md` como fuente de verdad para edición futura.

---

## 2026-05-29 — Botón Actualizar en Alertas y formato XLSX en todos los módulos

### Qué se hizo

**1. Botón "Actualizar" en toolbar del tab Listado (Alertas Payroll).**
- Icono `RefreshCw` (lucide-react) al lado del botón "Descargar".
- Llama a `loadData()` sin recargar la página. Mientras carga: icono gira (`payroll-historial__spinner`) y botón queda `disabled`. Tooltip: "Actualizar datos".

**2. Formato profesional en todos los reportes XLSX del sistema.**
- Problema raíz: `@e965/xlsx` v0.20.3 ignora silenciosamente la propiedad `.s` (estilos de celda) al escribir — ni `cellStyles: true` lo activa. Descubierto al inspeccionar el archivo descargado con Node.js.
- Solución: migrar a `exceljs` (instalado como nueva dependencia). Se usa con `await import('exceljs')` (dynamic import) para que el chunk solo cargue cuando el usuario descarga, no al iniciar la app.
- Formato aplicado en todos los puntos de descarga:
  - Encabezado: fondo azul `#1F4E79`, texto blanco negrita, centrado, altura 22px.
  - Filas alternas: blanco `#FFFFFF` / azul suave `#EBF3FB`.
  - Bordes `thin` en todas las celdas.
  - Header congelado (`ws.views = [{ state: 'frozen', ySplit: 1 }]`).
- Archivos modificados:
  - `AlertasPayroll.jsx` — botón Descargar + click en barras del dashboard.
  - `Tasks.jsx` — exportar tareas + plantilla de carga (fila de ejemplo en amarillo `#FFF9C4` italic para distinguirla).
  - `Home.jsx` — reporte general + click en gráfico por colaborador.

### Decisiones y trade-offs

- **ExcelJS en lugar de xlsx-style u otras alternativas.** ExcelJS es la librería más mantenida y con mejor soporte de estilos XLSX en cliente. La alternativa xlsx-style es un fork abandonado; `@e965/xlsx` community no lo soporta a pesar de aceptar la API sin error.
- **Dynamic import de ExcelJS.** El bundle de ExcelJS es ~939 kB (271 kB gzip). Al usar `await import('exceljs')` Vite lo separa en un chunk propio que solo se descarga al hacer click en "Descargar" — no penaliza el tiempo de carga inicial de la app.
- **`@e965/xlsx` se mantiene en Tasks.jsx.** Sigue siendo necesario para leer archivos XLSX en la carga masiva (`XLSX.read`, `sheet_to_json`, `SSF.parse_date_code`). Solo se reemplazaron las funciones de escritura.

### Pendientes / próximos pasos

- Ninguno urgente. El formato es consistente en todos los módulos.

---

## 2026-05-04 — Alertas Payroll: modal unificado, preview inline de adjuntos, filtro fecha global

### Qué se hizo

**1. Modal unificado `AlertaModal`.**
- Reemplaza al antiguo `PreviewModal` + modal de edición separado. Una sola pantalla concentra:
  - Tabs internos **Correo** / **Adjunto** (estilo carpeta, esquinas redondeadas, indicador inferior de 3px en primario).
  - Panel izquierdo: preview HTML del correo con zoom (default) o iframe del adjunto cuando se selecciona el otro tab.
  - Panel derecho (420px): sección "Resolución" (h3 con barra lateral azul) + meta + select estado + textarea notas (500 chars) + usuario; sección "Adjunto" en una fila con nombre y iconos 👁/⬇.
  - Footer con Cancelar / Guardar (mismo `Swal.fire` de confirmación).
- **Acciones por fila reducidas a un solo icono**: 👁 "Ver y resolver alerta". Eliminados los botones ✏ (edición) y ⬇ (descarga adjunto) — todo se gestiona desde el modal. Columna "Acciones" centrada.

**2. Preview inline de adjuntos (sin abrir nueva pestaña).**
- `payrollService.previewAdjunto({ rutaAdjunto, nombreAdjunto })` retorna `{ previewable, url, fileName, ext, mime }`.
- **Tipos directos** (blob → iframe con MIME forzado por extensión, no el `application/pdf` que devuelve el API): pdf, png, jpg, jpeg, gif, webp, svg, bmp, txt, json, xml, html.
- **Tipos procesados con SheetJS** (`@e965/xlsx` que ya estaba para descarga XLSX): xlsx, xls, xlsm, ods, csv, tsv. Se parsean con `XLSX.read(arrayBuffer)` y se genera un documento HTML completo con tabs por hoja (`XLSX.utils.sheet_to_html`) + script mínimo de navegación + estilos básicos. Ese HTML se envuelve en `Blob('text/html')` para que el iframe lo renderice como tabla.
- Estado del adjunto en el modal: `idle / loading / ready / unsupported / error` con UI específica para cada uno. `URL.revokeObjectURL` en cleanup.

**3. Filtro de fecha global en el Listado.**
- Refactor del pipeline de filtrado: nuevo memo `dateFilteredData` que aplica solo el rango de fechas a `data`. KPIs, donut "Pendientes por Resolver", donut "Distribución por Estado" y horizontal bar "Alertas por Categoría" ahora derivan todos de `dateFilteredData` — antes solo afectaba a la tabla.
- `filteredSorted` parte de `dateFilteredData` y aplica encima búsqueda global, filtros por columna y sort.

**4. Filtro de fecha también en el Dashboard tab.**
- Botón Fecha (mismo patrón `react-datepicker` `selectsRange`) entre el segmented Día/Semana/Mes y "Limpiar filtros". Afecta KPIs (los 4 doughnuts), gráfico vs tiempo, contador de resumen.
- "Limpiar filtros" del dashboard ahora también resetea el rango.

**5. DatePicker con portal global.**
- Nuevo `<div id="datepicker-portal">` agregado a `frontend/index.html` (después de `#root`). Ambos DatePickers (Listado y Dashboard) usan `portalId="datepicker-portal"` + `popperPlacement="bottom-start"`.
- Soluciona el problema de clipping cuando el calendario quedaba dentro de un contenedor con `overflow: hidden` o se desplegaba hacia arriba sin espacio suficiente.

**6. Pies del Dashboard rediseñados (look empresarial).**
- Antes: KPI numérico simple con barra de color.
- Ahora: 4 mini-doughnuts con layout horizontal:
  - Label "notched" 11px UPPERCASE arriba a la izquierda.
  - Cuerpo centrado: doughnut (`cutout: 72%`) + costado derecho con porcentaje grande (30px bold en color de la descripción) + "DEL TOTAL" debajo en uppercase. Separador vertical fino entre ambos.
  - Plugin Chart.js custom `descPieCenter` pinta dos líneas al centro: total grande (26px bold #111827) + "alertas" (11px medium gris).
  - Card con borde superior 4px en color de la descripción, hover con elevación sutil.

**7. Notas de resolución más amplio + contador.**
- Textarea con `rows={12}`, `min-height: 200px`, `resize: vertical`.
- `maxLength={500}` (la columna SQL es `varchar(500)`) con doble defensa: `onChange` aplica `.slice(0, 500)` por si pegan texto largo del portapapeles.
- Contador `X / 500 caracteres` debajo del textarea, alineado a la derecha. Cambia de color: gris (default) → amarillo (≥450) → rojo bold (=500). `aria-live="polite"` para lectores de pantalla; `tabular-nums` para que los dígitos no salten.

**8. Tab "Alertas por Categoría" reemplazó "Alertas por Origen" (commit anterior); chips con botón Limpiar/Todas.**
- Visible en el listado, agrupa por `categoria` (no `origen`). Chips multi-select por descripción (4 colores) + botón al final que alterna **"Limpiar"** (apaga todos si las 4 están activas) o **"Todas"** (enciende todos).

**9. Estado `E` renombrado: "Error envío" → "Error".**
- En `ESTADO_LABELS.E`, KPI card del listado y opción del select del modal de edición.

**10. Filas críticas resaltadas en rojo en la tabla.**
- Helper `isCriticalRow(row)` aplica clase `payroll-row--critical` cuando: `prioridad === Alta` AND `estado ∈ {A,P,E}` AND `descripcion ∈ {Con Novedad, Error Proceso}`. CSS: fondo `rgba(239,68,68,.10)`, hover `.18`, barra lateral roja 3px en la primera celda.

### Decisiones y trade-offs

- **Modal único en lugar de modales separados.** El usuario reportó fricción al tener que abrir un modal para ver el correo y otro para resolver. Unificar requirió mover la edición de estado/notas al lado derecho como panel pegado en lugar de un modal centrado, pero la UX termina siendo más eficiente (todo el contexto a la vista).
- **Preview inline de xlsx con SheetJS, no `tipo=V` del API externo.** El API de Utilerias Payroll soporta `tipo=V` (preview) pero responde siempre `Content-Type: application/pdf`, lo cual rompe la previsualización de hojas de cálculo en el iframe. Procesar el blob en cliente con SheetJS y generar HTML evita el round-trip extra al backend, no requiere cambios al `.NET` y le da consistencia visual con tablas formateadas. Limitación: no se respetan colores/formatos del Excel (negritas, fórmulas, gráficos).
- **DatePicker en portal global.** Renderizar fuera del DOM tree de los cards evita problemas de clipping y de auto-flip que ocurrían con el popper interno. La alternativa era un fix CSS por contenedor — más frágil.
- **Filtro de fecha como primer paso del pipeline (no fork).** Centralizar el filtro de fechas en `dateFilteredData` antes que el resto evita repetir la lógica en cuatro memos distintos y garantiza que KPIs, donuts y tabla estén siempre sincronizados.
- **Plugin Chart.js que lee del `chart.options` en lugar de closure.** Originalmente el plugin del centro del donut capturaba `pct` y `color` por closure del primer render; al cambiar las props, Chart.js mantenía la referencia al plugin viejo y el `%` no se actualizaba con los filtros. La solución fue mover `count` a `chart.options.plugins.descPieCenter.count` y leerlo dentro del `afterDraw`. Lección: para texto dinámico en plugins de Chart.js, leer siempre del chart instance, nunca del closure.

### Bug encontrado y fix

- **Síntoma:** los inputs del panel "Resolución" se veían con una fuente distinta a los textos meta y al título.
- **Causa raíz:** los `<input>`, `<select>`, `<textarea>` HTML **no heredan `font-family` del padre por defecto** — tienen reglas UA que aplican fuente del sistema operativo. Mi regla genérica con baja specificidad no ganaba.
- **Fix:** `font-family: 'Inter', ... !important` en selectores específicos `(.preview-modal__side input, select, option, textarea, button, .form-control)`. Cadena literal en lugar de la variable CSS por seguridad.
- **Lección:** cuando un `<input>` se ve "raro" en una página, el primer sospechoso son las reglas UA del navegador, no el design system de la app. Aplicar `font-family` explícitamente cierra la brecha.

### Pendientes / próximos pasos

- Decisión sobre DAB en producción aún en standby (subir DAB tal cual vs migrar las dos llamadas al backend BSC con un controller propio).
- Si se mantiene DAB: implementar historial de estados en colección Mongo `payrollAlertasHistorial` (best-effort, no bloquea la actualización en DAB si falla el registro).
- Considerar cargar fonts de Inter dentro del iframe de preview (correo y adjunto HTML de SheetJS) para mantener tipografía consistente; hoy esos iframes usan fallback Arial / Segoe UI.

---

## 2026-04-28 — Alertas Payroll: dashboard, pie charts, paginación, filtros y descarga (commit `088aea6`)

### Qué se hizo

**1. Reestructura en tabs (Dashboard / Listado).**
- La página entra en **Dashboard por defecto**. Listado es la vista clásica con tabla.
- Dashboard tiene **filtros propios** (Prioridad, Categoría, Estado + segmented Día/Semana/Mes), independientes de los del listado.

**2. Dashboard con pie charts y barras vs tiempo.**
- 4 mini-doughnuts (`DescriptionPie`) — uno por descripción (Con/Sin Novedad, Reportería, Error Proceso). Estilo `MonthlyStarsCard` de Tareas: `Doughnut` de `react-chartjs-2` con `cutout: 70%` y plugin custom `descPieCenter` que pinta `%` al centro con el color de la descripción. Debajo: nombre + cantidad.
- Resumen superior: `X filtradas · Y clasificadas · Z sin clasificar` (last only when `Z > 0`).
- Gráfico de barras apiladas vs tiempo (`Bar` de Chart.js). `bucketOf(iso, mode)` agrupa por día / semana ISO-8601 / mes. **Click en barra** descarga `Alertas_{Descripcion}_{Bucket}.xlsx` con las alertas que coinciden con el tramo + descripción + filtros activos.

**3. Donut nuevo "Pendientes por Resolver" (en tab Listado).**
- Antes de "Distribución por Estado". Filtra alertas con estado en `{A, P, E}` y agrupa por descripción. **Excluye `Sin novedad`** explícitamente. Etiqueta central "Pendientes". Leyenda con cantidad y `%`.
- `DonutChart` ahora acepta prop opcional `showPercent` (el donut original no lo usa).

**4. "Alertas por Origen" → "Alertas por Categoría" con chips multi-select.**
- Reemplazo: agrupa por `categoria` en lugar de `origen`, ordenado descendente. Las alertas sin `categoria` caen en barra "Sin categoría".
- Chips encima del gráfico para filtrar por descripción (4 colores). Botón al final que alterna **"Limpiar"** / **"Todas"** según el estado actual del set.

**5. Tabla "Alertas" (renombrada de "Notificaciones Recientes").**
- **Filtro de fecha** (botón con icono Calendar + `react-datepicker` `selectsRange`): rango sobre `fechaCreacion`, con X integrado para limpiar. Mismo patrón visual que el filtro de Tareas (`Tasks.jsx:851-894`).
- **Paginación cliente**: selector 10/20/50/100/200 (default 20), navegación primera/anterior/siguiente/última, indicador `X–Y de Z`. Reset a página 1 al cambiar filtros o `pageSize` (no al cambiar sort).
- **Botón Descargar** XLSX que respeta filtros aplicados (todo el conjunto filtrado, no solo la página visible). Nombre `Alertas_YYYY-MM-DD.xlsx`. Reutiliza `downloadAlertasXlsx` que también usa el dashboard al hacer click en una barra.
- "Limpiar filtros" ahora también limpia el rango de fechas.

**6. Filas críticas resaltadas en rojo.**
- Helper `isCriticalRow(row)` aplica clase `payroll-row--critical` cuando: `prioridad === Alta` AND `estado ∈ {A, P, E}` AND `descripcion ∈ {Con Novedad, Error Proceso}`.
- CSS: fondo `rgba(239,68,68,.10)`, hover `.18`, barra lateral roja (`box-shadow: inset 3px 0 0 #ef4444`) en la primera celda.

**7. Estado `E`: "Error envío" → "Error".**
- Renombrado en `ESTADO_LABELS.E`, KPI card y opción del select del modal de edición. El donut original ya tenía label "Error" desde antes.

**8. Paginación con `nextLink` en `payrollService.getNotificaciones`.**
- Antes truncaba a 100 con `$first=100`. DAB respeta `max-page-size: 100` por página y devuelve `nextLink` (o `@odata.nextLink`) cuando hay más. Ahora itera siguiendo el cursor hasta agotar, con tope de seguridad de 100 iteraciones. Maneja URLs absolutas y relativas: las absolutas se reescriben al prefijo `/dab/` para que sigan pasando por el proxy de nginx.

### Decisiones y trade-offs

- **Mantener filtrado/sort/paginación 100% en cliente.** DAB ya no trunca por la paginación con `nextLink`, así que toda la lista vive en memoria del browser. Para los volúmenes actuales (≤500 alertas) es óptimo: filtros instantáneos, descarga sin round-trip extra, sin necesidad de mover filtros al servidor. **Cuando supere los miles**, conviene mover filtrado y paginación al backend (con un endpoint propio que reemplace DAB en lectura) — está en el radar pero no es prioridad.
- **Descarga del filtrado completo (no solo página visible).** Es lo que el usuario espera: si filtra "Estado=Activa, Prioridad=Alta" y descarga, espera todas las activas-altas, no solo las 20 que ve. Coste: el XLSX puede ser grande, pero `@e965/xlsx` lo maneja en cliente sin problema.
- **Click en barra del gráfico = descarga directa, sin modal intermedio.** Sigue el patrón del dashboard de Tareas (`Home.jsx:888-905`). Reutiliza la misma función `downloadAlertasXlsx`.
- **Pie chart por descripción en lugar de KPI numérico.** El usuario pidió explícitamente el estilo `MonthlyStarsCard` de Tareas. Visualmente comunica mejor el peso relativo de cada descripción que un número plano.
- **Excluir "Sin novedad" del donut "Pendientes por Resolver".** "Sin novedad" no representa una alerta que requiera acción, por definición. Mostrarlo en "pendientes" diluiría el indicador.
- **`isoWeek` propio (no librería).** Implementación ISO-8601 directa: `target.setDate(d - dayNr + 3); target.setMonth(0,1)` y `Math.ceil((firstThursday - target)/604800000)`. Evita una dependencia adicional para algo que se usa una sola vez.
- **DAB sigue siendo el cuello de la lectura.** Si DAB no se sube en producción, todo el módulo (no solo el historial) deja de funcionar. Conversación pendiente con el usuario para decidir si se sube DAB o si se migra la lectura/escritura al backend BSC con un controller propio.

### Bug encontrado y fix

- **Síntoma:** la tabla mostraba 100 alertas cuando en SQL hay 144.
- **Causa raíz:** `payrollService` usaba `$first=100` y DAB respeta `max-page-size: 100` por página; sin paginación de cursor, los 44 restantes se descartaban silenciosamente.
- **Fix:** loop que sigue `data.nextLink || data['@odata.nextLink']` hasta agotar, normalizando URLs absolutas a relativas (proxy `/dab/`).
- **Lección:** los APIs OData/DAB suelen tener paginación implícita por cursor; nunca asumir que `$first` o `$top` solos traen todo.

### Pendientes / próximos pasos

- Decisión arquitectónica: ¿subir DAB a producción tal cual, o migrar las dos llamadas de `/dab/...` a un controller en el backend BSC (con `Microsoft.Data.SqlClient`)? Ver tradeoffs en la conversación con el usuario; el segundo camino habilita meter el **historial de estados** (al estilo Tareas) en una sola operación atómica con la actualización de DAB.
- Si se mantiene DAB: implementar historial best-effort (colección Mongo `payrollAlertasHistorial` + endpoint `POST/GET` en backend BSC, llamada extra desde el frontend tras el PATCH a DAB; en caso de fallo del registro, no bloquear).
- Cuando el volumen supere los miles de alertas, evaluar mover filtros y paginación al servidor.

---

## 2026-04-27 — Alertas Payroll: descarga de adjuntos + renombre estado C + colores de badges

### Qué se hizo

**1. Descarga de adjuntos (feature nuevo).**
- Backend (.NET 8, nuevo módulo): proxy `GET /api/alertas-payroll/adjunto?ruta=…&nombre=…` que reenvía al API interna de Utilerias Payroll (`utileriaspayroll.azurewebsites.net/api/Documentos/VerArchivosPdf`).
  - `BSC.Application/Interfaces/IUtileriasPayrollClient.cs` (interfaz + DTO `AdjuntoDescargado` + `UtileriasPayrollOptions`).
  - `BSC.Application/Queries/DescargarAdjunto/` (Query + Handler).
  - `BSC.Application/Validators/DescargarAdjuntoValidator.cs` (bloquea path traversal).
  - `BSC.Infrastructure/Services/UtileriasPayrollClient.cs` (`HttpClient` tipado).
  - `BSC.API/Controllers/AlertasPayrollController.cs` (`[Authorize]`, `FileStreamResult`).
  - `DependencyInjection.cs` registra `HttpClient` + opciones desde `UTILERIAS_API_BASE` y `UTILERIAS_TOKEN`.
- Config: `docker-compose.yml` y `.env.example` con las dos vars nuevas.
- Frontend:
  - `payrollService.descargarAdjunto({ rutaAdjunto, nombreAdjunto })` con JWT, recibe blob y dispara descarga vía `<a download>`.
  - Tercer botón ghost en `table__actions` con ícono `Download` de lucide-react. Activo si `rutaAdjunto`, deshabilitado si null. Tooltip dinámico (`Descargar {nombre}` / `Sin adjunto`).

**2. Estado `C` renombrado: "Caducada" → "Cerrada".**
- `ESTADO_LABELS.C` ya estaba en `'Cerrada'` (sin cambio), pero quedaban referencias viejas:
  - `StatusBadge` `classMap.C`: `payroll-badge--caducada` → `payroll-badge--cerrada`.
  - `stats.caducadas` → `stats.cerradas`.
  - KPI card y donut: label `Caducadas` → `Cerradas`.
- CSS: `.payroll-badge--caducada` renombrado a `.payroll-badge--cerrada`. Color cambiado de warning (amarillo) a inactive (gris) — "cerrada" no es alarma, es estado terminal neutro.

**3. Colores estandarizados en badges.**
- **Prioridad** (campo `prioridad`):
  - Alta → **rojo** (antes naranja `#FFF7ED`/`#C2410C`).
  - Media → amarillo (sin cambio).
  - Baja → **verde** (antes celeste).
- **Descripción** (campo `descripcion`, nuevo `DescriptionBadge`):
  - `Con novedad` → rojo.
  - `Sin novedad` → verde.
  - `Reporteria` / `Reportería` → celeste (info).
  - `Error Proceso` → amarillo (warning).
  - Cualquier otro valor → texto plano truncado a 80 chars (fallback).

### Decisiones y trade-offs

- **Proxy backend para descarga (no llamada directa al API externo desde React).** Razones: (1) `UTILERIAS_TOKEN` no se expone al frontend; (2) JWT de BSC valida que el usuario está autenticado, habilita auditoría futura; (3) evita CORS contra el dominio de Azure. Costo: un endpoint adicional, pero el patrón es estándar (`HttpClient` tipado + DI).
- **Sin restricción de rol para descargar.** Cualquier usuario autenticado puede; alineado con que el feature sirve para consulta operativa, no contiene PII sensible que justifique gating por rol.
- **Solo `tipo=D` (descarga) por ahora.** El API soporta `tipo=V` (preview inline) pero queda fuera de scope. Al activarse, hay que mapear el MIME por extensión en `UtileriasPayrollClient` porque el API responde siempre `application/pdf` aunque acepte cualquier archivo (legado del nombre `VerArchivosPdf`). El detalle quedó documentado en `docs/alertas-payroll.md`.
- **Lookup case-insensitive en `prioridad`/`descripcion`.** Los datos vienen con primera letra en mayúscula (`"Alta"`, `"Con novedad"`). El primer intento del badge usaba claves lowercase (`alta`) y no matcheaba — se veía sin color. Fix: `String(value).trim().toLowerCase()` antes del lookup tanto para la clase CSS como para el label.

### Bug encontrado y fix

- **Síntoma:** badges de Prioridad sin color (Alta no rojo, Baja no verde).
- **Causa raíz:** `classMap` tenía claves `alta`/`media`/`baja` pero los datos llegan como `"Alta"`/`"Media"`/`"Baja"`. El lookup directo devolvía `undefined` y el `<span>` quedaba con `className="payroll-badge "` (sin la modificadora).
- **Fix:** función `normalizePriority(p) = String(p).trim().toLowerCase()` aplicada antes del lookup en `PriorityBadge` y también en `filterValue`/`sortValue` de la columna.
- **Lección:** cuando el dato viene de una BD externa (DAB sobre SQL) sin un mapping/normalización propio, no asumir casing. Aplica también al campo `descripcion` y por eso `DescriptionBadge` ya nació con normalización.

### Pendientes / próximos pasos

- Validar manualmente que la descarga funciona en producción cuando se despliegue (pruebas locales con `idNotificacion 27/28/29` ya fueron ✅).
- Si en algún momento se enciende preview inline (`tipo=V`), implementar mapping MIME por extensión. Detalles ya en `docs/alertas-payroll.md`.

---

## 2026-04-22 — Alertas Payroll: ajustes de UX y alineación con design system

### Qué se hizo
- **Reorden de columnas**: `Acciones` ahora es la primera columna (antes era la última). `Origen` se movió a después de `Notificados` (antes iba tras `Categoría`).
- **Opción "Error envío" (`E`)** agregada al `<select>` de edición de resolución. Antes solo se podía marcar `P` o `R`. Adicionalmente, `openEdit` ahora preserva el estado actual del registro si es editable (`P`/`R`/`E`), en lugar de forzar siempre `P` como default.
- **Iconos de acción sin borde**: los botones 👁️ y ✏️ pasaron de una clase custom `.payroll-action-btn` (con `border: 1px solid`) al patrón del design system — `table__actions` + `btn.btn--icon.btn--sm.btn--ghost` — idéntico al que usa `Tasks.jsx`.
- **Tabla alineada con design system**: la tabla ya no redefine padding, alturas, colores, bordes ni hover — hereda todo de `.table` (`style/components.css`). Se usa `<div className="table-container payroll-sticky-table">` + `<table className="table">`. Solo queda custom el wrapper sticky (`max-height`, `overflow`, `border-collapse: separate`) y los estilos del botón de sort + input de filtro por columna.

### Decisión de diseño
- Consolidar en el design system en lugar de mantener estilos paralelos. Cualquier cambio futuro a `.table` (tipografía, colores, densidad) ahora se propaga automáticamente a Alertas Payroll — antes quedaría atrás.
- `border-collapse: separate` se scoped a `.payroll-sticky-table .table` para no afectar las demás tablas del sistema.

### Pendiente
- Estos cambios **están sin subir al servidor**. Aplican cuando se ejecute el runbook `docs/deploy-alertas-payroll.md` — el build que quede desplegado incluirá este ajuste. Recordar correr `vite build` en caliente justo antes.

---

## 2026-04-22 — Runbook de deploy Alertas Payroll + DAB

### Qué se hizo
Se redactó `docs/deploy-alertas-payroll.md` con el plan completo del primer despliegue del módulo + stand-up inicial de DAB en el servidor APP. **El deploy NO se ha ejecutado aún** — queda todo listo para cuando sea el momento.

### Contexto clave capturado en el runbook
- App **interna** (red corporativa / VPN), ya con usuarios activos en prod.
- SQL prod ya tiene aplicado el `ALTER` que permite `estado='P'` (hecho directo en la BD).
- Servidor APP (sistema) y servidor SQL son máquinas **distintas** — DAB en APP se conectará vía `SQL_CONN`.
- DAB nunca se ha subido a APP; es la primera vez.
- Seguridad de DAB queda con `Simulator` + permisos anónimos: aceptable por ser red interna, se endurece en fase 2.

### Pendientes / próximos pasos
- Ejecutar el runbook cuando se decida la ventana.
- Antes: refrescar el `vite build` por si hubo cambios en el repo desde hoy.
- Después: registrar en esta bitácora fecha exacta, ejecutor y resultado del smoke test.

---

## 2026-04-22 — docs/ inicial: arquitectura, DAB, modelo de datos, reglas de negocio

### Qué se hizo
Se pobló por primera vez la carpeta `docs/` con los documentos pendientes del índice:
- `arquitectura.md` — stack, servicios, red Docker, flujo de requests.
- `integracion-dab.md` — DAB (entity, OData, operación, notas de seguridad).
- `modelo-datos.md` — colecciones MongoDB + tabla SQL.
- `reglas-negocio.md` — actores, estados de tareas, flujo de alertas, auth.

### Decisiones aclaradas con el usuario
- **DAB fuera del compose — intencional.** `bsc_dab` no se integrará al `docker-compose.yml` principal por ahora. Se opera/levanta manualmente. Los docs lo reflejan como decisión, no como TODO.
- **Estado `P` en `notificacionesConsolidadas` — válido.** La BD real ya acepta `IN ('A','P','R','C','E')`. No hay discrepancia UI vs BD.

### Observación que sigue viva
- **Permisos DAB abiertos:** `anonymous: create/read/update/delete` + `authentication.provider: Simulator`. Aceptable en desarrollo, **no** en producción. Hay que cerrar eso antes de exponer el sistema al exterior.

### Pendientes / próximos pasos
- ~~Sincronizar `scripts/001_crear_notificacionesConsolidadas.sql` con la BD real.~~ **Resuelto:** se agregó `scripts/002_alter_estado_agregar_p.sql` (idempotente, DROP + ADD de `CK_notifConsolidadas_estado` con el set `A,P,R,C,E`). Recrear la BD en otro entorno requiere ahora correr `001` + `002` en orden.
- Planear endurecimiento de DAB (auth provider, roles, CORS) antes de exponer a prod.
- Script `npm run deploy` en `frontend/package.json`.

---

## 2026-04-22 — Alertas Payroll: refactor de tabla + modal de previsualización

### Qué se hizo
1. **Eliminado** el split layout previo (tabla + preview lateral). Tomaba mucho ancho y limitaba la tabla.
2. **Tabla mejorada** (`AlertasPayroll.jsx` / `.css`):
   - Sort en todas las columnas (ciclo `asc → desc → sin orden`) con `aria-sort` y ciclos por tipo (`text` / `date`).
   - Filtros duales: input global arriba (OR entre columnas) + inputs por columna en segunda fila del `<thead>` (AND). Ambos case-insensitive.
   - Botón "Limpiar filtros" + contador `X de Y`.
   - Headers sticky de dos niveles (header + filtros), con `box-shadow` inset para evitar el bug del borde que desaparece con `position: sticky`.
3. **Modal de previsualización** (componente `PreviewModal` en el mismo archivo):
   - Se abre desde el ícono 👁️ en la columna "Acciones".
   - Iframe `sandbox=""` aislado, renderiza la columna `descripcionHtml` de `Avisos.notificacionesConsolidadas`.
   - Zoom 25–300% en pasos de 25% (botones + `Ctrl + wheel`).
   - Cierra con `Esc`, X y click en el overlay.
   - Título: `{asunto} — {fechaCreacion}`.

### Decisiones y trade-offs
- **Filtros dual (global + por columna)** en vez de elegir uno: cubren casos distintos (búsqueda rápida vs filtrado quirúrgico). Mínimo overhead de UI.
- **Sandbox vacío** para el iframe: bloquea scripts pero permite CSS inline, adecuado para HTML de correo. No permite medir `scrollHeight` desde fuera → se usa altura base fija (`BASE_H = 1100px`).
- **Escalado con `transform: scale()`** sobre el iframe: el stage wrapper se dimensiona en `BASE × scale` para que los scrollbars del contenedor reflejen el tamaño real escalado.

### Bug encontrado y fix
- **Síntoma:** el header de la app (barra superior con nombre de usuario, campana, etc.) tapaba los botones del modal.
- **Causa raíz:** el design system define escala de z-index en `style/variables.css` (`--z-fixed: 1030` para el header, `--z-modal: 1050` para modales). El CSS inicial del modal usaba `z-index: 1000` hardcoded → por debajo del header.
- **Fix:** `z-index: var(--z-modal, 1050)` en `.preview-modal__overlay`.
- **Lección:** al crear cualquier overlay/dialog, usar las variables `--z-modal*` del design system, no valores hardcoded.

### Deploy
- Frontend es build estático, nginx sirve `./html/` (volumen `ro` del contenedor `bsc_frontend`).
- Flujo: `vite build` → copiar `dist/` a `html/` → `docker restart bsc_frontend`.
- No existe aún script `npm run deploy` que empaquete esto; queda como TODO.

### Pendientes / próximos pasos
- Agregar script `npm run deploy` al `package.json` del frontend.
- Evaluar si el filtro "Origen" se beneficiaría de un select (dropdown con valores únicos) en vez de input libre, dado que es un enum derivado.
- La altura base del iframe (`1100px`) es conservadora pero arbitraria. Si algún correo es más alto, el iframe tiene scroll interno; aceptable por ahora.

---

## Formato para entradas futuras

```
## YYYY-MM-DD — Título corto

### Qué se hizo
- Bullets de los cambios concretos.

### Decisiones y trade-offs
- Por qué se eligió X sobre Y, con el contexto que llevó a la decisión.

### Bug encontrado y fix (si aplica)
- Síntoma, causa raíz, fix. No solo el parche.

### Pendientes / próximos pasos
- Lo que queda abierto.
```
