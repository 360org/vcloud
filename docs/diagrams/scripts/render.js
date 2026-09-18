const puppeteer = require('puppeteer');
(async () => {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    await page.goto('file:///media/tanma/DATA/save/mobile_versions/docs/img/diagram_attendance.html', {waitUntil: 'networkidle0'});
    const element = await page.$('#container');
    await element.screenshot({path: '/media/tanma/DATA/save/mobile_versions/docs/img/diagram_attendance_activity.png'});
    await browser.close();
})();
