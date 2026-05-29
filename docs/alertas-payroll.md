# Alertas Payroll

Dashboard de notificaciones y alertas del sistema de nómina.

## Ubicación en el código
- Página: `frontend/src/pages/AlertasPayroll/AlertasPayroll.jsx`
- Estilos: `frontend/src/pages/AlertasPayroll/AlertasPayroll.css`
- Servicio: `frontend/src/services/payrollService.js`

## Fuente de datos

Los datos vienen de la tabla SQL Server `Avisos.notificacionesConsolidadas`, expuesta como REST vía **Data API Builder** (DAB).

- Endpoint lectura: `GET /dab/NotificacionesConsolidadas?$orderby=fechaCreacion desc&$first=100`
- `payrollService.getNotificaciones()` **pagina automáticamente** siguiendo `nextLink` (o `@odata.nextLink`) hasta agotar resultados, con un tope de seguridad de 100 iteraciones. DAB respeta `max-page-size: 100` por página, así que con varias páginas se obtienen los registros completos. Las URLs siguientes pueden venir absolutas o relativas; el servicio las normaliza al prefijo `/dab/`.
- Endpoint actualización de resolución: `PATCH /dab/NotificacionesConsolidadas/idNotificacion/{id}`
- Definición del entity en `dab/dab-config.json` (source: `Avisos.notificacionesConsolidadas`, type `table`).
- Script de creación de la tabla: `scripts/001_crear_notificacionesConsolidadas.sql`.

### Columnas relevantes de la tabla
- `idNotificacion` (BIGINT, PK)
- `fechaCreacion`, `fechaEnvio`, `fechaResolucion`, `fechaModificacion` (datetime)
- `estado` (CHAR(1): `A`=Activa, `P`=En Proceso, `R`=Resuelta, `C`=Cerrada, `E`=Error)
- `prioridad`, `categoria` (varchar)
- `origen`, `spOrigen` — dominio y SP que generó la alerta
- `asunto`, `descripcion`, `descripcionHtml` — contenido del correo; `descripcionHtml` es lo que se previsualiza en el modal. Los valores conocidos de `descripcion` son: `Con Novedad`, `Sin Novedad`, `Reportería` (también acepta `Reporteria` sin tilde) y `Error Proceso`.
- `destinatarios`, `destinatariosCc` (separados por `|`, `;` o `,`)
- `usuarioResolucion`, `notasResolucion`, `rutaAdjunto`, `nombreAdjunto`

El mapeo SP → `origen` está en el comentario del script SQL (Biométricos, Vacaciones, Marcajes, Horarios, Ausencias, etc.).

## UI — Estructura de la página

La página tiene **dos tabs** debajo del header:

- **Dashboard** (default) — KPIs por descripción + gráfico de barras vs tiempo con descarga al click.
- **Listado** — KPIs por estado + gráficos circulares + chips por categoría + tabla "Alertas".

Ambos tabs comparten la misma `data` cargada de DAB pero **filtros independientes**.

### Tab Dashboard
1. **Filtros propios** (no comparten estado con el listado):
   - Selects: Prioridad, Categoría, Estado.
   - Botón **Fecha** con `react-datepicker` rango (`selectsRange`) — mismo patrón que Tareas, con icono Calendar y X integrado para limpiar. Está colocado **antes** del botón "Limpiar filtros".
   - Selector segmented Día/Semana/Mes para la agrupación temporal del gráfico de tiempo.
   - Botón **"Limpiar filtros"** que resetea todos los filtros del dashboard incluyendo el rango de fechas.
2. **Resumen** arriba: `X filtradas · Y clasificadas · Z sin clasificar`. "Sin clasificar" aparece en amarillo solo si hay alertas con `descripcion` que no encaje en los 4 buckets conocidos.
3. **4 doughnuts empresariales** (`DescriptionPie`) — uno por descripción (Con Novedad / Sin Novedad / Reportería / Error Proceso):
   - **Cuerpo centrado** dentro de la card con label "notched" uppercase 11px arriba a la izquierda.
   - Doughnut con `cutout: 72%`. Plugin custom `descPieCenter` lee `count` desde `chart.options.plugins.descPieCenter.count` (no closure — se actualiza al filtrar) y pinta dos líneas al centro:
     - **Total** en `26px bold #111827`.
     - **"alertas"** debajo en `11px medium #6B7280`.
   - Al costado derecho del donut, separado por una línea vertical fina:
     - **Porcentaje** grande en `30px bold` con el **color de la descripción**, `tabular-nums` para que los dígitos no salten.
     - **"DEL TOTAL"** debajo en uppercase 11px gris.
   - Card con borde superior 4px en color de la descripción, hover con elevación sutil.
