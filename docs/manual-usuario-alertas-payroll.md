# Manual de Usuario — Módulo Alertas Payroll

**Sistema:** BSC BackOffice  
**Módulo:** Alertas Payroll  
**Versión:** 1.1  
**Fecha:** 2026-06-18  
**Dirigido a:** Analistas y Supervisores de Nómina / Payroll

---

## Tabla de Contenidos

1. [Introducción](#1-introducción)
2. [Acceso al módulo](#2-acceso-al-módulo)
3. [Vista general de la página](#3-vista-general-de-la-página)
4. [Tab Dashboard](#4-tab-dashboard)
   - 4.1 [Filtros del Dashboard](#41-filtros-del-dashboard)
   - 4.2 [Resumen de resultados](#42-resumen-de-resultados)
   - 4.3 [Tarjetas por tipo de descripción](#43-tarjetas-por-tipo-de-descripción)
   - 4.4 [Gráfico de alertas vs tiempo](#44-gráfico-de-alertas-vs-tiempo)
5. [Tab Listado](#5-tab-listado)
   - 5.1 [KPIs de estado](#51-kpis-de-estado)
   - 5.2 [Gráficos del Listado](#52-gráficos-del-listado)
   - 5.3 [Filtros de la tabla](#53-filtros-de-la-tabla)
   - 5.4 [Tabla de alertas](#54-tabla-de-alertas)
   - 5.5 [Paginación](#55-paginación)
   - 5.6 [Botón Actualizar](#56-botón-actualizar)
   - 5.7 [Descarga XLSX](#57-descarga-xlsx)
6. [Modal de alerta — Ver y Resolver](#6-modal-de-alerta--ver-y-resolver)
   - 6.1 [Tab Correo](#61-tab-correo)
   - 6.2 [Tab Adjunto](#62-tab-adjunto)
   - 6.3 [Panel de Resolución](#63-panel-de-resolución)
   - 6.4 [Guardar cambios](#64-guardar-cambios)
7. [Estados y prioridades](#7-estados-y-prioridades)
8. [Alertas críticas](#8-alertas-críticas)
9. [Preguntas frecuentes](#9-preguntas-frecuentes)

---

## 1. Introducción

El módulo **Alertas Payroll** es el centro de notificaciones del sistema BSC BackOffice. Consolida en una sola pantalla todas las alertas generadas automáticamente por los procesos de nómina: validaciones de marcajes, vacaciones, ausencias, jerarquías, biométricos, horarios, entre otros.

Las alertas se generan desde procedimientos almacenados (SP) que se ejecutan periódicamente y depositan sus resultados en la base de datos. Desde este módulo el equipo de Payroll puede:

- Monitorear el estado general de las alertas en tiempo real.
- Filtrar y buscar alertas por cualquier criterio.
- Previsualizar el contenido del correo que se envió a los involucrados.
- Revisar y descargar archivos adjuntos (reportes, listados).
- Registrar la resolución de cada alerta con notas y cambio de estado.
- Descargar reportes en Excel con formato profesional.

---

## 2. Acceso al módulo

1. Inicie sesión en BSC BackOffice con sus credenciales corporativas.
2. En el menú lateral izquierdo, haga clic en **"Alertas Payroll"**.
3. El sistema cargará automáticamente todas las alertas registradas, mostrando primero el **Tab Dashboard**.

> **Nota:** Si es la primera vez que accede o acaba de iniciar sesión, espere unos segundos mientras el sistema carga los datos desde el servidor.

> **Permisos:** La opción **"Alertas Payroll"** en el menú lateral solo aparece para los roles que tienen habilitado el módulo. Si no la ve, su rol no tiene acceso a este módulo; solicite la habilitación al administrador. Si tiene varios roles, el acceso depende del **rol activo** (puede cambiarlo desde el menú de usuario).

---

## 3. Vista general de la página

La página se divide en dos grandes secciones accesibles mediante pestañas (tabs) ubicadas bajo el encabezado:

| Tab | Descripción |
|-----|-------------|
| **Dashboard** | Visión ejecutiva: KPIs por tipo de alerta y gráfico de tendencia temporal |
| **Listado** | Tabla detallada de todas las alertas con filtros, acciones y descarga |

Ambas pestañas trabajan sobre el mismo conjunto de datos cargado al ingresar al módulo, pero mantienen sus propios filtros de forma independiente.

---

## 4. Tab Dashboard

El Dashboard ofrece una vista gerencial del estado de las alertas agrupadas por su **tipo de descripción**.

### 4.1 Filtros del Dashboard

En la barra de filtros superior del Dashboard encontrará:

| Filtro | Descripción |
|--------|-------------|
| **Prioridad** | Filtra por nivel: Crítica, Alta, Media, Baja |
| **Categoría** | Filtra por área de negocio (Biométricos, Vacaciones, Marcajes, etc.) |
| **Estado** | Filtra por estado de la alerta |
| **Fecha** | Rango de fechas sobre `Fecha de Creación`. Haga clic en el botón para abrir el selector de rango; haga clic en la **X** integrada para limpiar el rango sin abrir el selector |
| **Agrupación temporal** | Segmento Día / Semana / Mes: controla cómo se agrupan las barras en el gráfico de tiempo |
| **Limpiar filtros** | Restablece todos los filtros del Dashboard, incluyendo el rango de fechas |

### 4.2 Resumen de resultados

Sobre las tarjetas verá un texto como:

```
42 filtradas · 38 clasificadas · 4 sin clasificar
```

- **Filtradas:** total de alertas que pasan los filtros activos.
- **Clasificadas:** alertas con tipo de descripción reconocido (Con novedad / Sin novedad / Reportería / Error Proceso).
- **Sin clasificar:** aparece resaltado en amarillo si existen alertas con una descripción no reconocida.

### 4.3 Tarjetas por tipo de descripción

Hay cuatro tarjetas, una por cada tipo de alerta:

| Tipo | Color de acento |
|------|-----------------|
| **Con novedad** | Rojo |
| **Sin novedad** | Verde |
| **Reportería** | Azul |
| **Error Proceso** | Amarillo |

Cada tarjeta muestra:
- Un gráfico **donut** con el total de alertas de ese tipo.
- El número central (total del tipo).
- El **porcentaje del total** de alertas filtradas (número grande en el color de la tarjeta).

### 4.4 Gráfico de alertas vs tiempo

El gráfico de barras apiladas en la parte inferior muestra la evolución temporal de las alertas.

- El **eje X** agrupa las alertas según el selector Día/Semana/Mes.
- Cada color de barra corresponde a un tipo de descripción (los mismos colores que las tarjetas).
- **Haga clic en una barra** para descargar automáticamente un archivo Excel con las alertas de ese período y tipo específico, aplicando además los filtros activos.

---

## 5. Tab Listado

El Listado ofrece la tabla completa de alertas con todas las opciones de filtrado, ordenamiento y acciones por registro.

### 5.1 KPIs de estado

En la parte superior del Listado encontrará 6 tarjetas con conteos por estado:

| Tarjeta | Estado que cuenta |
|---------|-------------------|
| **Total** | Todas las alertas (con filtro de fecha activo) |
| **Activas** | Estado `A` |
| **En Proceso** | Estado `P` |
| **Resueltas** | Estado `R` |
| **Cerradas** | Estado `C` |
| **Error** | Estado `E` |

> Los KPIs se actualizan al aplicar el filtro de fecha del Listado.

### 5.2 Gráficos del Listado

Bajo los KPIs hay tres gráficos:

**Pendientes por Resolver (donut)**  
Muestra solo las alertas en estado Activa, En Proceso o Error, agrupadas por **prioridad**: Alta (rojo), Media (amarillo) y Baja (verde). La etiqueta central indica "Pendientes" y cada segmento de la leyenda muestra su cantidad y porcentaje. Permite ver de un vistazo cuántos pendientes hay de cada nivel de urgencia.

**Distribución por Estado (donut)**  
Muestra la proporción de todos los estados (A, P, R, C, E).

**Alertas por Categoría (barras horizontales)**  
Muestra cuántas alertas hay por cada categoría de negocio. Encima del gráfico hay **chips** (filtros visuales) para mostrar u ocultar tipos:

- Cada chip se activa/desactiva con un clic.
- El botón al final alterna entre **"Limpiar"** (cuando todos están activos) y **"Todas"** (cuando hay alguno desactivado).
- Si la combinación seleccionada no tiene datos, se muestra un mensaje vacío.

### 5.3 Filtros de la tabla

La toolbar de la tabla ofrece múltiples mecanismos de filtrado que se aplican en tiempo real:

**Búsqueda global**  
Campo de texto con ícono de lupa. Busca en todas las columnas simultáneamente (la coincidencia es en cualquier columna, no requiere coincidir en todas).

**Filtro por fecha**  
Botón con ícono de calendario. Al hacer clic abre un selector de rango de fechas sobre el campo `Fecha Creación`. El botón muestra el rango seleccionado (ej. `01/05/2026 – 31/05/2026`). La **X** integrada limpia el rango sin abrir el selector.

**Filtros por columna**  
En la segunda fila del encabezado de la tabla hay un campo de texto por cada columna. Filtra específicamente esa columna. Todos los filtros por columna se aplican en conjunto (AND).

**Botón "Limpiar filtros"**  
Restablece la búsqueda global, todos los filtros por columna y el rango de fechas en un solo clic. Se deshabilita automáticamente cuando no hay filtros activos.

**Contador de resultados**  
A la derecha de la toolbar se muestra `X de Y` alertas, donde X es el total filtrado y Y el total cargado.

### 5.4 Tabla de alertas

La tabla presenta las siguientes columnas:

| Columna | Descripción |
|---------|-------------|
| **Acciones** | Botón para ver y resolver la alerta |
| **Fecha Creación** | Fecha y hora en que se generó la alerta |
| **Estado** | Estado actual (Activa / En Proceso / Resuelta / Cerrada / Error) |
| **Prioridad** | Nivel de urgencia (Crítica / Alta / Media / Baja) |
| **Categoría** | Área de negocio que originó la alerta |
| **Asunto** | Asunto del correo de notificación |
| **Descripción** | Tipo de alerta (Con novedad / Sin novedad / Reportería / Error Proceso) |
| **Notificados** | Destinatarios del correo |
| **Origen** | Sistema o proceso que generó la alerta |
| **Fecha Resolución** | Fecha en que se marcó como resuelta (si aplica) |
| **Usuario Resolución** | Quién registró la resolución |
| **Notas Resolución** | Observaciones ingresadas al resolver |

**Ordenamiento:**  
Haga clic en el encabezado de cualquier columna para ordenar. Cada clic cicla entre: ascendente → descendente → sin orden. Las columnas de fecha se ordenan cronológicamente; las de texto usan orden alfabético en español.

**Orden prioritario automático:**  
Independientemente del orden que elija, las alertas más urgentes —**Prioridad Alta + Con Novedad + Activas**— se fijan siempre al inicio de la tabla, para que no se pierdan entre páginas. El resto de las filas conserva el orden de la columna elegida (o el orden original si no ha ordenado por ninguna).

### 5.5 Paginación

Bajo la tabla encontrará los controles de paginación:

- **Filas por página:** selector con opciones 10, 20, 50, 100, 200 (el valor por defecto es 20).
- **Navegación:** botones Primera / Anterior / Siguiente / Última página.
- **Indicador:** `X–Y de Z` muestra el rango visible y el total filtrado.
- Al cambiar cualquier filtro, la tabla regresa automáticamente a la primera página.

### 5.6 Botón Actualizar

El botón **"Actualizar"** (ícono de flechas circulares, junto al botón Descargar) recarga los datos desde el servidor sin necesidad de refrescar toda la página.

- Durante la carga, el ícono gira y el botón se deshabilita temporalmente.
- Úselo cuando sospeche que hay alertas nuevas que aún no se ven, o tras un período de inactividad.

> **Consejo:** Si trabaja el módulo durante toda la jornada, use "Actualizar" cada cierto tiempo para asegurarse de ver las alertas más recientes.

### 5.7 Descarga XLSX

El botón **"Descargar"** (azul, con ícono de descarga) genera un archivo Excel con las alertas visibles según los filtros activos.

- Si no hay filtros activos, descarga **todas** las alertas cargadas.
- Si hay filtros activos, descarga únicamente el **subconjunto filtrado completo** (no solo la página visible).
- El nombre del archivo tiene el formato: `Alertas_YYYY-MM-DD.xlsx`.

**Formato del archivo:**

| Elemento | Estilo |
|----------|--------|
| Encabezado | Fondo azul oscuro `#1F4E79`, texto blanco, negrita |
| Filas pares | Fondo azul suave `#EBF3FB` |
| Filas impares | Fondo blanco |
| Bordes | Líneas finas en todas las celdas |
| Encabezado fijo | Primera fila congelada (al desplazarse verticalmente, el encabezado permanece visible) |

**Columnas incluidas en el Excel:**

ID · Fecha Creación · Estado · Prioridad · Categoría · Asunto · Descripción · Notificados · Origen · Fecha Resolución · Usuario Resolución · Notas Resolución

---

## 6. Modal de alerta — Ver y Resolver

Al hacer clic en el botón **👁 Ver** de cualquier fila, se abre el modal de detalle. Este modal concentra toda la información y las acciones posibles sobre una alerta.

**Título del modal:** `{Asunto de la alerta} — {Fecha de creación dd/mm/yyyy HH:mm}`

El modal tiene dos áreas principales:

- **Panel izquierdo (mayor):** previsualización del contenido.
- **Panel derecho (lateral):** información de resolución y adjunto.

### 6.1 Tab Correo

Es la vista predeterminada al abrir el modal. Muestra el HTML del correo de notificación que fue enviado a los destinatarios.

**Controles de zoom** (en el encabezado del modal):

| Control | Acción |
|---------|--------|
| Botón **−** | Reduce el zoom un paso (mínimo 25%) |
| Porcentaje (ej. `100%`) | Indicador del zoom actual |
| Botón **+** | Aumenta el zoom un paso (máximo 300%) |
| `Ctrl + rueda del ratón` | Zoom rápido con el scroll del mouse |

El zoom se restablece a 100% automáticamente al abrir una alerta diferente.

**Links en el correo:**  
Si el correo contiene enlaces (por ejemplo, en alertas de Cargas Familiares), puede hacer clic directamente sobre ellos y se abrirán en una nueva pestaña del navegador.

### 6.2 Tab Adjunto

Si la alerta tiene un archivo adjunto, aparecerá el tab **"Adjunto: nombre-del-archivo.ext"**.

Al hacer clic en el tab (o en el botón 👁 del panel lateral), el sistema descarga y muestra el archivo directamente dentro del modal:

| Tipo de archivo | Comportamiento |
|-----------------|----------------|
| PDF | Visualización inline como PDF |
| Imágenes (PNG, JPG, GIF, WebP, SVG) | Visualización inline de la imagen |
| Texto (TXT, JSON, XML, HTML) | Visualización del contenido como texto |
| Excel/CSV (XLSX, XLS, CSV, TSV) | Tabla interactiva con tabs por hoja |
| Otros formatos (DOCX, ZIP, etc.) | Mensaje con botón "Descargar adjunto" |

> Si el archivo no puede cargarse por error de red, aparecerá un botón **"Reintentar"**.

### 6.3 Panel de Resolución

En el panel lateral derecho se encuentra la información de gestión de la alerta:

**Sección "Resolución"**

| Campo | Descripción |
|-------|-------------|
| **Estado actual** | Estado vigente de la alerta |
| **Prioridad** | Nivel de prioridad |
| **Categoría** | Área de negocio |
| **Cambiar estado** | Selector para actualizar el estado: En Proceso, Resuelto, Error |
| **Notas de resolución** | Texto libre para registrar observaciones (máximo 500 caracteres). El contador cambia a amarillo al superar 450 y a rojo al llegar a 500 |
| **Usuario resolución** | Se completa automáticamente con su email de sesión |

**Sección "Adjunto"**

Muestra el nombre del archivo adjunto (si existe) con dos botones:

| Botón | Acción |
|-------|--------|
| 👁 (ojo) | Abre el tab Adjunto para previsualizar el archivo |
| ⬇ (descarga) | Descarga el archivo directamente a su computador |

Si no hay adjunto, se muestra "Sin adjunto" en gris.

### 6.4 Guardar cambios

El botón **"Guardar cambios"** (azul) registra el nuevo estado y las notas de resolución en el sistema.

- Antes de guardar, el sistema pide confirmación.
- El botón **"Cancelar"** cierra el modal sin guardar ningún cambio.
- También puede cerrar el modal con la tecla `Esc` o haciendo clic fuera del modal (en el fondo oscuro).

> **Importante:** Los cambios de estado son visibles para todos los usuarios del sistema de forma inmediata tras guardar.

---

## 7. Estados y prioridades

### Estados de una alerta

| Código | Etiqueta | Significado |
|--------|----------|-------------|
| `A` | **Activa** | Recién generada, pendiente de revisión |
| `P` | **En Proceso** | Alguien está trabajando en ella |
| `R` | **Resuelta** | Fue atendida y cerrada exitosamente |
| `C` | **Cerrada** | Cerrada sin resolución (informativa o descartada) |
| `E` | **Error** | Ocurrió un error durante el procesamiento |

### Prioridades

| Prioridad | Significado |
|-----------|-------------|
| **Crítica** | Requiere atención inmediata |
| **Alta** | Debe atenderse con urgencia |
| **Media** | Atención en tiempo regular |
| **Baja** | Informativa, sin urgencia |

---

## 8. Alertas críticas

Las filas que cumplen las tres condiciones siguientes se resaltan con fondo rojo y una barra lateral izquierda roja:

1. **Prioridad:** Alta (o Crítica).
2. **Estado:** Activa, En Proceso o Error.
3. **Tipo:** Con Novedad o Error Proceso.

Estas alertas requieren atención prioritaria. El resaltado visual facilita su identificación rápida en la tabla, incluso entre muchos registros.

> Además, el subconjunto más urgente —**Prioridad Alta + Con Novedad + Activas**— se fija automáticamente al inicio de la tabla del Listado (ver [5.4](#54-tabla-de-alertas)), de modo que aparece primero sin importar el orden o la página en que se encuentre.

---

## 9. Preguntas frecuentes

**¿Con qué frecuencia se generan nuevas alertas?**  
Las alertas se generan cuando los SPs de nómina se ejecutan. La frecuencia depende de la configuración de cada proceso. Use el botón **Actualizar** para ver las alertas más recientes sin recargar la página.

**¿Puedo descargar solo las alertas que busqué?**  
Sí. Aplique los filtros que necesite (fecha, estado, prioridad, búsqueda por texto) y luego haga clic en **Descargar**. El Excel contendrá únicamente las alertas filtradas, no toda la base.

**¿Al cambiar el estado de una alerta, se notifica a alguien?**  
El cambio de estado queda registrado en el sistema con su usuario y fecha de modificación. Las notificaciones automáticas hacia terceros dependen de la configuración de cada proceso.

**¿Puedo previsualizar el correo antes de que llegue a los destinatarios?**  
El correo ya fue enviado cuando la alerta aparece en el sistema. La previsualización en el modal muestra exactamente lo que recibieron los destinatarios.

**¿Por qué algunos links del correo no funcionan?**  
Los links dentro del preview del correo se abren en una nueva pestaña. Si el link apunta a un sistema interno, asegúrese de tener acceso a la red corporativa.

**¿Qué significa "Sin clasificar" en el resumen del Dashboard?**  
Hay alertas cuya descripción no coincide con ninguno de los cuatro tipos reconocidos (Con novedad / Sin novedad / Reportería / Error Proceso). Esto puede indicar un tipo nuevo o un valor inesperado. Informe al equipo técnico si ve este indicador frecuentemente.

**¿Puedo deshacer una resolución registrada?**  
Puede cambiar el estado nuevamente a `Activa` o cualquier otro estado abriendo el modal y guardando los cambios. No hay restricción de transición de estados desde la interfaz.

---

*Manual generado para BSC BackOffice — Módulo Alertas Payroll v1.1 | 2026-06-18*
