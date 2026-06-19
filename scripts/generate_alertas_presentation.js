// Genera una presentacion ejecutiva RESUMIDA del Monitor de Alertas Payroll.
// Salida: docs/Presentacion_Monitor_Alertas.pptx
// Ejecutar:  node scripts/generate_alertas_presentation.js
//
// NOTA: los medidores (reduccion de tiempo, eficiencia, calidad) son valores
// ESTIMADOS/objetivo para el mensaje ejecutivo. Ajustar con datos reales.

const pptxgen = require('pptxgenjs');
const path = require('path');

const RED = 'E31837';
const DARK = '1F2937';
const GRAY = '6B7280';
const LIGHT = 'F3F4F6';
const WHITE = 'FFFFFF';
const GREEN = '2E7D32';
const BLUE = '2E75B6';

const pres = new pptxgen();
pres.defineLayout({ name: 'W', width: 13.33, height: 7.5 });
pres.layout = 'W';
pres.author = 'BSC BackOffice';
pres.title = 'Monitor de Alertas Payroll';

const footer = (slide) =>
  slide.addText('Nomina2 · Monitor de Alertas Payroll', {
    x: 0.5, y: 7.05, w: 12.3, h: 0.3, fontSize: 9, color: GRAY, fontFace: 'Arial',
  });

const header = (slide, title) => {
  slide.addShape(pres.ShapeType.rect, { x: 0, y: 0, w: 13.33, h: 0.85, fill: { color: RED } });
  slide.addText(title, { x: 0.6, y: 0.12, w: 12, h: 0.6, fontSize: 24, bold: true, color: WHITE, fontFace: 'Arial' });
};

// ─── 1. PORTADA ───────────────────────────────────────────────
(() => {
  const s = pres.addSlide();
  s.background = { fill: RED };
  s.addText('Monitor de Alertas Payroll', { x: 0.5, y: 2.2, w: 12.3, h: 1.1, fontSize: 44, bold: true, color: WHITE, align: 'center', fontFace: 'Arial' });
  s.addText('De revisar correos manualmente a un control centralizado', { x: 0.5, y: 3.45, w: 12.3, h: 0.6, fontSize: 20, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 10 });
  s.addShape(pres.ShapeType.rect, { x: 5.66, y: 4.4, w: 2, h: 0.06, fill: { color: WHITE } });
  s.addText('Resumen ejecutivo · Junio 2026', { x: 0.5, y: 4.7, w: 12.3, h: 0.4, fontSize: 14, color: WHITE, align: 'center', fontFace: 'Arial', transparency: 30 });
})();

// ─── 2. ANTES vs AHORA ────────────────────────────────────────
(() => {
  const s = pres.addSlide();
  s.background = { fill: WHITE };
  header(s, 'El reto: antes vs. ahora');

  // ANTES (card gris)
  s.addShape(pres.ShapeType.roundRect, { x: 0.6, y: 1.3, w: 5.9, h: 5.1, fill: { color: LIGHT }, line: { color: 'E5E7EB', width: 1 }, rectRadius: 0.1 });
  s.addText('ANTES', { x: 0.6, y: 1.5, w: 5.9, h: 0.5, fontSize: 18, bold: true, color: GRAY, align: 'center', fontFace: 'Arial' });
  s.addText([
    'Alertas dispersas en el correo',
    'Revisión manual, una por una',
    'Sin priorización ni trazabilidad',
    'Riesgo de pasar por alto las críticas',
    'Difícil medir o reportar',
  ].map((t) => ({ text: t, options: { bullet: { code: '2022' }, fontSize: 15, color: DARK, fontFace: 'Arial', paraSpaceAfter: 10 } })),
    { x: 1.0, y: 2.2, w: 5.2, h: 4.0, valign: 'top' });

  // AHORA (card roja)
  s.addShape(pres.ShapeType.roundRect, { x: 6.85, y: 1.3, w: 5.9, h: 5.1, fill: { color: 'FBE9EC' }, line: { color: RED, width: 1.5 }, rectRadius: 0.1 });
  s.addText('AHORA', { x: 6.85, y: 1.5, w: 5.9, h: 0.5, fontSize: 18, bold: true, color: RED, align: 'center', fontFace: 'Arial' });
  s.addText([
    'Monitor centralizado de todas las alertas',
    'Dashboard + Listado con filtros y búsqueda',
    'Priorización automática (críticas al tope)',
    'Resolución con historial auditable',
    'Reportes XLSX y métricas en segundos',
  ].map((t) => ({ text: t, options: { bullet: { code: '2022' }, fontSize: 15, color: DARK, fontFace: 'Arial', paraSpaceAfter: 10 } })),
    { x: 7.25, y: 2.2, w: 5.2, h: 4.0, valign: 'top' });

  footer(s);
})();