4. **Gráfico de barras apiladas vs tiempo** (`Bar` de Chart.js, stack por descripción). El eje X agrupa por bucket según el toggle (`isoDay` / `isoWeek` ISO-8601 / `isoMonth`). **Click en una barra** descarga un XLSX (`Alertas_{Descripcion}_{Bucket}.xlsx`) con las alertas que coinciden con ese tramo + esa descripción + filtros activos.

### Tab Listado
1. **KPIs** (6 tarjetas): Total, Activas, En Proceso, Resueltas, Cerradas, Error.
2. **3 gráficos circulares/barras** (`payroll-charts-row`, grid `auto-fit minmax(320px, 1fr)`):
   - **Pendientes por Resolver** (donut, `showPercent`) — solo alertas con estado en `{A, P, E}`, agrupadas por descripción. Excluye explícitamente `Sin novedad`. Etiqueta central "Pendientes".
   - **Distribución por Estado** (donut original).
   - **Alertas por Categoría** (horizontal bar) con **chips multi-select** encima (Con Novedad / Sin Novedad / Reportería / Error Proceso). Los chips pintan con el color de la descripción cuando están activos y atenuados cuando no. Botón al final que alterna **"Limpiar"** (si las 4 están activas) o **"Todas"** (si hay alguna apagada). Si no hay coincidencias se muestra mensaje vacío.
3. **Tabla "Alertas"** con toolbar + filtros + sort + paginación cliente + descarga + **actualizar** + acciones por fila.
4. **Modal unificado `AlertaModal`** (sustituye al antiguo `PreviewModal` + modal de edición):
   - Tabs internos **"Correo"** y **"Adjunto: nombre.ext"** estilo carpeta (esquinas redondeadas, indicador inferior de 3px en color primario).
   - Panel izquierdo: preview del HTML del correo (con zoom 25-300%) o iframe del adjunto según el tab activo.
   - Panel derecho: sección **"Resolución"** (h3 con barra lateral azul) + meta + select estado + textarea notas (500 chars con contador) + usuario; sección **"Adjunto"** con nombre + iconos previsualizar/descargar.

### Pipeline de filtrado del Listado

Tres memos encadenados:
1. `dateFilteredData = data.filter(porFecha)` — única source-of-truth para el rango de fechas.
2. `filteredSorted = dateFilteredData.filter(porBúsqueda + porColumna).sort(porSort)`.
3. `paginatedRows = filteredSorted.slice(página)`.

KPIs, donut "Pendientes por Resolver", donut "Distribución por Estado" y horizontal bar "Alertas por Categoría" **todos derivan de `dateFilteredData`** — al cambiar el rango de fechas, todo se recalcula a la vez. La tabla además aplica búsqueda y filtros por columna sobre el resultado.

## Tabla — Comportamiento

### Sort
- Cada encabezado es clickeable (botón con `aria-sort`).
- Ciclo: `asc → desc → sin orden`.
- Tipos por columna (`type` en `baseColumns`):
  - `date` → `fechaCreacion`, `fechaModificacion` (compara por `getTime()`).
  - `text` → el resto (compara con `localeCompare('es', { sensitivity: 'base', numeric: true })`).
- Columnas con etiquetas visibles diferentes al valor crudo (`estado`, `prioridad`) definen `sortValue` para ordenar por la etiqueta, no por el código.
- Valores nulos/vacíos quedan al final.

### Filtros
Se implementaron **tres** mecanismos complementarios:

