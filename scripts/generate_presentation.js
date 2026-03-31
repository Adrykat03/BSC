const pptxgen = require('pptxgenjs');
const fs = require('fs');
const path = require('path');

const SCREENSHOTS = path.join(__dirname, '..', 'manual_output', 'screenshots');
const OUTPUT = path.join(__dirname, '..', 'manual_output', 'Presentacion_Nomina2.pptx');

const RED = 'E31837';
const DARK = '1F2937';
const GRAY = '6B7280';
const WHITE = 'FFFFFF';
const LIGHT_BG = 'F9FAFB';

function img(name) {
  const p = path.join(SCREENSHOTS, `${name}.png`);
  if (!fs.existsSync(p)) return null;
  return { data: `image/png;base64,${fs.readFileSync(p).toString('base64')}` };
}

function addTitleSlide(pres) {
  const slide = pres.addSlide();
  slide.background = { fill: RED };
  slide.addText('Nomina2', { x: 0.5, y: 1.5, w: 9, h: 1.2, fontSize: 48, bold: true, color: WHITE, align: 'center', fontFace: 'Arial' });
  slide.addText('Sistema de Gestion de Tareas y Alertas de Nomina', { x: 0.5, y: 2.8, w: 9, h: 0.6, fontSize: 20, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 10 });
  slide.addText('Presentacion del Sistema', { x: 0.5, y: 3.6, w: 9, h: 0.5, fontSize: 16, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 30 });
  slide.addText('Marzo 2026', { x: 0.5, y: 4.8, w: 9, h: 0.4, fontSize: 12, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 50 });
}

function addSection(pres, title) {
  const slide = pres.addSlide();
  slide.background = { fill: DARK };
  slide.addText(title, { x: 0.5, y: 2.2, w: 9, h: 1, fontSize: 36, bold: true, color: WHITE, align: 'center', fontFace: 'Arial' });
  const bar = { x: 3.5, y: 3.3, w: 3, h: 0.05 };
  slide.addShape(pres.ShapeType.rect, { ...bar, fill: { color: RED } });
}

function addSlide(pres, title, bullets, screenshot) {
  const slide = pres.addSlide();
  slide.background = { fill: WHITE };

  // Header bar
  slide.addShape(pres.ShapeType.rect, { x: 0, y: 0, w: 10, h: 0.6, fill: { color: RED } });
  slide.addText(title, { x: 0.5, y: 0.05, w: 9, h: 0.5, fontSize: 18, bold: true, color: WHITE, fontFace: 'Arial' });

  if (screenshot && bullets.length > 0) {
    // Split layout: bullets left, screenshot right
    slide.addText(bullets.map(b => ({ text: b, options: { bullet: { code: '2022' }, fontSize: 13, color: DARK, fontFace: 'Arial', lineSpacingMultiple: 1.4 } })), { x: 0.5, y: 1.0, w: 4.2, h: 4.2, valign: 'top' });
    slide.addImage({ ...screenshot, x: 4.9, y: 0.9, w: 4.8, h: 4.4, rounding: true });
  } else if (screenshot) {
    // Full screenshot
    slide.addImage({ ...screenshot, x: 0.8, y: 0.9, w: 8.4, h: 4.5, rounding: true });
  } else {
    // Only bullets
    slide.addText(bullets.map(b => ({ text: b, options: { bullet: { code: '2022' }, fontSize: 14, color: DARK, fontFace: 'Arial', lineSpacingMultiple: 1.5 } })), { x: 0.5, y: 1.0, w: 9, h: 4.2, valign: 'top' });
  }

  // Footer
  slide.addText('Nomina2 - Sistema de Gestion', { x: 0.5, y: 5.2, w: 9, h: 0.3, fontSize: 9, color: GRAY, fontFace: 'Arial' });
}

function addTableSlide(pres, title, headers, rows) {
  const slide = pres.addSlide();
  slide.background = { fill: WHITE };
  slide.addShape(pres.ShapeType.rect, { x: 0, y: 0, w: 10, h: 0.6, fill: { color: RED } });
  slide.addText(title, { x: 0.5, y: 0.05, w: 9, h: 0.5, fontSize: 18, bold: true, color: WHITE, fontFace: 'Arial' });

  const tableRows = [
    headers.map(h => ({ text: h, options: { bold: true, color: WHITE, fill: { color: RED }, fontSize: 12, fontFace: 'Arial', align: 'center' } })),
    ...rows.map(row => row.map(cell => ({ text: cell, options: { fontSize: 11, color: DARK, fontFace: 'Arial', align: 'center', fill: { color: LIGHT_BG } } }))),
  ];

  slide.addTable(tableRows, { x: 0.5, y: 1.0, w: 9, colW: headers.map(() => 9 / headers.length), border: { pt: 0.5, color: 'D1D5DB' } });
  slide.addText('Nomina2 - Sistema de Gestion', { x: 0.5, y: 5.2, w: 9, h: 0.3, fontSize: 9, color: GRAY, fontFace: 'Arial' });
}