// ─── 3. MEDIDORES DE IMPACTO (gauges) ─────────────────────────
(() => {
  const s = pres.addSlide();
  s.background = { fill: WHITE };
  header(s, 'Medidores de impacto');

  const gauges = [
    { label: 'Reducción de tiempo\nrevisando correos', value: 75, color: RED },
    { label: 'Eficiencia en la\ngestión de alertas', value: 90, color: GREEN },
    { label: 'Trazabilidad y\ncalidad del proceso', value: 100, color: BLUE },
  ];
  const w = 3.6, h = 3.2, y = 1.5;
  const xs = [0.9, 4.86, 8.82];

  gauges.forEach((g, i) => {
    const x = xs[i];
    s.addChart(pres.ChartType.doughnut,
      [{ name: g.label, labels: ['v', 'r'], values: [g.value, 100 - g.value] }],
      { x, y, w, h, holeSize: 70, showLegend: false, showTitle: false, showValue: false,
        chartColors: [g.color, 'E5E7EB'], dataBorder: { pt: 1, color: WHITE } });
    // % al centro
    s.addText(`${g.value}%`, { x, y: y + h / 2 - 0.45, w, h: 0.9, fontSize: 34, bold: true, color: g.color, align: 'center', valign: 'middle', fontFace: 'Arial' });
    // etiqueta debajo
    s.addText(g.label, { x: x - 0.2, y: y + h + 0.05, w: w + 0.4, h: 0.8, fontSize: 14, color: DARK, align: 'center', fontFace: 'Arial' });
  });

  s.addText('* Valores estimados/objetivo para fines ejecutivos — ajustar con mediciones reales.',
    { x: 0.6, y: 6.6, w: 12.1, h: 0.3, fontSize: 10, italic: true, color: GRAY, fontFace: 'Arial' });
  footer(s);
})();

// ─── 4. TIEMPO QUE SE REDUCE ──────────────────────────────────
(() => {
  const s = pres.addSlide();
  s.background = { fill: WHITE };
  header(s, 'Tiempo que se reduce');

  s.addText('Tiempo diario dedicado a revisar y clasificar alertas por correo', { x: 0.6, y: 1.2, w: 12, h: 0.5, fontSize: 16, color: DARK, fontFace: 'Arial' });

  // Antes
  s.addShape(pres.ShapeType.roundRect, { x: 1.3, y: 2.4, w: 3.6, h: 2.6, fill: { color: LIGHT }, line: { color: 'E5E7EB', width: 1 }, rectRadius: 0.1 });
  s.addText('ANTES', { x: 1.3, y: 2.65, w: 3.6, h: 0.4, fontSize: 14, bold: true, color: GRAY, align: 'center', fontFace: 'Arial' });
  s.addText('~60', { x: 1.3, y: 3.05, w: 3.6, h: 1.0, fontSize: 48, bold: true, color: GRAY, align: 'center', fontFace: 'Arial' });
  s.addText('min / día', { x: 1.3, y: 4.15, w: 3.6, h: 0.4, fontSize: 14, color: GRAY, align: 'center', fontFace: 'Arial' });

  // Flecha
  s.addText('→', { x: 5.0, y: 2.9, w: 1.4, h: 1.5, fontSize: 54, bold: true, color: RED, align: 'center', valign: 'middle', fontFace: 'Arial' });

  // Ahora
  s.addShape(pres.ShapeType.roundRect, { x: 6.5, y: 2.4, w: 3.6, h: 2.6, fill: { color: 'FBE9EC' }, line: { color: RED, width: 1.5 }, rectRadius: 0.1 });
  s.addText('AHORA', { x: 6.5, y: 2.65, w: 3.6, h: 0.4, fontSize: 14, bold: true, color: RED, align: 'center', fontFace: 'Arial' });
  s.addText('~15', { x: 6.5, y: 3.05, w: 3.6, h: 1.0, fontSize: 48, bold: true, color: RED, align: 'center', fontFace: 'Arial' });
  s.addText('min / día', { x: 6.5, y: 4.15, w: 3.6, h: 0.4, fontSize: 14, color: RED, align: 'center', fontFace: 'Arial' });

  // -75%
  s.addShape(pres.ShapeType.roundRect, { x: 10.5, y: 2.85, w: 2.2, h: 1.7, fill: { color: RED }, rectRadius: 0.1 });
  s.addText('-75%', { x: 10.5, y: 3.0, w: 2.2, h: 1.0, fontSize: 36, bold: true, color: WHITE, align: 'center', valign: 'middle', fontFace: 'Arial' });
  s.addText('menos tiempo', { x: 10.5, y: 4.0, w: 2.2, h: 0.4, fontSize: 12, color: WHITE, align: 'center', fontFace: 'Arial' });

  s.addText('Equivale a recuperar ~45 min por analista cada día para tareas de mayor valor.', { x: 0.6, y: 5.6, w: 12, h: 0.5, fontSize: 14, italic: true, color: DARK, align: 'center', fontFace: 'Arial' });
  s.addText('* Estimación ilustrativa — ajustar con datos reales del equipo.', { x: 0.6, y: 6.6, w: 12.1, h: 0.3, fontSize: 10, italic: true, color: GRAY, fontFace: 'Arial' });
  footer(s);
})();

