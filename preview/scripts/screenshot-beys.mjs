#!/usr/bin/env node
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PREVIEW = path.resolve(__dirname, '..');
const OUT = '/opt/cursor/artifacts/showcase/beys';
const BEYS = ['NovaStriker', 'IronShell', 'VoltDash', 'ShadowBite'];

function startServer(root) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const p = path.join(root, decodeURIComponent((req.url || '/').split('?')[0].slice(1) || 'index.html'));
      fs.readFile(p, (err, data) => {
        if (err) { res.writeHead(404); res.end(); return; }
        const ext = path.extname(p);
        const mime = { '.html': 'text/html', '.js': 'text/javascript' }[ext] || 'application/octet-stream';
        res.writeHead(200, { 'Content-Type': mime });
        res.end(data);
      });
    });
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({ server, url: `http://127.0.0.1:${port}/bey-showcase.html` });
    });
  });
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const { server, url } = await startServer(PREVIEW);
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/local/bin/google-chrome',
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 360, height: 480 });
  await page.goto(url, { waitUntil: 'networkidle0' });
  await page.waitForFunction(() => window.__BEY_SHOWCASE_READY__);

  for (const id of BEYS) {
    await page.screenshot({ path: path.join(OUT, `${id}.png`), type: 'png' });
    // scroll/next card - screenshot individual canvas
    const el = await page.$(`#canvas-${id}`);
    if (el) {
      await el.screenshot({ path: path.join(OUT, `${id}_close.png`) });
    }
  }

  await page.setViewport({ width: 1280, height: 900 });
  await page.goto(url, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: path.join(OUT, 'all-beys.png'), fullPage: true });

  await browser.close();
  server.close();
  console.log('Saved to', OUT);
}

main().catch(console.error);