- **Input global** (arriba de la tabla): busca en todas las columnas filtrables (OR entre columnas).
- **Inputs por columna** (segunda fila del `<thead>`): filtro específico por columna (AND entre columnas).
- **Filtro de fecha** (botón con icono Calendar + `react-datepicker` con `selectsRange`): rango sobre `fechaCreacion`. El botón muestra el rango seleccionado o "Fecha"; lleva un X integrado para limpiar sin abrir el popover. Mismo patrón visual que el filtro de fecha en `Tasks.jsx`. El filtro toma todo el día completo del extremo superior (`23:59:59.999`) para incluirlo en el rango.
- Todos son case-insensitive y se aplican en tiempo real.
- Botón "Limpiar filtros" resetea **todo** (búsqueda global, filtros por columna y rango de fechas); deshabilitado cuando no hay filtros activos.
- Contador `X de Y` a la derecha del toolbar (con `aria-live="polite"`).

Las columnas cuya celda muestra una etiqueta diferente al valor crudo definen `filterValue` (ej. `estado` filtra por "Activa", no por "A").

### Paginación cliente
- Selector de **filas por página**: 10, 20, 50, 100, 200 (default 20).
- Navegación: primera / anterior / `Página X de N` / siguiente / última.
- Indicador `X–Y de Z` con el rango visible y el total filtrado.
- Reset automático a la página 1 cuando cambian los filtros (búsqueda global, columnas, fechas) o el `pageSize`. **No** se resetea al cambiar el sort.
- La tabla renderiza `paginatedRows`, no `filteredSorted` directo, pero **la descarga XLSX usa `filteredSorted` completo** (no la página visible).

### Botón Actualizar
- Botón `btn--secondary btn--sm` con icono `RefreshCw` en la toolbar del Listado, al lado de "Descargar".
- Llama a `loadData()` para recargar datos de DAB sin refrescar la página. Mientras carga: icono gira y botón queda `disabled` (usa el `loading` state existente). Tooltip: "Actualizar datos".

### Descarga XLSX
- Botón "Descargar" (primario) en la toolbar, junto al filtro de fecha.
- Si no hay filtros: descarga **todas** las alertas. Si hay filtros: descarga el subconjunto filtrado completo, no solo la página actual.
- Nombre del archivo: `Alertas_YYYY-MM-DD.xlsx`.
- **Formato**: generado con `exceljs` (dynamic import). Encabezado azul `#1F4E79` con texto blanco negrita, filas alternas blanco/azul suave `#EBF3FB`, bordes `thin` en todas las celdas, header congelado. Ver bitácora 2026-05-29 para el detalle de la decisión de librería.
- Genera el XLSX en cliente con `@e965/xlsx` (mismo paquete que `Home.jsx`). Columnas: ID, Fecha Creación, Estado, Prioridad, Categoría, Asunto, Descripción, Notificados, Origen, Fecha Resolución, Usuario Resolución, Notas Resolución. Anchos auto-ajustados con tope de 60 chars.
- La función `downloadAlertasXlsx(alertas, fileName)` también la usa el dashboard al hacer click en una barra del gráfico vs tiempo.

### Alineación con el design system
La tabla **hereda del design system** (`style/components.css`) todo lo genérico: padding `var(--spacing-4)`, alturas `--table-row-height` / `--table-header-height`, colores del `th` (`--color-text-secondary` sobre `--color-bg-main`), hover, bordes entre filas. Se usa `<div className="table-container payroll-sticky-table">` + `<table className="table">`, igual que Tasks.

Lo único custom es la clase `.payroll-sticky-table` que añade el scroll vertical + los stickies (ver abajo). Esto garantiza consistencia visual con el resto de la app.

### Sticky headers
Contenedor `.payroll-sticky-table` con `max-height: 65vh; overflow: auto`.

- Fila 1 (headers): `position: sticky; top: 0; z-index: 3`.
- Fila 2 (filtros): `position: sticky; top: var(--table-header-height); z-index: 2`.
- La tabla dentro del wrapper usa `border-collapse: separate; border-spacing: 0` (necesario porque con `collapse` + sticky los bordes desaparecen al hacer scroll). Fuera del wrapper la regla no aplica, así que el resto de tablas del sistema (Tasks, Colaboradores, etc.) siguen con `collapse` del design system.
- Fix del "borde que desaparece con sticky": en las filas sticky del `thead` se usa `box-shadow: inset 0 -1px 0 var(--color-border-light)` en vez de `border-bottom`.

