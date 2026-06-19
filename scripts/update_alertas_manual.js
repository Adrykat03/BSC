// Actualiza las capturas del manual de Alertas Payroll y regenera el PDF.
// Captura 3 imagenes correctas con Playwright (login real), las inyecta en el
// HTML reemplazando por <figcaption>, y exporta el PDF (respeta @media print).
//
// Ejecutar dentro del contenedor Docker de Playwright (red bsc_bsc_net):
//   docker run --rm --network bsc_bsc_net \
//     -e BASE_URL=http://bsc_frontend:3000 -e EMAIL=... -e PASSWORD=... \
//     -e PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
//     -v "C:\Proyectos\BSC:/work" -w /work/scripts \
//     mcr.microsoft.com/playwright:v1.58.2-jammy node update_alertas_manual.js

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = process.env.BASE_URL || 'http://bsc_frontend:3000';
const EMAIL = process.env.EMAIL;
const PASSWORD = process.env.PASSWORD;
const HTML = '/work/docs/manual-usuario-alertas-payroll.html';
const PDF = '/work/docs/manual-usuario-alertas-payroll.pdf';
const SHOTS = '/work/scripts/_shots';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const escRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Capturas a regenerar: { figcaption exacto -> archivo png }
const TARGETS = [
  {
    file: 'filtros_dashboard.png',
    caption: 'Barra de filtros del Dashboard (Prioridad, Categoría, Estado, Fecha, Agrupación)',
  },
  {
    file: 'grafico_barras.png',
    caption: 'Gráfico de barras apiladas — evolución de alertas vs tiempo (clic en barra descarga Excel)',
  },
  {
    file: 'toolbar_tabla.png',
    caption: 'Toolbar de la tabla — búsqueda global, filtro de fecha, limpiar, Actualizar y Descargar',
  },
];

async function login(page) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' });
  await sleep(600);
  await page.fill('input[type="email"]', EMAIL);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => !u.toString().includes('/login'), { timeout: 15000 });
  await sleep(1500);
}

async function shot(locator, file) {
  const fp = path.join(SHOTS, file);
  await locator.screenshot({ path: fp });
  console.log('  capturado:', file);
  return fp;
}

(async () => {
  if (!EMAIL || !PASSWORD) throw new Error('Faltan EMAIL/PASSWORD en env.');
  fs.mkdirSync(SHOTS, { recursive: true });

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const context = await browser.newContext({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: 2 });
  const page = await context.newPage();

  try {
    console.log('1. Login...');
    await login(page);

    console.log('2. Alertas Payroll (tab Dashboard)...');
    await page.goto(`${BASE_URL}/alertas-payroll`, { waitUntil: 'networkidle' });
    await sleep(2500); // espera carga de datos + render de charts

    // Asegura tab Dashboard activo
    const dashTab = page.locator('.payroll-tab', { hasText: 'Dashboard' });
    if (await dashTab.count()) { await dashTab.first().click(); await sleep(800); }

    // (a) Barra de filtros del Dashboard -> la card que contiene .payroll-dash-filters
    const filtersCard = page.locator('.card', { has: page.locator('.payroll-dash-filters') }).first();
    await filtersCard.scrollIntoViewIfNeeded();
    await sleep(400);
    await shot(filtersCard, 'filtros_dashboard.png');

    // (b) Grafico de barras "Alertas vs Tiempo" -> la card con ese titulo
    const barCard = page.locator('.card', { has: page.locator('h2', { hasText: 'Alertas vs Tiempo' }) }).first();
    await barCard.scrollIntoViewIfNeeded();
    await sleep(1200); // animacion del chart
    await shot(barCard, 'grafico_barras.png');

    console.log('3. Tab Listado (toolbar)...');
    const listTab = page.locator('.payroll-tab', { hasText: 'Listado' });
    await listTab.first().click();
    await sleep(1800);
    const toolbar = page.locator('.payroll-toolbar').first();
    await toolbar.scrollIntoViewIfNeeded();
    await sleep(300);
    await shot(toolbar, 'toolbar_tabla.png');

    // ── Inyectar imagenes en el HTML ──
    console.log('4. Inyectando imagenes en el HTML...');
    let html = fs.readFileSync(HTML, 'utf8');
    for (const t of TARGETS) {
      const b64 = fs.readFileSync(path.join(SHOTS, t.file)).toString('base64');
      const dataUri = `data:image/png;base64,${b64}`;
      // Anclar al <img> que precede inmediatamente al figcaption objetivo.
      // [^>]* NO cruza limites de tag, evitando colapsar figuras adyacentes.
      const re = new RegExp(
        '<img\\b[^>]*>(\\s*<figcaption>\\s*' + escRe(t.caption) + ')'
      );
      const before = html.length;
      html = html.replace(re, `<img class="screenshot" src="${dataUri}" alt="" />$1`);
      if (html.length === before) {
        console.warn('  ⚠ NO se encontro figura para:', t.caption);
      } else {
        console.log('  ✓ reemplazada:', t.file);
      }
    }
    fs.writeFileSync(HTML, html, 'utf8');

    // ── Regenerar PDF desde el HTML actualizado ──
    console.log('5. Generando PDF...');
    const pdfPage = await context.newPage();
    await pdfPage.goto('file://' + HTML, { waitUntil: 'networkidle' });
    await sleep(800);
    await pdfPage.pdf({
      path: PDF,
      format: 'A4',
      printBackground: true,
      margin: { top: '12mm', bottom: '12mm', left: '12mm', right: '12mm' },
    });
    console.log('   PDF:', PDF);

    console.log('LISTO.');
  } catch (err) {
    console.error('ERROR:', err.message);
    try { await page.screenshot({ path: path.join(SHOTS, '_ERROR.png'), fullPage: true }); } catch {}
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();
