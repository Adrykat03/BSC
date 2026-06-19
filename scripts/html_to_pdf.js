// Convierte un HTML a PDF con Chromium (Playwright). Respeta @page del CSS.
// Uso (en Docker Playwright):
//   docker run --rm -e IN=/work/docs/x.html -e OUT=/work/docs/x.pdf \
//     -e PLAYWRIGHT_BROWSERS_PATH=/ms-playwright -v "C:\Proyectos\BSC:/work" \
//     -w /work/scripts mcr.microsoft.com/playwright:v1.58.2-jammy node html_to_pdf.js

const { chromium } = require('playwright');

const IN = process.env.IN;
const OUT = process.env.OUT;

(async () => {
  if (!IN || !OUT) throw new Error('Faltan IN/OUT en env.');
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await (await browser.newContext()).newPage();
  await page.goto('file://' + IN, { waitUntil: 'networkidle' });
  await page.pdf({ path: OUT, printBackground: true, preferCSSPageSize: true });
  await browser.close();
  console.log('PDF generado:', OUT);
})();
