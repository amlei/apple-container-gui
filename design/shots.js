const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({
    executablePath: '/Users/amlei/Library/Caches/ms-playwright/chromium_headless_shell-1223/chrome-headless-shell-mac-arm64/chrome-headless-shell'
  });
  const page = await browser.newPage({ viewport: { width: 1500, height: 960 } });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));

  await page.goto('file://' + __dirname + '/index.html');
  await page.waitForTimeout(900);
  await page.screenshot({ path: '/tmp/acg/01-overview.png' });

  await page.click('[data-route="containers"]');
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/acg/02-containers.png' });

  await page.click('tr[data-id="postgres-db"]');
  await page.waitForTimeout(600);
  await page.screenshot({ path: '/tmp/acg/03-ct-drawer-info.png' });

  await page.click('[data-tab="stats"]');
  await page.waitForTimeout(1400);
  await page.screenshot({ path: '/tmp/acg/04-ct-drawer-stats.png' });

  await page.click('[data-tab="logs"]');
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/acg/05-ct-drawer-logs.png' });

  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);
  await page.click('[data-action="open-run"]');
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/acg/06-run-sheet.png' });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);

  await page.click('[data-route="images"]');
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/acg/07-images.png' });

  await page.click('[data-action="open-pull"]');
  await page.waitForTimeout(400);
  await page.fill('#pf-ref', 'python:3.13-alpine');
  await page.click('#sheet-submit');
  await page.waitForTimeout(1600);
  await page.screenshot({ path: '/tmp/acg/08-pull-progress.png' });
  await page.waitForTimeout(2600);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);

  await page.click('[data-route="networks"]');
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/acg/09-networks.png' });

  await page.click('[data-route="machines"]');
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/acg/10-machines.png' });

  await page.click('[data-route="settings"]');
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/acg/11-settings.png' });

  await page.click('[data-action="open-lang-menu"]');
  await page.waitForTimeout(300);
  await page.screenshot({ path: '/tmp/acg/lang-menu.png' });
  await page.click('.menu button:has-text("English")');
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/acg/12-settings-en.png' });

  await page.click('[data-action="open-lang-menu"]');
  await page.waitForTimeout(250);
  await page.click('.menu button:has-text("简体中文")');
  await page.waitForTimeout(300);

  await page.evaluate(() => { const c = document.querySelector('#view-root'); c.scrollTop = c.scrollHeight; });
  await page.waitForTimeout(300);
  await page.screenshot({ path: '/tmp/acg/14-shortcuts.png' });

  await page.click('[data-rec="nav.containers"]');
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+Alt+8');
  await page.waitForTimeout(300);
  await page.evaluate(() => { const c = document.querySelector('#view-root'); c.scrollTop = c.scrollHeight; });
  await page.screenshot({ path: '/tmp/acg/15-shortcut-rebound.png' });
  await page.keyboard.press('Control+Alt+8');
  await page.waitForTimeout(300);
  const routeAfterKbd = await page.evaluate(() => document.querySelector('.page-head h1').textContent);
  console.log('SHORTCUT_NAV_OK:', routeAfterKbd);

  await page.keyboard.press('Meta+2');
  await page.waitForTimeout(300);

  await page.click('[data-route="overview"]');
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/acg/13-overview-dark.png' });

  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'NO_CONSOLE_ERRORS');
  await browser.close();
})();
