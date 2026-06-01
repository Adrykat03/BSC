'use strict';
// ─────────────────────────────────────────────────────────────────────────────
// BSC BackOffice — Generador de manual con capturas de pantalla
// Uso: node screenshot.js
// Variables de entorno requeridas:
//   BSC_URL      URL base de la app  (default: http://host.docker.internal:3030)
//   BSC_EMAIL    Correo del usuario
//   BSC_PASSWORD Contraseña del usuario
// El HTML de entrada y salida se leen/escriben en /output/
// ─────────────────────────────────────────────────────────────────────────────

const { chromium } = require('playwright');
const fs   = require('fs');
const path = require('path');

// La app corre en el contenedor bsc_frontend (nginx) a 19.168.78.12:3000
// dentro de la red bsc_bsc_net. host.docker.internal:3030 falla en Windows
// porque HTTP.sys rechaza el host header; la IP interna + Host:localhost resuelve el problema.
const BASE_URL      = process.env.BSC_URL      || 'http://19.168.78.12:3000';
const API_HOST_HDR  = process.env.BSC_API_HOST || 'localhost';
const EMAIL         = process.env.BSC_EMAIL;
const PASSWORD      = process.env.BSC_PASSWORD;
const OUT_DIR       = '/output';
const TEMPLATE_FILE = path.join(OUT_DIR, 'manual-usuario-alertas-payroll.template.html');
const HTML_FILE     = path.join(OUT_DIR, 'manual-usuario-alertas-payroll.html');
const PDF_FILE      = path.join(OUT_DIR, 'manual-usuario-alertas-payroll.pdf');

