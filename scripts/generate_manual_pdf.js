const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const BASE_URL = process.env.BASE_URL || 'http://bsc_frontend:3000';
const API_URL = process.env.API_URL || 'http://bsc_backend:8080';
const OUTPUT = '/output/Manual_FlowPulse.pdf';
const SCREENSHOTS = '/output/screenshots';
const PASSWORD = 'Manual2026!';

const USERS = {
  gerente: { email: 'sabrina.chinchin@kfc.com.ec', role: 'Gerente' },
  admin: { email: 'katerin.carrillo@kfc.com.ec', role: 'Administrador' },
  lider: { email: 'maria.barreno@kfc.com.ec', role: 'Lider' },
  colaborador: { email: 'jhon.saltos@kfc.com.ec', role: 'Colaborador' },
};

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function login(page, email) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' });
  await sleep(500);
  await page.fill('input[type="email"]', email);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL(url => !url.toString().includes('/login'), { timeout: 10000 });
  await sleep(1500);
}

async function screenshot(page, name) {
  const filepath = path.join(SCREENSHOTS, `${name}.png`);
  await page.screenshot({ path: filepath, fullPage: false });
  console.log(`  Screenshot: ${name}`);
  return filepath;
}

async function screenshotFull(page, name) {
  const filepath = path.join(SCREENSHOTS, `${name}.png`);
  await page.screenshot({ path: filepath, fullPage: true });
  console.log(`  Screenshot (full): ${name}`);
  return filepath;
}

