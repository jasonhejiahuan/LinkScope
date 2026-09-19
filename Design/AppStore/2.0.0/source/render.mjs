#!/usr/bin/env node
// Local, deterministic composition. Reads original JPEG/PNG bytes without changing source files.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';

const require = createRequire(import.meta.url);
const sourceDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(sourceDir);
const bundledModules = path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
let sharp;
try { sharp = require('sharp'); }
catch { sharp = require(path.join(process.env.LINKSCOPE_NODE_MODULES || bundledModules, 'sharp')); }

const argv = process.argv.slice(2);
const value = (flag) => {
  const i = argv.indexOf(flag);
  if (i < 0) return null;
  if (!argv[i + 1] || argv[i + 1].startsWith('--')) throw new Error(`${flag} requires a value`);
  return argv[i + 1];
};
const onlyLocale = value('--locale');
const onlyScene = value('--scene');
const preflight = argv.includes('--preflight');
const config = JSON.parse(await fs.readFile(path.join(sourceDir, 'copy.json'), 'utf8'));
const templates = {
  svg: await fs.readFile(path.join(sourceDir, 'template.svg'), 'utf8'),
  html: await fs.readFile(path.join(sourceDir, 'template.html'), 'utf8'),
};
const xml = (s) => String(s).replace(/[&<>"']/g, (c) => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&apos;'}[c]));
const hash = (buf) => createHash('sha256').update(buf).digest('hex');
const renderTemplate = (template, replacements) => {
  const result = template.replace(/\{\{([A-Z_]+)\}\}/g, (match, key) => {
    if (!(key in replacements)) throw new Error(`Unresolved template field ${key}`);
    return replacements[key];
  });
  return result;
};
const selections = [];
const missing = [];
for (const [locale, localized] of Object.entries(config.locales)) {
  if (onlyLocale && locale !== onlyLocale) continue;
  for (const scene of localized.scenes) {
    if (onlyScene && scene.id !== onlyScene) continue;
    const base = path.join(root, 'captured', `${scene.id}-${localized.captureSuffix}`);
    const available = [];
    for (const extension of ['jpg', 'png']) {
      const candidate = `${base}.${extension}`;
      try { await fs.access(candidate); available.push(candidate); }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
    if (available.length > 1) throw new Error(`Ambiguous captures: keep only one .jpg or .png for ${base}`);
    const input = available[0];
    if (!input) missing.push(`${path.relative(root, base)}.{jpg,png}`);
    selections.push({locale, localized, scene, input});
  }
}
if (!selections.length) throw new Error('No matching shots; use --locale en-US|zh-Hans and --scene providers|dashboard|diagnostics|permissions.');
console.log(`sharp ${sharp.versions.sharp}; librsvg ${sharp.versions.rsvg}; ${selections.length} selected layouts`);
if (missing.length) {
  console.log(`Missing real captures:\n${missing.map((p) => `  ${p}`).join('\n')}`);
  if (!preflight) throw new Error('Capture the missing real app windows before rendering. No substitute image is generated.');
}
if (preflight) {
  console.log('Preflight only: templates loaded, no source images or output files changed.');
  process.exit(0);
}

const records = [];
for (const {locale, localized, scene, input} of selections) {
  const original = await fs.readFile(input);
  const inputHash = hash(original);
  const meta = await sharp(original).metadata();
  if (!['jpeg', 'png'].includes(meta.format) || !meta.width || !meta.height) throw new Error(`Expected valid capture JPEG or PNG: ${input}`);
  const inputMIME = meta.format === 'jpeg' ? 'image/jpeg' : 'image/png';
  // One complete image, proportionally fitted. No crop, recoloring, retouching, or fabricated UI.
  const bounds = {x: 80, y: 430, width: 2720, height: 1300};
  const scale = Math.min(1, bounds.width / meta.width, bounds.height / meta.height);
  const width = Math.round(meta.width * scale * 100) / 100;
  const height = Math.round(meta.height * scale * 100) / 100;
  const x = Math.round((2880 - width) / 2 * 100) / 100;
  const y = Math.round((bounds.y + (bounds.height - height) / 2) * 100) / 100;
  const r = {
    TITLE_XML: xml(scene.title), SUBTITLE_XML: xml(scene.subtitle),
    PRODUCT_XML: xml(config.productName), PLATFORM_XML: xml(config.platformLabel),
    TITLE_SIZE: localized.headlineSize, SUBTITLE_SIZE: localized.subtitleSize,
    TITLE_SPACING: locale === 'en-US' ? -3.4 : -1.5,
    LOCALE: locale, IMAGE_X: x, IMAGE_Y: y, IMAGE_WIDTH: width, IMAGE_HEIGHT: height,
    FRAME_X: x - 13, FRAME_Y: y - 13, FRAME_WIDTH: width + 26, FRAME_HEIGHT: height + 26,
    FRAME_OPACITY: meta.hasAlpha ? 0 : 1,
    SHADOW_Y: y + 17, SCREENSHOT_DATA_URI: `data:${inputMIME};base64,${original.toString('base64')}`,
  };
  const stem = `${scene.number}-${scene.id}`;
  const generatedDir = path.join(sourceDir, 'generated', locale);
  const exportDir = path.join(root, 'exports', locale);
  await fs.mkdir(generatedDir, {recursive: true});
  await fs.mkdir(exportDir, {recursive: true});
  const svg = renderTemplate(templates.svg, r);
  await fs.writeFile(path.join(generatedDir, `${stem}.svg`), svg);
  await fs.writeFile(path.join(generatedDir, `${stem}.html`), renderTemplate(templates.html, r));
  const output = path.join(exportDir, `${stem}.png`);
  await sharp(Buffer.from(svg), {density: 72})
    .flatten({background: config.canvas.background}).removeAlpha().toColourspace('srgb')
    .png({compressionLevel: 9, palette: false}).toFile(output);
  const exported = await sharp(output).metadata();
  if (exported.width !== 2880 || exported.height !== 1800 || exported.hasAlpha || exported.channels !== 3 || exported.format !== 'png' || exported.depth !== 'uchar') {
    throw new Error(`Output is not 2880x1800, RGB 8-bit PNG without alpha: ${output}`);
  }
  if (hash(await fs.readFile(input)) !== inputHash) throw new Error(`Source capture changed during render: ${input}`);
  const record = {locale, scene: scene.id, title: scene.title, input: path.relative(root, input), inputSHA256: inputHash,
    inputFormat: meta.format, inputMIME, inputPixels: {width: meta.width, height: meta.height},
    placement: {x, y, width, height, scale, enlarged: scale > 1},
    output: path.relative(root, output), outputSHA256: hash(await fs.readFile(output)),
    pixels: {width: exported.width, height: exported.height, channels: exported.channels, depth: exported.depth, hasAlpha: exported.hasAlpha},
    composition: `Original ${meta.format === 'jpeg' ? 'JPEG' : 'PNG'} bytes embedded intact; full image proportionally fitted, no clipping or UI redraw.`};
  records.push(record);
  await fs.writeFile(path.join(exportDir, `${stem}.json`), JSON.stringify(record, null, 2) + '\n');
  console.log(`PASS ${record.output}: 2880x1800 RGB, no alpha; source SHA-256 unchanged`);
}

// Rebuild the contact sheet from all available verified output manifests, even for partial runs.
const all = [];
for (const [locale, localized] of Object.entries(config.locales)) {
  for (const scene of localized.scenes) {
    const manifestPath = path.join(root, 'exports', locale, `${scene.number}-${scene.id}.json`);
    try { all.push(JSON.parse(await fs.readFile(manifestPath, 'utf8'))); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
}
all.sort((a, b) => path.basename(a.output).localeCompare(path.basename(b.output)) || a.locale.localeCompare(b.locale));
const cards = all.map((shot) => `<figure><a href="${xml(shot.output)}"><img src="${xml(shot.output)}" alt="${xml(shot.title)}" width="2880" height="1800"></a><figcaption><strong>${xml(shot.locale)} · ${xml(shot.scene)}</strong><span>${xml(shot.title)}</span><a href="source/generated/${xml(shot.locale)}/${path.basename(shot.output, '.png')}.html">Editable HTML</a> · <a href="source/generated/${xml(shot.locale)}/${path.basename(shot.output, '.png')}.svg">SVG</a></figcaption></figure>`).join('\n');
await fs.writeFile(path.join(root, 'index.html'), `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>LinkScope Lite · Screenshot Review</title><style>*{box-sizing:border-box}body{margin:0;padding:48px;background:#07080b;color:#f5f5f7;font:16px -apple-system,BlinkMacSystemFont,sans-serif}header{max-width:1500px;margin:0 auto 34px}h1{font-size:32px;letter-spacing:-1px;font-weight:600;margin:0 0 12px}p{color:#939aa8;margin:0;line-height:1.6}.grid{max-width:1500px;margin:auto;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:30px}figure{margin:0}img{width:100%;height:auto;display:block;border:1px solid #242832;border-radius:10px}figcaption{color:#a0a7b4;padding:14px 2px;line-height:1.6}figcaption strong,figcaption span{display:block}figcaption strong{color:#eceef4}a{color:#aabdda;text-decoration:none}@media(max-width:800px){body{padding:22px}.grid{grid-template-columns:1fr}}</style><header><h1>LinkScope Lite</h1><p>${all.length} rendered screenshots · 2880 × 1800 · RGB PNG without alpha<br>Visual review required before App Store submission. Click an image for the full-size export.</p></header><main class="grid">${cards}</main></html>\n`);
await fs.writeFile(path.join(root, 'exports', 'manifest.json'), JSON.stringify({formatVersion:1,renderer:'SVG + sharp',sharpVersion:sharp.versions.sharp,shots:all}, null, 2) + '\n');
const expectedCount = Object.values(config.locales).reduce((count, locale) => count + locale.scenes.length, 0);
console.log(`Contact sheet: ${path.join(root, 'index.html')} (${all.length}/${expectedCount} rendered)`);
