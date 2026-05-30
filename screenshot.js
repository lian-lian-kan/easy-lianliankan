import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch({
    args: [
      '--enable-webgl',
      '--enable-webgl2',
      '--ignore-gpu-blocklist',
      '--use-gl=angle',
    ]
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
  });

  const page = await context.newPage();

  // Capture console logs
  page.on('console', msg => console.log('BROWSER CONSOLE:', msg.type(), msg.text()));
  page.on('pageerror', err => console.log('PAGE ERROR:', err.message));

  // Navigate and wait for Godot to load
  await page.goto('http://localhost:50511/demo/', { waitUntil: 'networkidle' });

  // Wait for Godot to initialize (25MB pck needs more time)
  await page.waitForTimeout(60000);

  // Take screenshot
  await page.screenshot({ path: '/Users/cc11001100/github/lian-lian-kan/easy-lianliankan/screenshot.png', fullPage: false });

  await browser.close();
  console.log('Screenshot saved');
})();