(async () => {
  fs.mkdirSync(SCREENSHOTS, { recursive: true });
  const screenshots = {};

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const context = await browser.newContext({ viewport: { width: 1366, height: 768 } });
  const page = await context.newPage();

  try {
    // ── LOGIN PAGE ──
    console.log('1. Login page...');
    await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' });
    await sleep(1000);
    screenshots.login = await screenshot(page, '01_login');

    // ── GERENTE ──
    console.log('2. Gerente views...');
    await login(page, USERS.gerente.email);

    // Dashboard
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await sleep(2000);
    screenshots.dashboard_gerente = await screenshot(page, '02_dashboard_gerente');
    screenshots.dashboard_gerente_full = await screenshotFull(page, '02b_dashboard_gerente_full');

    // Header (bell + user)
    screenshots.header = await page.locator('.header__right').screenshot({ path: path.join(SCREENSHOTS, '03_header.png') });
    screenshots.header = path.join(SCREENSHOTS, '03_header.png');
    console.log('  Screenshot: header');

    // Tasks page
    await page.goto(`${BASE_URL}/tasks`, { waitUntil: 'networkidle' });
    await sleep(1500);
    screenshots.tasks_gerente = await screenshot(page, '04_tasks_gerente');

    // Create task modal
    const newTaskBtn = page.locator('button', { hasText: 'Nueva Tarea' });
    if (await newTaskBtn.isVisible()) {
      await newTaskBtn.click();
      await sleep(800);
      screenshots.task_modal_create = await screenshot(page, '05_task_modal_create');
      // Close modal
      await page.locator('button[title="Cerrar sin guardar"]').click();
      await sleep(500);
    }

    // Edit first task
    const editBtn = page.locator('.table__actions .btn--ghost').first();
    if (await editBtn.isVisible()) {
      await editBtn.click();
      await sleep(800);
      screenshots.task_modal_edit = await screenshot(page, '06_task_modal_edit');

      // Scroll to see calificacion
      const modal = page.locator('.modal__body');
      if (await modal.isVisible()) {
        await modal.evaluate(el => el.scrollTop = el.scrollHeight / 2);
        await sleep(500);
        screenshots.task_modal_rating = await screenshot(page, '07_task_modal_rating');

        await modal.evaluate(el => el.scrollTop = el.scrollHeight);
        await sleep(500);
        screenshots.task_modal_evidence = await screenshot(page, '08_task_modal_evidence');
      }
      await page.locator('button[title="Cerrar sin guardar"]').click();
      await sleep(500);
    }

    // History modal
    const historyBtn = page.locator('[data-tooltip="Historial"]').first();
    if (await historyBtn.isVisible()) {
      await historyBtn.click();
      await sleep(800);
      screenshots.history_modal = await screenshot(page, '09_history_modal');
      await page.keyboard.press('Escape');
      await sleep(500);
    }

    // Alertas Payroll
    await page.goto(`${BASE_URL}/alertas-payroll`, { waitUntil: 'networkidle' });
    await sleep(2000);
    screenshots.alertas = await screenshot(page, '10_alertas_payroll');
    screenshots.alertas_full = await screenshotFull(page, '10b_alertas_payroll_full');

    // Logout
    await page.locator('.header__user').click();
    await sleep(300);
    await page.locator('.dropdown__item', { hasText: 'Cerrar sesion' }).click();
    await sleep(1000);

    // ── LIDER ──
    console.log('3. Lider views...');
    await login(page, USERS.lider.email);
    // Switch role to Lider if needed
    const roleBadge = page.locator('.header__user-info .badge');
    const currentRole = await roleBadge.textContent();
    if (currentRole.trim() !== 'Lider') {
      await page.locator('.header__user').click();
      await sleep(300);
      const liderBtn = page.locator('.dropdown__item', { hasText: 'Lider' });
      if (await liderBtn.isVisible()) {
        await liderBtn.click();
        await sleep(2000);
      }
    }

    await page.goto(`${BASE_URL}/tasks`, { waitUntil: 'networkidle' });
    await sleep(1500);
    screenshots.tasks_lider = await screenshot(page, '11_tasks_lider');

    // Logout
    await page.locator('.header__user').click();
    await sleep(300);
    await page.locator('.dropdown__item', { hasText: 'Cerrar sesion' }).click();
    await sleep(1000);

    // ── COLABORADOR ──
    console.log('4. Colaborador views...');
    await login(page, USERS.colaborador.email);
    await page.goto(`${BASE_URL}/tasks`, { waitUntil: 'networkidle' });
    await sleep(1500);
    screenshots.tasks_colaborador = await screenshot(page, '12_tasks_colaborador');

    // View detail
    const eyeBtn = page.locator('[data-tooltip="Ver detalle"]').first();
    if (await eyeBtn.isVisible()) {
      await eyeBtn.click();
      await sleep(800);
      screenshots.task_detail_colab = await screenshot(page, '13_task_detail_colab');
      await page.locator('button[title="Cerrar sin guardar"]').click();
      await sleep(500);
    }

    // Logout
    await page.locator('.header__user').click();
    await sleep(300);
    await page.locator('.dropdown__item', { hasText: 'Cerrar sesion' }).click();
    await sleep(1000);

    // ── ADMIN ──
    console.log('5. Admin views...');
    await login(page, USERS.admin.email);
    // Should redirect to /roles
    await sleep(1500);

    // Switch to Administrador if needed
    const adminBadge = page.locator('.header__user-info .badge');
    const adminRole = await adminBadge.textContent();
    if (adminRole.trim() !== 'Administrador') {
      await page.locator('.header__user').click();
      await sleep(300);
      const adminBtn = page.locator('.dropdown__item', { hasText: 'Administrador' });
      if (await adminBtn.isVisible()) {
        await adminBtn.click();
        await sleep(2000);
      }
    }

    await page.goto(`${BASE_URL}/roles`, { waitUntil: 'networkidle' });
    await sleep(1500);
    screenshots.roles = await screenshot(page, '14_roles');

    await page.goto(`${BASE_URL}/colaboradores`, { waitUntil: 'networkidle' });
    await sleep(1500);
    screenshots.colaboradores = await screenshot(page, '15_colaboradores');

    // ═══════════════════════════════════
    //  GENERATE PDF WITH SCREENSHOTS
    // ═══════════════════════════════════
    console.log('6. Generating PDF...');

    const screenshotFiles = fs.readdirSync(SCREENSHOTS).filter(f => f.endsWith('.png')).sort();
    const images = {};
    screenshotFiles.forEach(f => {
      const name = f.replace('.png', '');
      const data = fs.readFileSync(path.join(SCREENSHOTS, f));
      images[name] = `data:image/png;base64,${data.toString('base64')}`;
    });

    const manualHtml = buildManualHtml(images);
    const pdfPage = await context.newPage();
    await pdfPage.setContent(manualHtml, { waitUntil: 'networkidle' });
    await sleep(1000);
    await pdfPage.pdf({
      path: OUTPUT,
      format: 'A4',
      margin: { top: '12mm', bottom: '12mm', left: '14mm', right: '14mm' },
      printBackground: true,
    });

    console.log(`PDF saved to ${OUTPUT}`);

  } catch (err) {
    console.error('Error:', err.message);
    // Take error screenshot
    await page.screenshot({ path: path.join(SCREENSHOTS, 'ERROR.png') });
  } finally {
    await browser.close();
  }
})();

