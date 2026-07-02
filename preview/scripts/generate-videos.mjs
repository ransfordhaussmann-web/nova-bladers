#!/usr/bin/env node
/**
 * Renders phase-accurate special move previews as MP4 videos.
 * Uses deterministic frame stepping (not real-time capture).
 */
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PREVIEW_DIR = path.resolve(__dirname, '..');
const OUT_DIR = path.join(PREVIEW_DIR, 'videos');

const MOVES = [
  'NovaMeteorShower',
  'IronVaultLock',
  'VoltSonicTempest',
  'ShadowEclipseFang',
];

const FPS = 30;
const WIDTH = 640;
const HEIGHT = 360;

const MIME = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.mp4': 'video/mp4',
  '.png': 'image/png',
};

function startServer(root) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const urlPath = decodeURIComponent((req.url ?? '/').split('?')[0]);
      const filePath = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
      if (!filePath.startsWith(root)) {
        res.writeHead(403);
        res.end();
        return;
      }
      fs.readFile(filePath, (err, data) => {
        if (err) {
          res.writeHead(404);
          res.end('Not found');
          return;
        }
        const ext = path.extname(filePath);
        res.writeHead(200, { 'Content-Type': MIME[ext] ?? 'application/octet-stream' });
        res.end(data);
      });
    });
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({ server, port, baseUrl: `http://127.0.0.1:${port}` });
    });
  });
}

async function renderMove(browser, baseUrl, moveId) {
  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: 1 });

  const pageUrl = `${baseUrl}/video-studio.html?move=${moveId}`;
  await page.goto(pageUrl, { waitUntil: 'networkidle0' });
  await page.waitForFunction(() => window.__STUDIO_READY__ === true, { timeout: 10000 });

  const duration = await page.evaluate(() => window.getMoveDuration());
  const frameCount = Math.ceil(duration * FPS);
  const tmpDir = path.join(OUT_DIR, `_frames_${moveId}`);
  fs.mkdirSync(tmpDir, { recursive: true });

  console.log(`  ${moveId}: ${frameCount} frames (${duration.toFixed(2)}s)`);

  for (let i = 0; i < frameCount; i++) {
    const elapsed = i / FPS;
    await page.evaluate((t) => window.renderAt(t), elapsed);
    const framePath = path.join(tmpDir, `frame-${String(i).padStart(5, '0')}.png`);
    await page.screenshot({ path: framePath, type: 'png' });
  }

  await page.close();

  const mp4Path = path.join(OUT_DIR, `${moveId}.mp4`);
  execSync(
    `ffmpeg -y -framerate ${FPS} -i "${tmpDir}/frame-%05d.png" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "${mp4Path}"`,
    { stdio: 'pipe' }
  );

  fs.rmSync(tmpDir, { recursive: true, force: true });
  return mp4Path;
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const { server, baseUrl } = await startServer(PREVIEW_DIR);
  console.log(`Preview server: ${baseUrl}`);

  console.log('Launching headless Chrome…');
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/local/bin/google-chrome',
  });

  try {
    for (const moveId of MOVES) {
      console.log(`Rendering ${moveId}…`);
      const mp4 = await renderMove(browser, baseUrl, moveId);
      const sizeKb = Math.round(fs.statSync(mp4).size / 1024);
      console.log(`  ✓ ${path.basename(mp4)} (${sizeKb} KB)`);
    }
  } finally {
    await browser.close();
    server.close();
  }

  console.log('\nDone — videos in preview/videos/');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