### Orden de columnas
1. **Acciones** (primera) — botones 👁️ Ver y ✏️ Editar.
2. Fecha, Estado, Prioridad, Categoría.
3. Asunto, Descripción.
4. Notificados, **Origen**.
5. Fecha Resolución, Usuario Resolución, Notas Resolución.

### Acciones por fila

Una sola acción visible: **👁 Ver y resolver alerta** (icono Eye, ghost, centrado en la columna). Abre el modal unificado `AlertaModal` que internamente concentra todo el flujo:

- Previsualización del HTML del correo (con zoom).
- Previsualización del adjunto (PDF, imagen, txt, xlsx, csv, etc.) inline en otro tab.
- Edición del estado y notas de resolución.
- Descarga del adjunto.

La columna "Acciones" tiene `text-align: center` aplicado solo dentro de `.payroll-sticky-table` (el header `th:first-child` y todas las celdas `td:first-child`), sin afectar otras tablas del sistema.

### Filas críticas (resaltado rojo)
Una fila se resalta con fondo rojo suave + barra lateral roja izquierda cuando cumple **las tres** condiciones simultáneamente:

- `prioridad` (case-insensitive) === `Alta`.
- `estado` ∈ `{A, P, E}` (Activa / En Proceso / Error).
- `descripcion` (clasificada) ∈ `{Con Novedad, Error Proceso}`.

Implementación: helper top-level `isCriticalRow(row)` que se evalúa por fila; aplica clase `payroll-row--critical` al `<tr>`. CSS:

```css
.payroll-sticky-table .table tbody tr.payroll-row--critical td {
  background-color: rgba(239, 68, 68, 0.10);
}
.payroll-sticky-table .table tbody tr.payroll-row--critical:hover td {
  background-color: rgba(239, 68, 68, 0.18);
}
.payroll-sticky-table .table tbody tr.payroll-row--critical td:first-child {
  box-shadow: inset 3px 0 0 #ef4444;
}
```

## Modal unificado `AlertaModal`

Componente único que reemplaza al antiguo `PreviewModal` y al modal de edición separado. Concentra previsualización + edición + adjunto en una sola pantalla.

**Estructura general:**
```
┌──────────────────────────────────────────────────────────┐
│ Header: título + zoom (solo en tab Correo) + cerrar      │
├──────────────────────────────────────────┬───────────────┤
│ [Tabs: Correo] [Adjunto: nombre.ext]     │ Resolución    │
├──────────────────────────────────────────┤ ─ meta        │
│                                          │ ─ select      │
│  iframe (correo HTML o adjunto)          │ ─ textarea    │
│                                          │ ─ usuario     │
│                                          ├───────────────┤
│                                          │ Adjunto       │
│                                          │ nombre 👁 ⬇   │
│                                          ├───────────────┤
│                                          │ Cancel/Guardar│
└──────────────────────────────────────────┴───────────────┘
```

### Tabs Correo / Adjunto

Estilo "carpeta" (esquinas superiores redondeadas, fondo blanco en activa, línea inferior de 3px en color primario). El tab "Adjunto" solo aparece cuando `row.rutaAdjunto` existe. Click en el tab Adjunto dispara la carga del blob (lazy) y cambia el panel izquierdo para mostrar el adjunto inline. El click en el botón "Previsualizar" del panel lateral hace lo mismo: cambia al tab Adjunto en lugar de abrir nueva pestaña.

### Tab Correo
- `<iframe sandbox="allow-popups allow-popups-to-escape-sandbox allow-top-navigation-by-user-activation" srcDoc={doc}>` con la columna `descripcionHtml` envuelta por `buildPreviewDocument(html)` (charset utf-8 + estilos base). Los permisos permiten que los links del correo abran en nueva pestaña; scripts siguen bloqueados. Fix aplicado en commit `cb86fb2` (2026-05-29).
- **Zoom 25-300%** en pasos de 25% (botones + Ctrl+rueda). Default 100%, reset al cambiar de fila.
- Escalado con `transform: scale(N)` sobre el iframe; el stage wrapper se dimensiona en `BASE_W × scale × BASE_H × scale` para que los scrollbars reflejen el tamaño real escalado. `BASE_W = 800`, `BASE_H = 1100`.

### Tab Adjunto

Estado interno con cuatro fases (`adjuntoState.status`):