// ─────────────────────────────────────────────────────────────────────────────
// Validar entorno
// ─────────────────────────────────────────────────────────────────────────────
if (!EMAIL || !PASSWORD) {
  console.error('ERROR: Las variables BSC_EMAIL y BSC_PASSWORD son requeridas.');
  process.exit(1);
}
if (!fs.existsSync(TEMPLATE_FILE)) {
  console.error(`ERROR: No se encontró el template ${TEMPLATE_FILE}`);
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
function b64(buf) {
  return `data:image/png;base64,${buf.toString('base64')}`;
}

function figure(src, caption) {
  return `\n<figure class="screenshot">\n` +
    `  <img src="${src}" alt="${caption}" loading="lazy" />\n` +
    `  <figcaption>${caption}</figcaption>\n` +
    `</figure>\n`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Captura de pantallas
// ─────────────────────────────────────────────────────────────────────────────
async function captureScreenshots() {
  const browser = await chromium.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    deviceScaleFactor: 1,
  });

  const page = await context.newPage();
  const shots = {};

  async function snapPage(name, caption) {
    try {
      const buf = await page.screenshot({ type: 'png' });
      shots[name] = { src: b64(buf), caption };
      console.log(`  ✓ ${name}`);
    } catch (e) {
      console.warn(`  ✗ ${name}: ${e.message.split('\n')[0]}`);
    }
  }

  async function snapEl(name, caption, selector, opts = {}) {
    try {
      const loc = page.locator(selector).first();
      await loc.waitFor({ state: 'visible', timeout: opts.timeout || 6000 });
      if (opts.scrollIntoView) await loc.scrollIntoViewIfNeeded();
      await page.waitForTimeout(opts.settle || 400);
      const buf = await loc.screenshot({ type: 'png' });
      shots[name] = { src: b64(buf), caption };
      console.log(`  ✓ ${name}`);
    } catch (e) {
      // Fallback: full-page screenshot
      console.warn(`  ⚠ ${name} (selector fallback): ${e.message.split('\n')[0]}`);
      await snapPage(name, caption);
    }
  }

  // ── 1. LOGIN PAGE (captura visual) ────────────────────────────────────────
  console.log('\n[1/7] Página de login');
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(800);
  await snapPage('login', 'Pantalla de inicio de sesión — BSC BackOffice');

  // ── 2. AUTENTICACIÓN (via API directa para evitar problemas de hostname) ──
  console.log('\n[2/7] Autenticando vía API…');
  const apiRes = await context.request.post(`${BASE_URL}/api/auth/login`, {
    headers: { 'Content-Type': 'application/json', 'Host': API_HOST_HDR },
    data: { email: EMAIL, password: PASSWORD },
  });
  if (!apiRes.ok()) {
    throw new Error(`Login API devolvió ${apiRes.status()}: ${await apiRes.text()}`);
  }
  const apiBody = await apiRes.json();
  const token = apiBody?.data?.token;
  if (!token) throw new Error('No se recibió token JWT en la respuesta del login');

  // Inyectar token + colapsar sidebar antes del siguiente page.goto (React remonta y lee localStorage)
  await page.goto(`${BASE_URL}/`, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.evaluate((t) => {
    sessionStorage.setItem('fp_token', t);
    localStorage.setItem('fp_sidebar_collapsed', '1');
  }, token);
  console.log('  ✓ Sesión iniciada (token inyectado, sidebar colapsado)');

  // ── 3. ALERTAS PAYROLL — DASHBOARD ───────────────────────────────────────
  console.log('\n[3/7] Alertas Payroll — Dashboard');
  await page.goto(`${BASE_URL}/alertas-payroll`, { waitUntil: 'networkidle', timeout: 30000 });

  // Ocultar sidebar completamente para screenshots limpios (persiste en navegaciones SPA)
  await page.addStyleTag({ content: `
    .layout__sidebar { display: none !important; }
    .layout__main    { margin-left: 0 !important; }
  ` });
  // Esperar que los charts se rendericen
  try {
    await page.waitForSelector('canvas', { timeout: 10000 });
  } catch (_) { /* continuar aunque no haya canvas */ }
  await page.waitForTimeout(3000);

  // Vista general (tabs visibles)
  await snapPage('vista_general', 'Vista general — pestañas Dashboard y Listado del módulo Alertas Payroll');

  // Overview del Dashboard
  await snapEl('dashboard_overview', 'Tab Dashboard — resumen ejecutivo de alertas por tipo de descripción',
    '.payroll-dashboard-tab', { settle: 600 });

  // Filtros
  await snapEl('dashboard_filtros', 'Barra de filtros del Dashboard (Prioridad, Categoría, Estado, Fecha, Agrupación)',
    '.payroll-dashboard-tab .payroll-filter-bar, .payroll-dashboard-tab form, .payroll-dashboard-tab [class*="filter"], .payroll-dashboard-tab select',
    { settle: 400 });

  // Tarjetas donut (los 4 DescriptionPie)
  await snapEl('dashboard_tarjetas', 'Tarjetas donut por tipo: Con novedad, Sin novedad, Reportería y Error Proceso',
    '.payroll-dash-pies, .payroll-desc-grid, [class*="desc-pies"], [class*="dash-pies"]',
    { settle: 600 });

  // Gráfico de barras (canvas de la línea de tiempo)
  await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' }));
  await page.waitForTimeout(600);
  await snapEl('dashboard_grafico', 'Gráfico de barras apiladas — evolución de alertas vs tiempo (clic en barra descarga Excel)',
    'canvas', { settle: 500 });

  // ── 4. TAB LISTADO ────────────────────────────────────────────────────────
  console.log('\n[4/7] Alertas Payroll — Listado');
  await page.evaluate(() => window.scrollTo(0, 0));

  // Clic en tab "Listado"
  await page.locator('.payroll-tab:not(.is-active)').first().click();
  await page.waitForTimeout(1200);

  // Vista general del listado
  await snapPage('listado_overview', 'Tab Listado — KPIs de estado y gráficos de distribución');

  // KPI cards
  await snapEl('listado_kpis', 'Tarjetas KPI: Total, Activas, En Proceso, Resueltas, Cerradas y Error',
    '.payroll-kpi-row', { settle: 400 });

  // 3 gráficos
  await snapEl('listado_graficos', 'Gráficos del Listado: Pendientes por resolver, Distribución por estado y Alertas por categoría',
    '.payroll-charts-row', { scrollIntoView: true, settle: 800 });

  // Toolbar de la tabla
  await page.locator('.payroll-sticky-table').first().scrollIntoViewIfNeeded();
  await page.waitForTimeout(600);
  await snapEl('listado_filtros', 'Toolbar de la tabla — búsqueda global, filtro de fecha, limpiar, Actualizar y Descargar',
    '.payroll-sticky-table', { settle: 400 });

  // Tabla completa
  await snapEl('listado_tabla', 'Tabla de alertas con columnas de estado, prioridad, acciones y datos de resolución',
    '.payroll-sticky-table', { settle: 400 });

  // Paginación
  await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' }));
  await page.waitForTimeout(500);
  await snapEl('listado_paginacion', 'Controles de paginación — filas por página y navegación de páginas',
    '[class*="pagination"], [id*="page-size"]',
    { settle: 400 });

  // ── 5. MODAL ──────────────────────────────────────────────────────────────
  console.log('\n[5/7] Modal de alerta');
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(500);

  const eyeBtn = page.locator('.table__actions button').first();
  if (await eyeBtn.count() > 0) {
    await eyeBtn.scrollIntoViewIfNeeded();
    await eyeBtn.click();
    try {
      await page.waitForSelector('[aria-modal="true"]', { timeout: 8000 });
      await page.waitForTimeout(2000); // esperar que el iframe del correo cargue

      // Modal completo
      await snapEl('modal_correo', 'Modal de alerta — Tab Correo con previsualización del correo HTML y controles de zoom',
        '[aria-modal="true"]', { settle: 800 });

      // Panel lateral (resolución)
      await snapEl('modal_resolucion', 'Panel lateral del modal — Resolución: cambiar estado, notas y adjunto',
        '.preview-modal__side', { settle: 400 });

    } catch (e) {
      console.warn(`  ✗ modal: ${e.message.split('\n')[0]}`);
    }
    // Cerrar modal
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
  } else {
    console.warn('  ✗ No se encontró el botón de acción en la tabla');
  }

  await browser.close();
  console.log('\n  ✓ Todas las capturas tomadas\n');
  return shots;
}

// ─────────────────────────────────────────────────────────────────────────────
// Inyectar capturas en el HTML
// ─────────────────────────────────────────────────────────────────────────────
function buildHTML(shots) {
  let html = fs.readFileSync(TEMPLATE_FILE, 'utf-8');

  const markers = [
    ['login',               'login'],
    ['vista_general',       'vista_general'],
    ['dashboard_overview',  'dashboard_overview'],
    ['dashboard_filtros',   'dashboard_filtros'],
    ['dashboard_tarjetas',  'dashboard_tarjetas'],
    ['dashboard_grafico',   'dashboard_grafico'],
    ['listado_overview',    'listado_overview'],
    ['listado_kpis',        'listado_kpis'],
    ['listado_filtros',     'listado_filtros'],
    ['listado_tabla',       'listado_tabla'],
    ['listado_paginacion',  'listado_paginacion'],
    ['modal_correo',        'modal_correo'],
    ['modal_resolucion',    'modal_resolucion'],
  ];

  let injected = 0;
  for (const [marker, shotName] of markers) {
    const placeholder = `<!-- SHOT:${marker} -->`;
    if (!html.includes(placeholder)) {
      console.warn(`  ⚠ Marcador no encontrado: ${placeholder}`);
      continue;
    }
    const shot = shots[shotName];
    if (!shot) {
      html = html.replace(placeholder, `<!-- captura ${marker} no disponible -->`);
      console.warn(`  ⚠ Sin captura para ${shotName}`);
      continue;
    }
    html = html.replace(placeholder, figure(shot.src, shot.caption));
    injected++;
  }
  console.log(`  ✓ ${injected} capturas inyectadas en el HTML`);

  // ── Correcciones de texto ────────────────────────────────────────────────
  // Nombre del sistema
  html = html.replace(/BSC BackOffice/g, 'Nomina2');
  // Convertir <details> a formato siempre visible para compatibilidad con PDF
  html = html.replace(/<details([^>]*)>/g, '<div class="faq-item"$1>');
  html = html.replace(/<\/details>/g, '</div>');
  html = html.replace(/<summary([^>]*)>/g, '<div class="faq-question"$1>');
  html = html.replace(/<\/summary>/g, '</div>');
  console.log('  ✓ Textos corregidos (Nomina2, FAQ expandido)');

  return html;
}

// ─────────────────────────────────────────────────────────────────────────────
// Generar PDF desde el HTML resultante
// ─────────────────────────────────────────────────────────────────────────────
async function generatePDF(htmlContent) {
  const browser = await chromium.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();

  await page.setContent(htmlContent, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);

  // Expandir todos los <details>/<div.faq-item> por si quedaron colapsados
  await page.evaluate(() => {
    document.querySelectorAll('details').forEach(d => { d.open = true; });
    document.querySelectorAll('.faq-item').forEach(d => { d.style.display = 'block'; });
    document.querySelectorAll('.faq-question').forEach(d => { d.style.display = 'block'; });
  });

  await page.pdf({
    path: PDF_FILE,
    format: 'A4',
    printBackground: true,
    // Márgenes: top más grande para dejar espacio al footer, sin header
    margin: { top: '15mm', right: '12mm', bottom: '20mm', left: '12mm' },
    displayHeaderFooter: true,
    // Header vacío (sin título ni URL de Chrome)
    headerTemplate: '<span style="font-size:1px;visibility:hidden;"> </span>',
    footerTemplate: `
      <div style="font-family:'Segoe UI',sans-serif;font-size:9px;color:#9CA3AF;
                  width:100%;text-align:center;padding:0 12mm;box-sizing:border-box;">
        Nomina2 — Manual de Usuario Alertas Payroll
        &nbsp;|&nbsp;
        Página <span class="pageNumber"></span> de <span class="totalPages"></span>
      </div>`,
  });

  await browser.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log('═══════════════════════════════════════════════════');
  console.log(' BSC BackOffice — Generador de Manual con Capturas');
  console.log('═══════════════════════════════════════════════════');
  console.log(`  App URL : ${BASE_URL}`);
  console.log(`  Usuario : ${EMAIL}`);
  console.log(`  Salida  : ${OUT_DIR}`);
  console.log('───────────────────────────────────────────────────\n');

  // 1. Tomar capturas
  const shots = await captureScreenshots();

  // 2. Inyectar en HTML
  console.log('\n[6/7] Generando HTML con capturas…');
  const htmlFinal = buildHTML(shots);
  fs.writeFileSync(HTML_FILE, htmlFinal, 'utf-8');
  console.log(`  ✓ Guardado: ${HTML_FILE}`);

  // 3. Generar PDF
  console.log('\n[7/7] Generando PDF…');
  await generatePDF(htmlFinal);
  console.log(`  ✓ Guardado: ${PDF_FILE}`);

  const htmlKb = Math.round(fs.statSync(HTML_FILE).size / 1024);
  const pdfKb  = Math.round(fs.statSync(PDF_FILE).size  / 1024);

  console.log('\n═══════════════════════════════════════════════════');
  console.log(' ✅ Manual generado exitosamente');
  console.log(`  HTML : ${HTML_FILE} (${htmlKb} KB)`);
  console.log(`  PDF  : ${PDF_FILE}  (${pdfKb} KB)`);
  console.log('═══════════════════════════════════════════════════');
}

main().catch(err => {
  console.error('\n❌ ERROR FATAL:', err.message);
  process.exit(1);
});
