const path = require('path');
const {pathToFileURL} = require('url');
const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    const input = path.join(__dirname, '..', 'attendance', 'diagram_attendance.html');
    const output = path.join(__dirname, '..', 'attendance', 'diagram_attendance_activity.png');
    await page.goto(pathToFileURL(input).href, {waitUntil: 'networkidle0'});
    const element = await page.$('#container');
    await element.screenshot({path: output});
    await browser.close();
})();