| Fase | Cuándo | UI |
|---|---|---|
| `idle` | Antes de cargar | Vacío (no se renderiza nada) |
| `loading` | Mientras `payrollService.previewAdjunto` corre | "Cargando adjunto…" |
| `ready` | Blob recibido y previewable | Iframe con `src={objectURL}`, MIME correcto |
| `unsupported` | Tipo no previewable (ej. .docx, .zip) | Mensaje + botón "Descargar adjunto" |
| `error` | Fallo de red/servidor | Mensaje + botón "Reintentar" |

Tipos previsualizables (definidos en `payrollService.js`):
- **Directos** (blob → iframe con MIME): `pdf, png, jpg, jpeg, gif, webp, svg, bmp, txt, json, xml, html`.
- **Procesados con SheetJS** (`@e965/xlsx`): `xlsx, xls, xlsm, ods, csv, tsv` → se parsean en cliente y se genera un documento HTML completo con tabs por hoja, tabla por sheet (`XLSX.utils.sheet_to_html`) + script mínimo de navegación. Ese HTML se envuelve en un Blob `text/html` que el iframe renderiza.

El `objectURL` del blob se guarda en `adjuntoState.url` y se libera con `URL.revokeObjectURL` en cleanup (al cerrar el modal o al cambiar de fila).

### Panel lateral derecho

Ancho 420px (360px ≤1100, 100% apilado ≤900). Contiene:

**Sección "Resolución"** (h3 con barra lateral 3px en color primario, look de título de sección):
- **Meta** (Estado actual / Prioridad / Categoría) en `font-size-sm`.
- **Select "Cambiar estado"**: opciones P (En Proceso), R (Resuelto), E (Error). Default basado en el estado actual de la fila.
- **Textarea "Notas de resolución"**: `rows={12}`, `min-height: 200px`, `resize: vertical`, `maxLength={500}` con doble defensa (`onChange` aplica `slice(0,500)` por si pegan texto). Contador `X / 500 caracteres` debajo, alineado a la derecha; cambia a amarillo (≥450) y rojo bold (=500) con `aria-live="polite"`.
- **Input readonly "Usuario resolución"** con el email de la sesión.

**Sección "Adjunto"**: una sola fila con fondo gris claro, nombre del archivo a la izquierda (truncado con ellipsis + tooltip nativo si es muy largo), e iconos 👁/⬇ a la derecha (mismo patrón ghost que la columna acciones de la tabla). Si no hay adjunto, muestra "Sin adjunto" en cursiva gris.

**Footer**: botones Cancelar y Guardar cambios (con `Swal.fire` de confirmación antes de hacer PATCH a DAB).

### Tipografía del panel

Se forzó `font-family: 'Inter', ...` con `!important` en `input`, `select`, `option`, `textarea`, `button`, `.form-control` dentro de `.preview-modal__side`. Los `<input>` no heredan font-family por defecto y respetan reglas UA; sin `!important` algunos navegadores los renderaban con su fuente del sistema, dando la sensación de "fuente diferente" entre los inputs y el resto del panel. Los `.form-label` mantienen el patrón notched del design system (`10px UPPERCASE bold gris`) para coincidencia con Tareas.

### Comportamiento general
- Overlay `position: fixed; inset: 0` con fondo `rgba(0,0,0,0.65)`, **z-index**: `var(--z-modal, 1050)` — necesario para quedar **sobre el header** del layout (que usa `--z-fixed: 1030`).
- Cierre con: botón X (deshabilitado mientras `saving=true`), tecla `Esc` (listener global, ignorado mientras se guarda), click en el overlay (solo si `target === currentTarget` y `!saving`).
- `document.body.style.overflow = 'hidden'` mientras está abierto. Foco inicial en el botón Cerrar.

### Título del modal
Formato: `{asunto || "Alerta #id"} — {fechaCreacion dd/mm/yyyy HH:mm}`.

## Responsive
- ≤1024px: KPIs a 3 columnas, gráficos a 1 columna.
- ≤640px: KPIs a 2 columnas, donut apilado, toolbar apilada, **modal a 100vw/100vh sin border-radius**, textos del zoom reducidos.