function buildManualHtml(img) {
  const ss = (name) => img[name] ? `<div class="screenshot"><img src="${img[name]}" /></div>` : '';

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<style>
  @page { margin: 0; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', Arial, sans-serif; color: #1f2937; line-height: 1.6; font-size: 11px; }
  .cover { background: linear-gradient(135deg, #E31837 0%, #a01228 100%); color: #fff; padding: 120px 40px 80px; text-align: center; page-break-after: always; height: 100vh; display: flex; flex-direction: column; justify-content: center; }
  .cover h1 { font-size: 52px; margin-bottom: 10px; letter-spacing: 2px; }
  .cover .subtitle { font-size: 22px; opacity: 0.95; margin-bottom: 6px; }
  .cover .desc { font-size: 16px; opacity: 0.8; }
  .cover .version { margin-top: 40px; font-size: 13px; opacity: 0.6; }
  .toc { page-break-after: always; padding: 40px 20px; }
  .toc h2 { color: #E31837; font-size: 24px; margin-bottom: 20px; border-bottom: 2px solid #E31837; padding-bottom: 6px; }
  .toc ol { list-style: none; counter-reset: toc; padding: 0; }
  .toc li { counter-increment: toc; padding: 6px 0; font-size: 13px; border-bottom: 1px dotted #d1d5db; }
  .toc li::before { content: counter(toc) "."; font-weight: 700; color: #E31837; margin-right: 10px; display: inline-block; width: 24px; }
  h2 { color: #E31837; font-size: 22px; margin: 0 0 12px 0; padding: 30px 0 6px 0; border-bottom: 2px solid #E31837; page-break-before: always; }
  h2:first-of-type { page-break-before: avoid; }
  h3 { color: #374151; font-size: 15px; margin: 18px 0 8px 0; page-break-after: avoid; }
  h4 { color: #4b5563; font-size: 12px; margin: 14px 0 6px 0; page-break-after: avoid; }
  p { margin-bottom: 8px; font-size: 11px; }
  ul, ol { padding-left: 20px; margin-bottom: 10px; }
  li { margin-bottom: 4px; font-size: 11px; }
  table { width: 100%; border-collapse: collapse; margin: 10px 0 14px; font-size: 10px; page-break-inside: avoid; }
  th { background: #E31837; color: #fff; padding: 6px 10px; text-align: left; font-weight: 600; }
  td { padding: 6px 10px; border-bottom: 1px solid #e5e7eb; }
  tr:nth-child(even) { background: #f3f4f6; }
  .tip { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 8px 12px; margin: 10px 0; border-radius: 0 6px 6px 0; font-size: 10px; page-break-inside: avoid; }
  .tip strong { color: #92400e; }
  .note { background: #dbeafe; border-left: 4px solid #3b82f6; padding: 8px 12px; margin: 10px 0; border-radius: 0 6px 6px 0; font-size: 10px; page-break-inside: avoid; }
  .note strong { color: #1e40af; }
  .screenshot { margin: 12px 0; text-align: center; page-break-inside: avoid; }
  .screenshot img { max-width: 100%; border: 1px solid #d1d5db; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
  .badge { display: inline-block; padding: 1px 8px; border-radius: 10px; font-size: 9px; font-weight: 600; color: #fff; }
  .badge--creada { background: #7B8794; } .badge--asignada { background: #4A90D9; }
  .badge--cpv { background: #F5A623; } .badge--reasignada { background: #E85D75; }
  .badge--cv { background: #50C878; } .badge--completa { background: #2E7D32; }
  .badge--cancelada { background: #B71C1C; }
  .flow { display: flex; align-items: center; justify-content: center; gap: 6px; margin: 14px 0; flex-wrap: wrap; page-break-inside: avoid; }
  .flow-step { padding: 6px 14px; border-radius: 6px; color: #fff; font-weight: 600; font-size: 10px; }
  .flow-arrow { color: #9ca3af; font-size: 16px; }
  .star { color: #F59E0B; font-size: 14px; } .star-gray { color: #D1D5DB; font-size: 14px; }
  footer { text-align: center; color: #9ca3af; font-size: 9px; margin-top: 30px; padding-top: 10px; border-top: 1px solid #e5e7eb; }
</style>
</head>
<body>

<!-- PORTADA -->
<div class="cover">
  <h1>FlowPulse</h1>
  <div class="subtitle">Manual de Usuario</div>
  <div class="desc">Sistema de Gestion de Tareas y Alertas de Nomina</div>
  <div class="version">Version 1.0 &mdash; Marzo 2026</div>
</div>

<!-- TOC -->
<div class="toc">
  <h2 style="page-break-before:avoid;">Contenido</h2>
  <ol>
    <li>Introduccion</li>
    <li>Inicio de Sesion</li>
    <li>Roles del Sistema</li>
    <li>Navegacion</li>
    <li>Dashboard</li>
    <li>Gestion de Tareas</li>
    <li>Calificacion de Tareas</li>
    <li>Carga de Evidencia</li>
    <li>Exportar e Importar Tareas</li>
    <li>Administracion de Roles</li>
    <li>Administracion de Colaboradores</li>
    <li>Alertas Payroll</li>
    <li>Notificaciones</li>
    <li>Flujo de Estados de Tareas</li>
    <li>Preguntas Frecuentes</li>
  </ol>
</div>

<!-- 1 -->
<h2>1. Introduccion</h2>
<p><strong>FlowPulse</strong> es un sistema BackOffice para la gestion de tareas y monitoreo de alertas de nomina. Permite a los equipos organizar, asignar, dar seguimiento y calificar tareas de forma colaborativa, con controles diferenciados por rol.</p>
<table>
  <tr><th>Rol</th><th>Descripcion</th></tr>
  <tr><td><strong>Administrador</strong></td><td>Gestiona roles y colaboradores del sistema</td></tr>
  <tr><td><strong>Gerente</strong></td><td>Crea tareas, asigna lideres, aprueba completadas, ve dashboard completo</td></tr>
  <tr><td><strong>Lider</strong></td><td>Asigna colaboradores, valida tareas completadas, califica</td></tr>
  <tr><td><strong>Colaborador</strong></td><td>Ejecuta tareas, sube evidencia, envia a validacion</td></tr>
</table>

<!-- 2 -->
<h2>2. Inicio de Sesion</h2>
<p>Para acceder al sistema:</p>
<ol>
  <li>Ingrese a la URL del sistema en su navegador.</li>
  <li>Introduzca su <strong>correo electronico</strong> corporativo.</li>
  <li>Introduzca su <strong>contrasena</strong>.</li>
  <li>Haga clic en <strong>"Iniciar sesion"</strong>.</li>
</ol>
${ss('01_login')}
<div class="tip"><strong>Consejo:</strong> Si tiene multiples roles asignados, al iniciar sesion se activara el rol de mayor privilegio. Puede cambiar de rol desde el menu de usuario en la esquina superior derecha.</div>

<h3>Cambiar de Rol</h3>
<p>Si su cuenta tiene mas de un rol:</p>
<ol>
  <li>Haga clic en su nombre en la esquina superior derecha.</li>
  <li>En el menu desplegable, seleccione el rol al que desea cambiar.</li>
  <li>La pagina se recargara con los permisos del nuevo rol.</li>
</ol>

<!-- 3 -->
<h2>3. Roles del Sistema</h2>
<h3>Administrador</h3>
<ul>
  <li>Accede a: <strong>Roles</strong>, <strong>Colaboradores</strong>, <strong>Alertas Payroll</strong></li>
  <li>No tiene acceso al Dashboard ni a Tareas</li>
  <li>Crea, edita y elimina roles y usuarios del sistema</li>
</ul>
<h3>Gerente</h3>
<ul>
  <li>Accede a: <strong>Dashboard</strong>, <strong>Tareas</strong>, <strong>Alertas Payroll</strong></li>
  <li>Crea y edita tareas, asigna Lideres</li>
  <li>Aprueba tareas como "Completa" o las devuelve</li>
  <li>Cancela y restaura tareas, califica tareas (1-10 estrellas)</li>
  <li>Descarga reportes XLSX completos</li>
</ul>
<h3>Lider</h3>
<ul>
  <li>Accede a: <strong>Dashboard</strong>, <strong>Tareas</strong>, <strong>Alertas Payroll</strong></li>
  <li>Asigna tareas a Colaboradores, valida tareas completadas</li>
  <li>Reasigna tareas si requieren correccion</li>
  <li>Califica tareas (1-10 estrellas)</li>
</ul>
<h3>Colaborador</h3>
<ul>
  <li>Accede a: <strong>Dashboard</strong> (vista limitada), <strong>Tareas</strong>, <strong>Alertas Payroll</strong></li>
  <li>Ve el detalle de tareas asignadas, sube evidencia</li>
  <li>Envia tareas a validacion</li>
</ul>

<!-- 4 -->
<h2>4. Navegacion</h2>
<h3>Barra Lateral</h3>
<table>
  <tr><th>Menu</th><th>Admin</th><th>Gerente</th><th>Lider</th><th>Colaborador</th></tr>
  <tr><td>Dashboard</td><td>-</td><td>Si</td><td>Si</td><td>Si</td></tr>
  <tr><td>Tareas</td><td>-</td><td>Si</td><td>Si</td><td>Si</td></tr>
  <tr><td>Roles</td><td>Si</td><td>-</td><td>-</td><td>-</td></tr>
  <tr><td>Colaboradores</td><td>Si</td><td>-</td><td>-</td><td>-</td></tr>
  <tr><td>Alertas Payroll</td><td>Si</td><td>Si</td><td>Si</td><td>Si</td></tr>
</table>
<h3>Barra Superior</h3>
<p>Contiene: titulo de la pagina, icono de ayuda (descarga este manual), campana de notificaciones y menu de usuario.</p>
${ss('03_header')}

<!-- 5 -->
<h2>5. Dashboard</h2>
<p>El Dashboard presenta un resumen estadistico de las tareas. El contenido varia segun su rol.</p>
${ss('02_dashboard_gerente')}
<h3>Componentes del Dashboard</h3>
<table>
  <tr><th>Componente</th><th>Gerente</th><th>Lider</th><th>Colaborador</th></tr>
  <tr><td>Tarjetas KPI</td><td>Si</td><td>-</td><td>-</td></tr>
  <tr><td>Mapa de calor</td><td>Si</td><td>Si</td><td>-</td></tr>
  <tr><td>Tiempo promedio por estado</td><td>Si</td><td>Si</td><td>Si</td></tr>
  <tr><td>Distribucion por estado</td><td>Si</td><td>Si</td><td>Si</td></tr>
  <tr><td>Por colaborador y estado</td><td>Si</td><td>Si</td><td>Si</td></tr>
  <tr><td>Descargar reporte XLSX</td><td>Si</td><td>-</td><td>-</td></tr>
</table>

<!-- 6 -->
<h2>6. Gestion de Tareas</h2>
<h3>Vista de Tareas — Gerente</h3>
${ss('04_tasks_gerente')}

<h3>Vista de Tareas — Lider</h3>
${ss('11_tasks_lider')}

<h3>Vista de Tareas — Colaborador</h3>
${ss('12_tasks_colaborador')}

<h3>Crear Tarea</h3>
<ol>
  <li>Haga clic en <strong>"+ Nueva Tarea"</strong>.</li>
  <li>Complete: Titulo, Descripcion, Fecha de entrega, Tiempo estimado, Insumos, Observaciones.</li>
  <li>Opcionalmente asigne un Lider.</li>
  <li>Haga clic en <strong>"Guardar"</strong>.</li>
</ol>
${ss('05_task_modal_create')}

<h3>Editar Tarea</h3>
<p>Haga clic en el icono de lapiz para abrir el modal de edicion.</p>
${ss('06_task_modal_edit')}
<div class="note"><strong>Nota:</strong> El Lider no puede modificar la fecha de entrega. Solo el Gerente puede hacerlo.</div>

<h3>Estados de una Tarea</h3>
<table>
  <tr><th>Estado</th><th>Significado</th><th>Color</th></tr>
  <tr><td><span class="badge badge--creada">Creada</span></td><td>Recien creada, sin asignar</td><td>Gris</td></tr>
  <tr><td><span class="badge badge--asignada">Asignada</span></td><td>Asignada a lider o colaborador</td><td>Azul</td></tr>
  <tr><td><span class="badge badge--cpv">Completa - Por Validar</span></td><td>Esperando validacion</td><td>Naranja</td></tr>
  <tr><td><span class="badge badge--reasignada">Reasignada</span></td><td>Devuelta para correccion</td><td>Rojo</td></tr>
  <tr><td><span class="badge badge--cv">Completa - Validada</span></td><td>Validada, pendiente aprobacion</td><td>Verde claro</td></tr>
  <tr><td><span class="badge badge--completa">Completa</span></td><td>Finalizada</td><td>Verde</td></tr>
  <tr><td><span class="badge badge--cancelada">Cancelada</span></td><td>Cancelada</td><td>Rojo oscuro</td></tr>
</table>

<h3>Cambiar Estado</h3>
<table>
  <tr><th>Rol</th><th>Estado Actual</th><th>Puede cambiar a</th></tr>
  <tr><td>Gerente</td><td>Completa - Validada</td><td>Completa, Reasignada, CPV</td></tr>
  <tr><td>Gerente</td><td>Asignada/CPV/Reasignada/CV</td><td>Cancelada</td></tr>
  <tr><td>Lider</td><td>Completa - Por Validar</td><td>C. Validada, Reasignada</td></tr>
  <tr><td>Colaborador</td><td>Asignada/Reasignada</td><td>Completa - Por Validar</td></tr>
</table>

<h3>Historial de una Tarea</h3>
<p>Haga clic en el icono de reloj para ver la linea de tiempo de cambios.</p>
${ss('09_history_modal')}

<!-- 7 -->
<h2>7. Calificacion de Tareas</h2>
<p>El Lider y el Gerente pueden calificar tareas con <strong>10 estrellas</strong>.</p>
<ol>
  <li>Abra la tarea.</li>
  <li>En "Calificacion", haga clic en la estrella deseada: <span class="star">&#9733;&#9733;&#9733;&#9733;&#9733;&#9733;&#9733;</span><span class="star-gray">&#9733;&#9733;&#9733;</span> = 7/10</li>
  <li>La calificacion se guarda al hacer clic en Guardar, cambiar estado o asignar.</li>
</ol>
${ss('07_task_modal_rating')}
<div class="tip"><strong>Importante:</strong> Las estrellas cambian visualmente al hacer clic. Se persisten al presionar un boton de accion.</div>

<!-- 8 -->
<h2>8. Carga de Evidencia</h2>
<ol>
  <li>Abra el detalle de la tarea.</li>
  <li>En "Evidencia (texto)", describa el trabajo.</li>
  <li>En "Archivos de evidencia", arrastre o seleccione archivos (max 20MB).</li>
  <li>Haga clic en "Guardar".</li>
</ol>
${ss('08_task_modal_evidence')}
${ss('13_task_detail_colab')}

<!-- 9 -->
<h2>9. Exportar e Importar Tareas</h2>
<h3>Exportar a Excel</h3>
<p>Desde Tareas, haga clic en el icono de descarga. Se genera un .xlsx con todas las tareas incluyendo calificacion.</p>
<h3>Importar (Carga Masiva)</h3>
<ol>
  <li>Descargue la plantilla.</li>
  <li>Complete los datos (max 100 tareas).</li>
  <li>Suba el archivo .xlsx.</li>
</ol>
<table>
  <tr><th>Columna</th><th>Requerida</th><th>Descripcion</th></tr>
  <tr><td>Titulo</td><td>Si</td><td>Nombre de la tarea</td></tr>
  <tr><td>Descripcion</td><td>Si</td><td>Descripcion detallada</td></tr>
  <tr><td>Fecha de entrega</td><td>Si</td><td>DD/MM/AAAA HH:mm</td></tr>
  <tr><td>Tiempo estimado (h)</td><td>Si</td><td>Horas estimadas</td></tr>
  <tr><td>Insumos</td><td>No</td><td>Recursos necesarios</td></tr>
  <tr><td>Email lider</td><td>No</td><td>Correo del lider</td></tr>
  <tr><td>Email colaborador</td><td>No</td><td>Correo del colaborador</td></tr>
</table>

<!-- 10 -->
<h2>10. Administracion de Roles</h2>
<p><em>Solo Administrador.</em></p>
${ss('14_roles')}
<ol>
  <li>Navegue a <strong>Roles</strong>.</li>
  <li>Haga clic en <strong>"+ Nuevo Rol"</strong>.</li>
  <li>Ingrese nombre y descripcion.</li>
  <li>Haga clic en <strong>"Guardar"</strong>.</li>
</ol>

<!-- 11 -->
<h2>11. Administracion de Colaboradores</h2>
<p><em>Solo Administrador.</em></p>
${ss('15_colaboradores')}
<h4>Requisitos de Contrasena</h4>
<ul>
  <li>Minimo 8 caracteres</li>
  <li>Al menos una mayuscula, una minuscula, un numero</li>
  <li>Al menos un caracter especial (@$!%*?&#)</li>
</ul>

<!-- 12 -->
<h2>12. Alertas Payroll</h2>
<p>Dashboard de notificaciones del sistema de nomina.</p>
${ss('10_alertas_payroll')}
<h3>Indicadores</h3>
<ul>
  <li><strong>Total Alertas</strong> — Numero total</li>
  <li><strong>Activas</strong> — Requieren atencion</li>
  <li><strong>En Proceso</strong> — Siendo atendidas</li>
  <li><strong>Resueltas</strong> — Solucionadas</li>
  <li><strong>Caducadas</strong> — Expiraron</li>
  <li><strong>Error Envio</strong> — Fallas de notificacion</li>
</ul>

<!-- 13 -->
<h2>13. Notificaciones</h2>
<p>En la barra superior encontrara un icono de campana con un circulo rojo que indica tareas pendientes (Asignada o Reasignada). Se actualiza cada 60 segundos.</p>

<!-- 14 -->
<h2>14. Flujo de Estados de Tareas</h2>
<div class="flow">
  <span class="flow-step" style="background:#7B8794;">Creada</span>
  <span class="flow-arrow">&rarr;</span>
  <span class="flow-step" style="background:#4A90D9;">Asignada</span>
  <span class="flow-arrow">&rarr;</span>
  <span class="flow-step" style="background:#F5A623;">CPV</span>
  <span class="flow-arrow">&rarr;</span>
  <span class="flow-step" style="background:#50C878;">C. Validada</span>
  <span class="flow-arrow">&rarr;</span>
  <span class="flow-step" style="background:#2E7D32;">Completa</span>
</div>
<p style="text-align:center; color:#9ca3af; font-size:10px;">Flujos alternativos: Reasignar (devolver) | Cancelar (solo Gerente)</p>
<ol>
  <li>Gerente crea la tarea &rarr; Creada</li>
  <li>Gerente asigna Lider &rarr; Asignada</li>
  <li>Lider asigna Colaborador &rarr; Asignada</li>
  <li>Colaborador completa &rarr; Completa - Por Validar</li>
  <li>Lider valida &rarr; Completa - Validada</li>
  <li>Gerente aprueba &rarr; Completa</li>
</ol>

<!-- 15 -->
<h2>15. Preguntas Frecuentes</h2>
<h4>No puedo ver mis tareas</h4>
<p>Verifique que inicio sesion con el rol correcto. Cambie de rol desde el menu de usuario.</p>
<h4>No puedo cambiar el estado</h4>
<p>Solo puede cambiar a estados permitidos para su rol. Vea la tabla de transiciones en la seccion 6.</p>
<h4>La calificacion no se guarda</h4>
<p>Las estrellas son un selector visual. Se guardan al presionar Guardar o cambiar estado.</p>
<h4>No puedo crear tareas</h4>
<p>Solo Gerente y Lider pueden crear tareas.</p>
<h4>El archivo no se sube</h4>
<p>Verifique que no supere 20 MB.</p>

<footer>FlowPulse &copy; 2026 &mdash; Manual de Usuario v1.0</footer>
</body>
</html>`;
}