// ─── 5. FUNCIONALIDADES CLAVE ─────────────────────────────────
(() => {
  const s = pres.addSlide();
  s.background = { fill: WHITE };
  header(s, 'Funcionalidades clave');
  s.addText([
    'Dashboard ejecutivo: tendencia de alertas vs tiempo y KPIs por estado',
    'Pendientes por resolver, segmentados por prioridad (Alta / Media / Baja)',
    'Listado con búsqueda global, filtros por columna y por fecha',
    'Alertas críticas (Alta + Con novedad + Activas) fijadas al inicio',
    'Resolución con cambio de estado, notas e historial auditable',
    'Previsualización del correo y adjuntos sin salir del módulo',
    'Descarga de reportes XLSX con formato profesional',
    'Acceso por permisos de módulo según el rol',
  ].map((t) => ({ text: t, options: { bullet: { code: '2022' }, fontSize: 16, color: DARK, fontFace: 'Arial', paraSpaceAfter: 12 } })),
    { x: 0.9, y: 1.3, w: 11.5, h: 5.4, valign: 'top' });
  footer(s);
})();

// ─── 6. BENEFICIOS / CIERRE ───────────────────────────────────
(() => {
  const s = pres.addSlide();
  s.background = { fill: DARK };
  s.addText('Beneficios', { x: 0.6, y: 0.7, w: 12, h: 0.8, fontSize: 30, bold: true, color: WHITE, fontFace: 'Arial' });
  s.addShape(pres.ShapeType.rect, { x: 0.65, y: 1.55, w: 2.2, h: 0.05, fill: { color: RED } });

  const cards = [
    { t: 'Decisiones más rápidas', d: 'Toda la información en una sola pantalla, en segundos.' },
    { t: 'Menos riesgo operativo', d: 'Las alertas críticas saltan a la vista; nada se pasa por alto.' },
    { t: 'Foco en lo importante', d: 'Menos tiempo en el correo, más en resolver.' },
    { t: 'Trazabilidad total', d: 'Cada cambio queda registrado con usuario y fecha.' },
  ];
  const cw = 5.9, ch = 2.0;
  const pos = [[0.6, 2.1], [6.85, 2.1], [0.6, 4.3], [6.85, 4.3]];
  cards.forEach((c, i) => {
    const [x, y] = pos[i];
    s.addShape(pres.ShapeType.roundRect, { x, y, w: cw, h: ch, fill: { color: '2B3645' }, rectRadius: 0.08 });
    s.addText(c.t, { x: x + 0.3, y: y + 0.25, w: cw - 0.6, h: 0.6, fontSize: 18, bold: true, color: RED, fontFace: 'Arial' });
    s.addText(c.d, { x: x + 0.3, y: y + 0.9, w: cw - 0.6, h: 0.9, fontSize: 14, color: WHITE, fontFace: 'Arial' });
  });
})();

const out = path.join(__dirname, '..', 'docs', 'Presentacion_Monitor_Alertas.pptx');
pres.writeFile({ fileName: out }).then(() => console.log('PPTX generado:', out));