## Accesibilidad
- `aria-label` en iconos y botones.
- `aria-sort` en `<th>` ordenables.
- `aria-modal="true"` y `aria-label` con el título en el contenedor del modal.
- `focus-visible` con outline del color primario en botones de sort, zoom y cerrar.
- `aria-live="polite"` en el contador de resultados.

## Descarga de adjuntos

El proyecto `AlertasSistema` (otro repo) sube los archivos adjuntos de los correos a Azure Blob Storage vía la API interna de Dennis Suárez (`utileriaspayroll.azurewebsites.net/api/Documentos/`). En `Avisos.notificacionesConsolidadas` quedan persistidas dos columnas:

| Columna | Tipo | Contenido |
|---|---|---|
| `rutaAdjunto` | VARCHAR(1000) NULL | Ruta relativa del blob, p. ej. `AdjuntoAlertas/ReporteMarcajes.xlsx` |
| `nombreAdjunto` | VARCHAR(300) NULL | Nombre amigable para el usuario, p. ej. `ReporteMarcajes.xlsx` |

### Flujo

```
Usuario click ⬇️ en fila
   │
   ▼
GET /api/alertas-payroll/adjunto?ruta=...&nombre=...
   ▼  (bsc_backend, [Authorize], anexa UTILERIAS_TOKEN del .env)
GET https://utileriaspayroll.azurewebsites.net/api/Documentos/VerArchivosPdf
    ?nombreArchivo=...&token=...&tipo=D
   ▼
FileStreamResult → blob → <a download="..."> en el browser
```

### Por qué proxy en backend (no llamada directa desde React)

- El `UTILERIAS_TOKEN` no se expone al frontend (vive en `.env` del contenedor `bsc_backend`).
- El JWT de BSC valida que el usuario está autenticado; auditoría futura (quién descargó qué) queda viable.
- Se evitan problemas de CORS contra el dominio de Azure.

### Componentes

- Backend: `BSC.API/Controllers/AlertasPayrollController.cs` + `BSC.Application/Queries/DescargarAdjunto/` + `BSC.Infrastructure/Services/UtileriasPayrollClient.cs`.
- Frontend: `payrollService.descargarAdjunto({ rutaAdjunto, nombreAdjunto })` y tercer botón ghost (`Download` de lucide-react) en `table__actions`. Si `rutaAdjunto` es null/vacío el botón queda `disabled` con tooltip "Sin adjunto".

### Variables de entorno (`bsc_backend`)

```
UTILERIAS_API_BASE=https://utileriaspayroll.azurewebsites.net/api/Documentos/
UTILERIAS_TOKEN=<token de Dennis>
```

### Detalle del API externo a tener en cuenta

- El endpoint se llama `VerArchivosPdf` por legado, pero **acepta cualquier tipo de archivo** (xlsx, docx, zip, pdf, etc.).
- A pesar de eso, **siempre responde `Content-Type: application/pdf`** sin importar el archivo real.
- Para el flujo de **descarga** que tenemos hoy esto **no es problema**: el frontend usa `<a download="<nombreAdjunto>">`, así que el browser y el SO asocian el archivo por su extensión real (Excel abre `.xlsx`, etc.). El content-type del response no se usa.
- **Si en el futuro agregamos preview inline** (consumiendo `tipo=V` en vez de `tipo=D`), entonces sí hay que mapear el MIME real desde la extensión en `UtileriasPayrollClient.DescargarAsync` antes de devolver el `AdjuntoDescargado`. Ejemplo de mapping mínimo: `.xlsx` → `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `.docx` → `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, fallback → `application/octet-stream`. Sin ese mapping, el browser podría intentar abrir un xlsx como PDF y fallar al renderizar inline.

### Validación de seguridad

`DescargarAdjuntoValidator` rechaza rutas con `..`, rutas absolutas (`/...`) o con `:` para evitar path traversal contra el API externo, dado que la `ruta` viene como query param controlado por el cliente.

## Deploy

El frontend es build estático servido por `nginx` desde `./html/` (volumen del contenedor `bsc_frontend`).

```bash
cd frontend && npx vite build
rm -rf ../html/assets && cp -r dist/assets ../html/
cp dist/index.html ../html/index.html
docker restart bsc_frontend
```

> TODO: valdría la pena agregar un script `npm run deploy` que empaquete este flujo.
