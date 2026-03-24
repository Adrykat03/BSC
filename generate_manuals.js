const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const markdownpdf = require('markdown-pdf');

const users = [
    { email: 'maria.espinoza@bsc.com', role: 'Administrador', sections: ['Roles', 'Colaboradores'] },
    { email: 'carlos.mendoza@bsc.com', role: 'Gerente', sections: ['Tareas'] },
    { email: 'ana.torres@bsc.com', role: 'Lider', sections: ['Tareas'] },
    { email: 'sofia.herrera@bsc.com', role: 'Colaborador', sections: ['Tareas'] }
];

const pass = 'Test1234!';

(async () => {
    console.log("Starting browser...");
    const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });

    const capturasDir = path.join(__dirname, 'capturas');
    if (!fs.existsSync(capturasDir)) fs.mkdirSync(capturasDir, { recursive: true });

    for (let user of users) {
        console.log(`Processing role: ${user.role} (${user.email})`);
        const userDir = path.join(capturasDir, user.role.toLowerCase());
        if (!fs.existsSync(userDir)) fs.mkdirSync(userDir, { recursive: true });

        // Go to login
        await page.goto('http://localhost:3000/login');
        await page.waitForSelector('input[type="email"]');
        await page.screenshot({ path: path.join(userDir, '1_login.png') });

        // Login
        await page.type('input[type="email"]', user.email);
        await page.type('input[type="password"]', pass);
        await page.click('button[type="submit"]');

        // Wait for dashboard
        await page.waitForNavigation({ waitUntil: 'networkidle0' }).catch(()=>console.log("Network idle 0 timeout"));
        await new Promise(r => setTimeout(r, 2000));
        await page.screenshot({ path: path.join(userDir, '2_dashboard.png') });

        // Navigate to sections
        let step = 3;
        for (let section of user.sections) {
            console.log(`Navigating to ${section}...`);
            const links = await page.$$('a');
            let clicked = false;
            for (let link of links) {
                const text = await page.evaluate(el => el.textContent, link);
                if (text && text.trim() === section) {
                    await link.click();
                    clicked = true;
                    break;
                }
            }
            if (!clicked) {
                // If the link wasn't found using 'a', let's try other interactable elements like buttons, or nav links
                // or direct URL navigation like /roles or /colaboradores
                console.log(`Could not click ${section}, trying direct navigation`);
                await page.goto(`http://localhost:3000/${section.toLowerCase()}`);
            }
            await new Promise(r => setTimeout(r, 2000));
            await page.screenshot({ path: path.join(userDir, `${step}_${section.toLowerCase()}.png`) });
            step++;
        }

        // Logout
        try {
            await page.goto('http://localhost:3000/login'); // simple logout by returning to login if logout button is hard to find
            await page.evaluate(() => localStorage.clear()); // forcefully clear local storage token
        } catch (e) {
            console.log("Error logging out", e);
        }

        // Generate Markdown content
        console.log(`Generating Markdown for ${user.role}...`);
        let mdContent = `# Manual de Usuario - Perfil: ${user.role}\n\n`;
        mdContent += `Bienvenido al sistema BackOffice. Este manual describe paso a paso cómo utilizar la plataforma con el rol de **${user.role}**.\n\n`;
        mdContent += `## 1. Inicio de Sesión\n`;
        mdContent += `Ingrese a la plataforma utilizando su correo electrónico asignado y contraseña.\n\n`;
        mdContent += `![Login](${path.join(userDir, '1_login.png')})\n\n`;
        mdContent += `## 2. Pantalla Principal (Dashboard)\n`;
        mdContent += `Una vez inicie sesión, será redirigido a la pantalla principal.\n\n`;
        mdContent += `![Dashboard](${path.join(userDir, '2_dashboard.png')})\n\n`;

        let mdStep = 3;
        for (let section of user.sections) {
            mdContent += `## ${mdStep}. Sección ${section}\n`;
            mdContent += `Navegue a la sección **${section}** desde el menú.\n\n`;
            mdContent += `![${section}](${path.join(userDir, `${mdStep}_${section.toLowerCase()}.png`)})\n\n`;
            mdStep++;
        }

        const mdFile = path.join(__dirname, `manual_${user.role.toLowerCase()}.md`);
        const pdfFile = path.join(__dirname, `manual_${user.role.toLowerCase()}.pdf`);
        fs.writeFileSync(mdFile, mdContent);

        // Convert to PDF
        console.log(`Generating PDF for ${user.role}...`);
        await new Promise((resolve, reject) => {
            markdownpdf().from(mdFile).to(pdfFile, function () {
                console.log(`PDF created: ${pdfFile}`);
                resolve();
            });
        });
    }

    await browser.close();
    console.log("All tasks completed.");
})();