(async () => {
  const pres = new pptxgen();
  pres.layout = 'LAYOUT_WIDE';
  pres.author = 'Nomina2';
  pres.subject = 'Presentacion del Sistema Nomina2';

  // 1. Portada
  addTitleSlide(pres);

  // 2. Agenda
  addSlide(pres, 'Agenda', [
    '1. Que es Nomina2',
    '2. Roles del Sistema',
    '3. Inicio de Sesion',
    '4. Dashboard',
    '5. Gestion de Tareas',
    '6. Calificacion Automatica',
    '7. Estrellas y Rendimiento Mensual',
    '8. Evidencia y Archivos',
    '9. Exportar e Importar',
    '10. Administracion (Roles y Colaboradores)',
    '11. Alertas Payroll',
    '12. Notificaciones',
  ], null);

  // 3. Que es Nomina2
  addSection(pres, 'Que es Nomina2');
  addSlide(pres, 'Que es Nomina2', [
    'Sistema BackOffice para gestion de tareas y monitoreo de alertas de nomina',
    'Permite organizar, asignar, dar seguimiento y calificar tareas',
    'Controles diferenciados por rol (Gerente, Lider, Colaborador, Administrador)',
    'Dashboard con metricas en tiempo real',
    'Calificacion automatica basada en rendimiento',
    'Exportacion e importacion masiva de tareas (XLSX)',
  ], img('02_dashboard_gerente'));

  // 4. Roles
  addSection(pres, 'Roles del Sistema');
  addTableSlide(pres, 'Roles y Permisos', ['Rol', 'Acceso', 'Funciones Principales'], [
    ['Gerente', 'Dashboard, Tareas, Alertas', 'Crea tareas, asigna lideres, aprueba, cancela'],
    ['Lider', 'Dashboard, Tareas, Alertas', 'Asigna colaboradores, valida, reasigna'],
    ['Colaborador', 'Dashboard, Tareas, Alertas', 'Ejecuta tareas, sube evidencia, envia a validacion'],
    ['Administrador', 'Roles, Colaboradores, Alertas', 'Gestiona roles y usuarios del sistema'],
  ]);

  addTableSlide(pres, 'Visibilidad por Rol', ['Modulo', 'Administrador', 'Gerente', 'Lider', 'Colaborador'], [
    ['Dashboard', '-', 'Si', 'Si', 'Si'],
    ['Tareas', '-', 'Si', 'Si', 'Si'],
    ['Roles', 'Si', '-', '-', '-'],
    ['Colaboradores', 'Si', '-', '-', '-'],
    ['Alertas Payroll', 'Si', 'Si', 'Si', 'Si'],
  ]);

  // 5. Login
  addSection(pres, 'Inicio de Sesion');
  addSlide(pres, 'Inicio de Sesion', [
    'Ingrese su correo corporativo y contrasena',
    'Si tiene multiples roles, se activa el de mayor privilegio',
    'Puede cambiar de rol desde el menu de usuario (esquina superior derecha)',
    'La pagina se recarga con los permisos del nuevo rol',
  ], img('01_login'));

  // 6. Dashboard
  addSection(pres, 'Dashboard');
  addSlide(pres, 'Dashboard - Vista Gerente', [
    'Tarjetas KPI con metricas clave',
    'Mapa de calor por horas estimadas',
    'Distribucion de tareas por estado',
    'Tareas por colaborador y estado',
    'Highlights: colaborador mas eficiente y lider top',
    'Descarga de reportes XLSX',
  ], img('02_dashboard_gerente'));

  // 7. Tareas
  addSection(pres, 'Gestion de Tareas');
  addSlide(pres, 'Tareas - Vista Gerente', [
    'Tabla con todas las tareas del sistema',
    'Filtros y busqueda en tiempo real',
    'Boton "+ Nueva Tarea" para crear',
    'Acciones: editar, historial, cambiar estado',
    'Tooltips en todos los botones',
    'Exportar e importar desde XLSX',
  ], img('04_tasks_gerente'));

  addSlide(pres, 'Crear y Editar Tareas', [
    'Titulo, Descripcion, Fecha de entrega',
    'Tiempo estimado (horas)',
    'Insumos y Observaciones',
    'Asignar Lider y Colaborador',
    'Toolbar con acciones por rol en el footer',
  ], img('05_task_modal_create'));

  addSlide(pres, 'Vista Lider y Colaborador', [
    'Lider: ve tareas asignadas, valida y reasigna',
    'Colaborador: ve sus tareas, sube evidencia, envia a validacion',
    'Cada rol tiene botones de accion especificos',
  ], img('11_tasks_lider'));

  addTableSlide(pres, 'Flujo de Estados', ['Paso', 'Accion', 'Estado Resultante'], [
    ['1', 'Gerente crea tarea', 'Creada'],
    ['2', 'Gerente asigna Lider', 'Asignada'],
    ['3', 'Lider asigna Colaborador', 'Asignada'],
    ['4', 'Colaborador completa', 'Completa - Por Validar'],
    ['5', 'Lider valida', 'Completa - Validada'],
    ['6', 'Gerente aprueba', 'Completa'],
  ]);

  // 8. Calificacion
  addSection(pres, 'Calificacion Automatica');
  addSlide(pres, 'Calificacion por Porcentaje', [
    'Se calcula automaticamente al completar la tarea',
    'Base: 100%',
    'Entrega tardia: -30%',
    'Por cada reasignacion: -10%',
    'Barra de progreso con color: Verde (>=70%), Amarillo (40-69%), Rojo (<40%)',
    'No es editable manualmente',
  ], img('07_task_modal_rating'));

  // 9. Estrellas mensuales
  addSlide(pres, 'Estrellas y Rendimiento Mensual', [
    'Calificacion mensual de 1 a 5 estrellas',
    'Basada en el promedio de calificaciones del mes',
    'Frase motivacional segun nivel',
    'Grafico de dona con porcentaje de rendimiento',
    'Se reinicia al inicio de cada mes',
    'Visible solo para el Colaborador en su Dashboard',
  ], null);

  addTableSlide(pres, 'Escala de Estrellas Mensuales', ['Estrellas', 'Promedio', 'Mensaje'], [
    ['5 estrellas', '90% - 100%', 'Excelente desempeno'],
    ['4 estrellas', '70% - 89%', 'Muy buen trabajo'],
    ['3 estrellas', '50% - 69%', 'Buen esfuerzo, sigue mejorando'],
    ['2 estrellas', '30% - 49%', 'Hay oportunidades de mejora'],
    ['1 estrella', '0% - 29%', 'Necesita atencion'],
  ]);

  // 10. Evidencia
  addSection(pres, 'Evidencia y Archivos');
  addSlide(pres, 'Carga de Evidencia', [
    'Abra el detalle de la tarea',
    'Describa el trabajo en "Evidencia (texto)"',
    'Adjunte archivos (max 20MB cada uno)',
    'Haga clic en "Guardar"',
    'Los archivos son descargables por todos los roles',
    'Evidencia y texto son opcionales',
  ], img('08_task_modal_evidence'));

  // 11. Exportar/Importar
  addSlide(pres, 'Exportar e Importar Tareas', [
    'Exportar: icono de descarga genera archivo XLSX',
    'Incluye calificacion como porcentaje',
    'Importar: descargue plantilla, complete datos (max 100)',
    'Suba archivo XLSX para carga masiva',
    'Columnas: Titulo, Descripcion, Fecha, Tiempo estimado, Insumos, Email lider/colaborador',
  ], img('04_tasks_gerente'));

  // 12. Admin
  addSection(pres, 'Administracion');
  addSlide(pres, 'Gestion de Roles', [
    'Solo accesible para el Administrador',
    'Crear, editar y eliminar roles',
    'Cada rol tiene nombre y descripcion',
  ], img('14_roles'));

  addSlide(pres, 'Gestion de Colaboradores', [
    'Solo accesible para el Administrador',
    'CRUD completo de colaboradores',
    'Busqueda por nombre, cedula, area, correo o rol',
    'Asignacion de multiples roles',
    'Contrasena con requisitos de complejidad',
  ], img('15_colaboradores'));

  // 13. Alertas
  addSection(pres, 'Alertas Payroll');
  addSlide(pres, 'Dashboard de Alertas Payroll', [
    'Monitoreo de alertas del sistema de nomina',
    'Indicadores: Total, Activas, En Proceso, Resueltas, Caducadas, Error Envio',
    'Accesible para todos los roles',
  ], img('10_alertas_payroll'));

  // 14. Notificaciones
  addSlide(pres, 'Notificaciones', [
    'Campana de notificaciones en la barra superior',
    'Badge rojo muestra cantidad de tareas pendientes',
    'Cuenta tareas con estado Asignada o Reasignada',
    'Se actualiza automaticamente cada 60 segundos',
    'Icono de ayuda para descargar el manual PDF',
  ], img('03_header'));

  // 15. Cierre
  const closeSlide = pres.addSlide();
  closeSlide.background = { fill: RED };
  closeSlide.addText('Gracias', { x: 0.5, y: 1.8, w: 9, h: 1, fontSize: 44, bold: true, color: WHITE, align: 'center', fontFace: 'Arial' });
  closeSlide.addText('Nomina2 - Sistema de Gestion de Tareas', { x: 0.5, y: 3.0, w: 9, h: 0.6, fontSize: 18, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 15 });
  closeSlide.addText('Preguntas?', { x: 0.5, y: 4.0, w: 9, h: 0.5, fontSize: 16, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 30 });

  await pres.writeFile({ fileName: OUTPUT });
  console.log(`Presentacion guardada en: ${OUTPUT}`);
})();
