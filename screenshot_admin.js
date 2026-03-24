const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
    const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });

    const capturasDir = './capturas/admin';
    if (!fs.existsSync(capturasDir)) fs.mkdirSync(capturasDir, { recursive: true });

    // 1. Login
    await page.goto('http://localhost:3000/login');
    await page.screenshot({ path: `${capturasDir}/1_login.png` });

    await page.type('input[type="email"]', 'maria.espinoza@bsc.com');
    await page.type('input[type="password"]', 'Test1234!');
    await page.click('button[type="submit"]');

    // Wait for navigation to dashboard
    await page.waitForNavigation();
    // Wait a bit fully
    await new Promise(r => setTimeout(r, 2000));
    await page.screenshot({ path: `${capturasDir}/2_dashboard.png` });

    // 2. Roles
    const links = await page.$$('a');
    for (let link of links) {
        const text = await page.evaluate(el => el.textContent, link);
        if (text && text.includes('Roles')) {
            await link.click();
            break;
        }
    }
    await new Promise(r => setTimeout(r, 2000));
    await page.screenshot({ path: `${capturasDir}/3_roles.png` });

    // 3. Colaboradores
    for (let link of links) {
        const text = await page.evaluate(el => el.textContent, link);
        if (text && text.includes('Colaboradores')) {
            await link.click();
            break;
        }
    }
    await new Promise(r => setTimeout(r, 2000));
    await page.screenshot({ path: `${capturasDir}/4_colaboradores.png` });

    await browser.close();
    console.log("Screenshots saved for Administrador.");
})();
