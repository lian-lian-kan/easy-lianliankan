const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch({
    args: ['--enable-webgl', '--enable-webgl2', '--ignore-gpu-blocklist', '--use-gl=angle'],
  });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:50511/demo/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(28000);
  await page.screenshot({ path: 'output/mobile-portrait-v2.png', fullPage: false });
  await browser.close();
  console.log('saved output/mobile-portrait-v2.png');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
