// Inline everything into self-contained HTML files (no fetch / import / external URLs):
// Android opens local HTML via content:// from the file manager, where relative sub-resources break.
// Usage: node eink/build.mjs  →  eink/dist/XEO-Rom-激活演示.html + eink/dist/租赁入口二维码.html
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const read = p => readFileSync(join(here, p), 'utf8');
// Brand logo used as-is (no redraw); only the XML prolog/comments are dropped and the viewBox trimmed to the mark
// with a safety margin, so it can sit inline at small sizes.
const logo = readFileSync(join(here, '..', 'brand', 'logo_black.svg'), 'utf8')
  .replace(/<\?xml[^>]*>\s*/, '').replace(/<!--[\s\S]*?-->/g, '')
  .replace('viewBox="0 0 180 180"', 'viewBox="12 60.5 156 59.7"').replace(/\s+id="[^"]*"/g, '');
const qr = read('vendor/qrcode-generator/qrcode.js');
const fill = html => html.replace('<!--@LOGO@-->', () => logo).replace('/*@QR@*/', () => qr)
  .replace('/*@CSS@*/', () => read('src/app.css')).replace('/*@JS@*/', () => read('src/app.js'));

mkdirSync(join(here, 'dist'), { recursive: true });
const out = [['src/shell.html', 'XEO-Rom-激活演示.html'], ['src/print.html', '租赁入口二维码.html']];
for (const [src, name] of out) {
  const html = fill(read(src));
  if (/https?:\/\/(?!www\.w3\.org)/.test(html.replace(/\/\/[^\n]*\n/g, ''))) console.warn('warning: external URL text in', name);
  writeFileSync(join(here, 'dist', name), html);
  console.log('wrote dist/' + name, (html.length / 1024).toFixed(0) + ' KB');
}
