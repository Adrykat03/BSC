import jsPDF from 'jspdf';
import 'jspdf-autotable';

const RED = [227, 24, 55];
const DARK = [31, 41, 55];
const GRAY = [107, 114, 128];
const WHITE = [255, 255, 255];
const LIGHT_BG = [249, 250, 251];
const TIP_BG = [254, 243, 199];
const TIP_BORDER = [245, 158, 11];
const NOTE_BG = [219, 234, 254];
const NOTE_BORDER = [59, 130, 246];
const TABLE_HEADER = RED;
const TABLE_EVEN = [243, 244, 246];

const PAGE_W = 210;
const PAGE_H = 297;
const MARGIN = 16;
const CONTENT_W = PAGE_W - MARGIN * 2;
const FOOTER_Y = PAGE_H - 10;

export function generateManualPdf() {
  const doc = new jsPDF('p', 'mm', 'a4');
  let y = 0;

  // ── Helpers ──
  const addFooter = () => {
    const pageCount = doc.internal.getNumberOfPages();
    for (let i = 2; i <= pageCount; i++) {
      doc.setPage(i);
      doc.setFontSize(9);
      doc.setTextColor(...GRAY);
      doc.text(`FlowPulse - Manual de Usuario`, MARGIN, FOOTER_Y);
      doc.text(`Pagina ${i - 1}`, PAGE_W - MARGIN, FOOTER_Y, { align: 'right' });
    }
  };

  const checkSpace = (needed) => {
    if (y + needed > PAGE_H - 20) {
      doc.addPage();
      y = MARGIN;
    }
  };

  const heading2 = (text) => {
    doc.addPage();
    y = MARGIN;
    doc.setFontSize(22);
    doc.setTextColor(...RED);
    doc.setFont('helvetica', 'bold');
    doc.text(text, MARGIN, y);
    y += 4;
    doc.setDrawColor(...RED);
    doc.setLineWidth(0.7);
    doc.line(MARGIN, y, PAGE_W - MARGIN, y);
    y += 10;
  };

  const heading3 = (text) => {
    checkSpace(16);
    doc.setFontSize(15);
    doc.setTextColor(...DARK);
    doc.setFont('helvetica', 'bold');
    doc.text(text, MARGIN, y);
    y += 8;
  };

  const heading4 = (text) => {
    checkSpace(14);
    doc.setFontSize(12);
    doc.setTextColor(75, 85, 99);
    doc.setFont('helvetica', 'bold');
    doc.text(text, MARGIN, y);
    y += 7;
  };

  const para = (text) => {
    doc.setFontSize(10.5);
    doc.setTextColor(...DARK);
    doc.setFont('helvetica', 'normal');
    const lines = doc.splitTextToSize(text, CONTENT_W);
    checkSpace(lines.length * 5 + 4);
    doc.text(lines, MARGIN, y);
    y += lines.length * 5 + 4;
  };

  const bulletList = (items) => {
    doc.setFontSize(10.5);
    doc.setTextColor(...DARK);
    doc.setFont('helvetica', 'normal');
    items.forEach((item) => {
      const lines = doc.splitTextToSize(item, CONTENT_W - 8);
      checkSpace(lines.length * 5 + 2);
      doc.text('•', MARGIN + 2, y);
      doc.text(lines, MARGIN + 8, y);
      y += lines.length * 5 + 2;
    });
    y += 3;
  };

  const numberedList = (items) => {
    doc.setFontSize(10.5);
    doc.setTextColor(...DARK);
    doc.setFont('helvetica', 'normal');
    items.forEach((item, i) => {
      const lines = doc.splitTextToSize(item, CONTENT_W - 10);
      checkSpace(lines.length * 5 + 2);
      doc.text(`${i + 1}.`, MARGIN + 1, y);
      doc.text(lines, MARGIN + 10, y);
      y += lines.length * 5 + 2;
    });
    y += 3;
  };

  const tipBox = (text, type = 'tip') => {
    const bg = type === 'tip' ? TIP_BG : NOTE_BG;
    const border = type === 'tip' ? TIP_BORDER : NOTE_BORDER;
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    const lines = doc.splitTextToSize(text, CONTENT_W - 12);
    const h = lines.length * 5 + 10;
    checkSpace(h + 4);
    doc.setFillColor(...bg);
    doc.roundedRect(MARGIN, y - 2, CONTENT_W, h, 1, 1, 'F');
    doc.setFillColor(...border);
    doc.rect(MARGIN, y - 2, 1.5, h, 'F');
    doc.setTextColor(...DARK);
    doc.text(lines, MARGIN + 6, y + 4);
    y += h + 5;
  };

  const table = (headers, rows) => {
    checkSpace(20);
    doc.autoTable({
      startY: y,
      head: [headers],
      body: rows,
      margin: { left: MARGIN, right: MARGIN },
      styles: { fontSize: 9, cellPadding: 3, textColor: DARK, lineWidth: 0 },
      headStyles: { fillColor: TABLE_HEADER, textColor: WHITE, fontStyle: 'bold', fontSize: 9 },
      alternateRowStyles: { fillColor: TABLE_EVEN },
      theme: 'plain',
    });
    y = doc.lastAutoTable.finalY + 6;
  };

  // ══════════════════════════════════════
  //  PORTADA
  // ══════════════════════════════════════
  doc.setFillColor(...RED);
  doc.rect(0, 0, PAGE_W, PAGE_H, 'F');
  doc.setTextColor(...WHITE);
  doc.setFontSize(48);
  doc.setFont('helvetica', 'bold');
  doc.text('FlowPulse', PAGE_W / 2, 100, { align: 'center' });
  doc.setFontSize(22);
  doc.setFont('helvetica', 'normal');
  doc.text('Manual de Usuario', PAGE_W / 2, 120, { align: 'center' });
  doc.setFontSize(14);
  doc.text('Sistema de Gestion de Tareas', PAGE_W / 2, 135, { align: 'center' });
  doc.text('y Alertas de Nomina', PAGE_W / 2, 145, { align: 'center' });
  doc.setFontSize(11);
  doc.setTextColor(255, 255, 255, 180);
  doc.text('Version 1.0 — Marzo 2026', PAGE_W / 2, 175, { align: 'center' });

  // ══════════════════════════════════════
  //  TABLA DE CONTENIDOS
  // ══════════════════════════════════════
  doc.addPage();
  y = MARGIN;
  doc.setFontSize(22);
  doc.setTextColor(...RED);
  doc.setFont('helvetica', 'bold');
  doc.text('Contenido', MARGIN, y);
  y += 12;

  const tocItems = [
    'Introduccion',
    'Inicio de Sesion',
    'Roles del Sistema',
    'Navegacion',
    'Dashboard',
    'Gestion de Tareas',
    'Calificacion de Tareas',
    'Carga de Evidencia',
    'Exportar e Importar Tareas',
    'Administracion de Roles',
    'Administracion de Colaboradores',
    'Alertas Payroll',
    'Notificaciones',
    'Flujo de Estados de Tareas',
    'Preguntas Frecuentes',
  ];

  doc.setFontSize(12);
  doc.setFont('helvetica', 'normal');
  tocItems.forEach((item, i) => {
    doc.setTextColor(...RED);
    doc.setFont('helvetica', 'bold');
    doc.text(`${i + 1}.`, MARGIN + 4, y);
    doc.setTextColor(...DARK);
    doc.setFont('helvetica', 'normal');
    doc.text(item, MARGIN + 16, y);
    y += 8;
  });

  // ══════════════════════════════════════
  //  1. INTRODUCCION
  // ══════════════════════════════════════
  heading2('1. Introduccion');
  para('FlowPulse es un sistema BackOffice para la gestion de tareas y monitoreo de alertas de nomina. Permite a los equipos organizar, asignar, dar seguimiento y calificar tareas de forma colaborativa, con controles diferenciados por rol.');
  para('El sistema cuenta con cuatro roles principales, cada uno con permisos y vistas especificas:');
  table(
    ['Rol', 'Descripcion'],
    [
      ['Administrador', 'Gestiona roles y colaboradores del sistema'],
      ['Gerente', 'Crea tareas, asigna lideres, aprueba completadas, ve dashboard completo'],
      ['Lider', 'Asigna colaboradores, valida tareas completadas, califica'],
      ['Colaborador', 'Ejecuta tareas, sube evidencia, envia a validacion'],
    ]
  );

  // ══════════════════════════════════════
  //  2. INICIO DE SESION
  // ══════════════════════════════════════
  heading2('2. Inicio de Sesion');
  para('Para acceder al sistema:');
  numberedList([
    'Ingrese a la URL del sistema en su navegador.',
    'Introduzca su correo electronico corporativo.',
    'Introduzca su contrasena.',
    'Haga clic en "Iniciar sesion".',
  ]);
  tipBox('Consejo: Si tiene multiples roles asignados, al iniciar sesion se activara el rol de mayor privilegio. Puede cambiar de rol desde el menu de usuario en la esquina superior derecha.');

  heading3('Cambiar de Rol');
  para('Si su cuenta tiene mas de un rol (por ejemplo, Lider y Colaborador):');
  numberedList([
    'Haga clic en su nombre en la esquina superior derecha.',
    'En el menu desplegable, seleccione el rol al que desea cambiar.',
    'La pagina se recargara con los permisos del nuevo rol.',
  ]);

  // ══════════════════════════════════════
  //  3. ROLES DEL SISTEMA
  // ══════════════════════════════════════
  heading2('3. Roles del Sistema');

  heading3('Administrador');
  bulletList([
    'Accede a: Roles, Colaboradores, Alertas Payroll',
    'No tiene acceso al Dashboard ni a Tareas',
    'Crea, edita y elimina roles y usuarios del sistema',
  ]);

  heading3('Gerente');
  bulletList([
    'Accede a: Dashboard, Tareas, Alertas Payroll',
    'Crea y edita tareas',
    'Asigna tareas a Lideres',
    'Aprueba tareas como "Completa" o las devuelve',
    'Cancela y restaura tareas',
    'Califica tareas (1-10 estrellas)',
    'Descarga reportes XLSX completos',
  ]);

  heading3('Lider');
  bulletList([
    'Accede a: Dashboard, Tareas, Alertas Payroll',
    'Edita tareas asignadas a el',
    'Asigna tareas a Colaboradores',
    'Valida tareas completadas y las envia al Gerente',
    'Reasigna tareas al Colaborador si requieren correccion',
    'Califica tareas (1-10 estrellas)',
  ]);

  heading3('Colaborador');
  bulletList([
    'Accede a: Dashboard (vista limitada), Tareas, Alertas Payroll',
    'Ve el detalle de las tareas asignadas',
    'Sube evidencia (archivos y texto)',
    'Envia tareas a validacion',
    'Ve la calificacion asignada por el Lider/Gerente',
  ]);

  // ══════════════════════════════════════
  //  4. NAVEGACION
  // ══════════════════════════════════════
  heading2('4. Navegacion');
  para('El sistema cuenta con una barra lateral (sidebar) de navegacion y una barra superior (header).');

  heading3('Barra Lateral');
  para('Muestra las opciones de menu segun su rol:');
  table(
    ['Menu', 'Administrador', 'Gerente', 'Lider', 'Colaborador'],
    [
      ['Dashboard', '-', 'Si', 'Si', 'Si'],
      ['Tareas', '-', 'Si', 'Si', 'Si'],
      ['Roles', 'Si', '-', '-', '-'],
      ['Colaboradores', 'Si', '-', '-', '-'],
      ['Alertas Payroll', 'Si', 'Si', 'Si', 'Si'],
    ]
  );

  heading3('Barra Superior');
  para('Contiene:');
  bulletList([
    'Titulo de la pagina actual (izquierda)',
    'Icono de ayuda — descarga este manual en PDF',
    'Campana de notificaciones — muestra el numero de tareas pendientes (Asignada o Reasignada)',
    'Menu de usuario — nombre, rol actual, cambio de rol y cerrar sesion',
  ]);

  // ══════════════════════════════════════
  //  5. DASHBOARD
  // ══════════════════════════════════════
  heading2('5. Dashboard');
  para('El Dashboard presenta un resumen estadistico de las tareas. El contenido varia segun su rol.');

  heading3('Filtros');
  bulletList([
    'Periodo: Seleccione "Todos" para ver datos historicos o "Rango de fechas" para filtrar por periodo especifico.',
    'Desde / Hasta: Aparecen al seleccionar rango de fechas.',
  ]);

  heading3('Componentes del Dashboard');
  table(
    ['Componente', 'Gerente', 'Lider', 'Colaborador'],
    [
      ['Tarjetas KPI (metricas clave)', 'Si', '-', '-'],
      ['Mapa de calor de carga laboral', 'Si', 'Si', '-'],
      ['Tiempo promedio por estado', 'Si', 'Si', 'Si'],
      ['Distribucion de tareas por estado', 'Si', 'Si', 'Si'],
      ['Tareas por colaborador y estado', 'Si', 'Si', 'Si'],
      ['Boton descargar reporte XLSX', 'Si', '-', '-'],
    ]
  );

  heading4('Descargar Reporte (solo Gerente)');
  para('Haga clic en el boton "Descargar Reporte" en la parte superior del Dashboard para exportar todas las tareas a un archivo Excel (.xlsx) con la siguiente informacion:');
  bulletList([
    'Titulo, Descripcion, Estado, Lider, Colaborador',
    'Fecha de entrega, Tiempos estimado y real',
    'Insumos, Observaciones, Evidencia',
    'Calificacion, Creado por, Fechas de creacion y actualizacion',
  ]);

  // ══════════════════════════════════════
  //  6. GESTION DE TAREAS
  // ══════════════════════════════════════
  heading2('6. Gestion de Tareas');

  heading3('Vista de la Tabla');
  para('La pagina de Tareas muestra una tabla con las siguientes columnas:');
  table(
    ['Columna', 'Descripcion'],
    [
      ['Titulo', 'Nombre de la tarea'],
      ['Asignado a', 'Nombre del colaborador (solo Gerente/Lider)'],
      ['Lider', 'Nombre del lider asignado'],
      ['Estado', 'Estado actual con indicador de color'],
      ['Entrega', 'Fecha limite de entrega'],
      ['Tiempo', 'Tiempo estimado en horas'],
      ['Calificacion', 'Estrellas de calificacion (1-10)'],
      ['Acciones', 'Botones de accion segun rol'],
    ]
  );

  heading4('Indicadores de Urgencia');
  bulletList([
    'Rojo: La tarea esta vencida o el tiempo restante es menor al estimado',
    'Naranja: La fecha de entrega se aproxima (entre 1 y 2 veces el tiempo estimado)',
    'Normal: La tarea tiene suficiente tiempo disponible',
  ]);

  heading4('Estados de una Tarea');
  table(
    ['Estado', 'Significado', 'Color'],
    [
      ['Creada', 'Tarea recien creada, sin asignar', 'Gris'],
      ['Asignada', 'Asignada a un lider o colaborador', 'Azul'],
      ['Completa - Por Validar', 'Completada, esperando validacion', 'Naranja'],
      ['Reasignada', 'Devuelta al colaborador para correccion', 'Rojo'],
      ['Completa - Validada', 'Validada por el lider, pendiente de aprobacion', 'Verde claro'],
      ['Completa', 'Aprobada por el gerente, finalizada', 'Verde'],
      ['Cancelada', 'Tarea cancelada', 'Rojo oscuro'],
    ]
  );

  heading3('Filtros y Busqueda');
  bulletList([
    'Buscar: Escriba cualquier texto para filtrar tareas por titulo o descripcion.',
    'Estado: Filtre por un estado especifico. Los estados visibles dependen de su rol.',
    'Fecha: Filtre por Hoy, Ayer, Esta semana o Todas.',
  ]);

  heading3('Crear una Tarea (Gerente / Lider)');
  numberedList([
    'Haga clic en el boton "+ Nueva Tarea".',
    'Complete los campos requeridos: Titulo (obligatorio), Descripcion (obligatorio), Fecha de entrega, Tiempo estimado (horas), Insumos, Archivos de insumo (max 20MB), Observaciones.',
    'Opcionalmente, seleccione un Lider para asignar inmediatamente.',
    'Haga clic en "Guardar".',
  ]);

  heading3('Editar una Tarea (Gerente / Lider)');
  numberedList([
    'Haga clic en el icono de lapiz en la fila de la tarea.',
    'Modifique los campos necesarios.',
    'Haga clic en "Guardar".',
  ]);
  tipBox('Nota: El Lider no puede modificar la fecha de entrega. Solo el Gerente puede hacerlo.', 'note');

  heading3('Asignar una Tarea');
  bulletList([
    'Gerente: Asigna a un Lider. Si ya tiene Lider, puede asignar directamente a un Colaborador.',
    'Lider: Asigna a un Colaborador desde el selector dentro del modal de edicion.',
  ]);

  heading3('Cambiar Estado de una Tarea');
  para('Los botones de cambio de estado aparecen en la parte inferior del modal:');
  table(
    ['Rol', 'Estado Actual', 'Puede cambiar a'],
    [
      ['Gerente', 'Completa - Validada', 'Completa, Reasignada, Completa - Por Validar'],
      ['Gerente', 'Asignada / CPV / Reasignada / CV', 'Cancelada'],
      ['Gerente', 'Cancelada', 'Restaurar'],
      ['Lider', 'Completa - Por Validar', 'Completa - Validada, Reasignada'],
      ['Colaborador', 'Asignada / Reasignada', 'Completa - Por Validar'],
    ]
  );

  heading3('Eliminar / Cancelar una Tarea (solo Gerente)');
  bulletList([
    'Tarea sin asignar: Se elimina permanentemente.',
    'Tarea asignada: Cambia a estado "Cancelada". Puede restaurarse posteriormente.',
  ]);

  heading3('Ver Historial de una Tarea');
  para('Haga clic en el icono de reloj en las acciones de la tarea. Se mostrara una linea de tiempo con todos los cambios de estado, incluyendo quien realizo el cambio y cuando.');

  // ══════════════════════════════════════
  //  7. CALIFICACION
  // ══════════════════════════════════════
  heading2('7. Calificacion de Tareas');
  para('El Lider y el Gerente pueden calificar tareas usando un sistema de 10 estrellas.');

  heading3('Como calificar');
  numberedList([
    'Abra la tarea (clic en editar o ver detalle).',
    'En la seccion "Calificacion", haga clic en la estrella correspondiente a la puntuacion deseada (1-10). Ejemplo: 7 estrellas amarillas y 3 grises = 7/10.',
    'La calificacion se guarda automaticamente al realizar cualquier accion: cambiar el estado, guardar cambios o asignar la tarea.',
  ]);
  tipBox('Importante: Las estrellas solo cambian visualmente al hacer clic. La calificacion se persiste cuando usted presiona un boton de accion (Guardar, cambiar estado, etc.).');
  para('El Colaborador puede ver la calificacion asignada, pero no puede modificarla.');
  para('La calificacion aparece tambien en la columna "Calificacion" de la tabla y en los reportes XLSX.');

  // ══════════════════════════════════════
  //  8. EVIDENCIA
  // ══════════════════════════════════════
  heading2('8. Carga de Evidencia');
  para('El Colaborador (y el Lider) pueden adjuntar evidencia a las tareas.');

  heading3('Subir evidencia');
  numberedList([
    'Abra el detalle de la tarea.',
    'En la seccion "Evidencia (texto)", describa el trabajo realizado.',
    'En "Archivos de evidencia", arrastre archivos o haga clic para seleccionarlos.',
    'Haga clic en "Guardar".',
  ]);
  tipBox('Limite: Cada archivo no debe superar los 20 MB. Puede adjuntar multiples archivos.', 'note');

  heading3('Descargar archivos');
  para('Haga clic en el icono de descarga junto a cualquier archivo (insumo o evidencia) para descargarlo.');

  // ══════════════════════════════════════
  //  9. EXPORTAR E IMPORTAR
  // ══════════════════════════════════════
  heading2('9. Exportar e Importar Tareas');

  heading3('Exportar a Excel');
  para('Desde la pagina de Tareas, haga clic en el icono de descarga en la barra de herramientas. Se generara un archivo .xlsx con las tareas visibles, incluyendo la calificacion.');

  heading3('Importar desde Excel (Carga Masiva)');
  numberedList([
    'Haga clic en el icono de "Descargar plantilla" para obtener el formato correcto.',
    'Complete la plantilla con los datos de las tareas (maximo 100 por archivo).',
    'Haga clic en el icono de "Cargar tareas desde XLSX" y seleccione su archivo.',
    'Revise los datos y confirme la carga.',
  ]);
  tipBox('Formato de fecha: Use DD/MM/AAAA HH:mm (ejemplo: 25/03/2026 17:00).');

  heading4('Columnas de la plantilla');
  table(
    ['Columna', 'Requerida', 'Descripcion'],
    [
      ['Titulo', 'Si', 'Nombre de la tarea'],
      ['Descripcion', 'Si', 'Descripcion detallada'],
      ['Fecha de entrega', 'Si', 'Formato DD/MM/AAAA HH:mm'],
      ['Tiempo estimado (h)', 'Si', 'Horas estimadas'],
      ['Insumos', 'No', 'Recursos necesarios'],
      ['Observaciones', 'No', 'Notas adicionales'],
      ['Email lider', 'No', 'Correo del lider a asignar'],
      ['Email colaborador', 'No', 'Correo del colaborador a asignar'],
    ]
  );

  // ══════════════════════════════════════
  //  10. ADMIN ROLES
  // ══════════════════════════════════════
  heading2('10. Administracion de Roles');
  para('Disponible solo para el rol Administrador.');

  heading3('Crear un Rol');
  numberedList([
    'Navegue a Roles en el menu lateral.',
    'Haga clic en "+ Nuevo Rol".',
    'Ingrese el nombre y la descripcion del rol.',
    'Haga clic en "Guardar".',
  ]);

  heading3('Editar / Eliminar un Rol');
  bulletList([
    'Editar: Haga clic en el icono de lapiz y modifique los campos.',
    'Eliminar: Haga clic en el icono de basura y confirme la eliminacion.',
  ]);

  // ══════════════════════════════════════
  //  11. ADMIN COLABORADORES
  // ══════════════════════════════════════
  heading2('11. Administracion de Colaboradores');
  para('Disponible solo para el rol Administrador.');

  heading3('Crear un Colaborador');
  numberedList([
    'Navegue a Colaboradores en el menu lateral.',
    'Haga clic en "+ Nuevo Colaborador".',
    'Complete los campos: Nombre completo, Cedula, Area, Correo, Contrasena (debe cumplir requisitos de seguridad), Roles (seleccione uno o mas).',
    'Haga clic en "Guardar".',
  ]);

  heading4('Requisitos de Contrasena');
  bulletList([
    'Minimo 8 caracteres',
    'Al menos una letra mayuscula',
    'Al menos una letra minuscula',
    'Al menos un numero',
    'Al menos un caracter especial (@$!%*?&#)',
  ]);

  // ══════════════════════════════════════
  //  12. ALERTAS PAYROLL
  // ══════════════════════════════════════
  heading2('12. Alertas Payroll');
  para('La pagina de Alertas Payroll muestra un dashboard de notificaciones del sistema de nomina.');

  heading3('Indicadores');
  bulletList([
    'Total Alertas: Numero total de alertas',
    'Activas: Alertas vigentes que requieren atencion',
    'En Proceso: Alertas siendo atendidas',
    'Resueltas: Alertas solucionadas',
    'Caducadas: Alertas que expiraron sin atencion',
    'Error Envio: Alertas con fallas en la notificacion',
  ]);

  heading3('Graficos');
  bulletList([
    'Distribucion por Estado: Grafico de dona con el conteo por estado.',
    'Alertas por Origen: Grafico de barras por sistema de origen.',
  ]);

  heading3('Tabla de Notificaciones Recientes');
  para('Muestra las notificaciones mas recientes con fecha, estado, prioridad, origen, asunto, descripcion, notificados y periodo.');

  // ══════════════════════════════════════
  //  13. NOTIFICACIONES
  // ══════════════════════════════════════
  heading2('13. Notificaciones');
  para('En la barra superior, junto a su nombre, encontrara un icono de campana.');
  bulletList([
    'Si tiene tareas pendientes en estado "Asignada" o "Reasignada", aparecera un circulo rojo con el numero de tareas.',
    'El contador se actualiza automaticamente cada 60 segundos.',
    'Si no tiene tareas pendientes, solo se muestra la campana sin indicador.',
  ]);

  // ══════════════════════════════════════
  //  14. FLUJO DE ESTADOS
  // ══════════════════════════════════════
  heading2('14. Flujo de Estados de Tareas');

  heading3('Flujo tipico de una tarea');

  // Draw flow diagram
  checkSpace(35);
  const boxH = 10;
  const boxColors = [
    { label: 'Creada', color: [123, 135, 148] },
    { label: 'Asignada', color: [74, 144, 217] },
    { label: 'CPV', color: [245, 166, 35] },
    { label: 'C. Validada', color: [80, 200, 120] },
    { label: 'Completa', color: [46, 125, 50] },
  ];
  const totalBoxes = boxColors.length;
  const boxW = 28;
  const arrowW = 7;
  const totalW = totalBoxes * boxW + (totalBoxes - 1) * arrowW;
  let startX = (PAGE_W - totalW) / 2;
  boxColors.forEach((b, i) => {
    doc.setFillColor(...b.color);
    doc.roundedRect(startX, y, boxW, boxH, 2, 2, 'F');
    doc.setFontSize(8);
    doc.setTextColor(...WHITE);
    doc.setFont('helvetica', 'bold');
    doc.text(b.label, startX + boxW / 2, y + boxH / 2 + 1, { align: 'center' });
    if (i < totalBoxes - 1) {
      doc.setTextColor(...GRAY);
      doc.setFontSize(14);
      doc.text('\u2192', startX + boxW + arrowW / 2, y + boxH / 2 + 1.5, { align: 'center' });
    }
    startX += boxW + arrowW;
  });
  y += boxH + 6;
  doc.setFontSize(9);
  doc.setTextColor(...GRAY);
  doc.setFont('helvetica', 'italic');
  doc.text('Flujos alternativos: Reasignar (devolver al colaborador) | Cancelar (solo Gerente)', PAGE_W / 2, y, { align: 'center' });
  y += 10;

  heading3('Detalle del flujo');
  numberedList([
    'Gerente crea la tarea → Estado: Creada',
    'Gerente asigna un Lider → Estado: Asignada',
    'Lider asigna un Colaborador → Estado: Asignada',
    'Colaborador completa y envia a validacion → Estado: Completa - Por Validar',
    'Lider valida y envia al Gerente → Estado: Completa - Validada',
    'Gerente aprueba → Estado: Completa',
  ]);
  para('Si en cualquier punto el Lider o Gerente considera que la tarea necesita correccion, puede reasignarla al colaborador (Reasignada).');

  // ══════════════════════════════════════
  //  15. FAQ
  // ══════════════════════════════════════
  heading2('15. Preguntas Frecuentes');

  heading4('No puedo ver mis tareas');
  para('Verifique que ha iniciado sesion con el rol correcto. Puede cambiar de rol desde el menu de usuario en la esquina superior derecha.');

  heading4('No puedo cambiar el estado de una tarea');
  para('Solo puede cambiar a los estados permitidos para su rol. Verifique la tabla de transiciones en la seccion 6.');

  heading4('La calificacion no se guarda al hacer clic en las estrellas');
  para('Las estrellas son un selector visual. La calificacion se guarda cuando presiona un boton de accion como "Guardar" o un cambio de estado.');

  heading4('No puedo crear tareas');
  para('Solo los roles Gerente y Lider pueden crear tareas. El Colaborador solo puede ver y completar tareas asignadas.');

  heading4('El archivo no se puede subir');
  para('Verifique que el archivo no supere los 20 MB. Puede subir multiples archivos a la vez.');

  heading4('No veo el Dashboard');
  para('El rol Administrador no tiene acceso al Dashboard. Es redirigido automaticamente a la pagina de Roles.');

  // ── Footer on all pages ──
  addFooter();

  // ── Save ──
  doc.save('Manual_FlowPulse.pdf');
}
