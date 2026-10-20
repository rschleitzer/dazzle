// Draw dazzle's page description (`dazzle -t canvas`) onto canvases.
//
// The description holds the pages the PDF backend sets -- the same layout,
// the same operations (PdfFOTBuilder.write_canvas has the format): lengths in
// thousandths of a point from the top left corner, y downwards, text at its
// baseline, and the advance of every character in its font's units. A
// character is drawn where those advances put it, one at a time: never where
// the browser's own shaping would put it (kerning, ligatures), which is what
// keeps the canvas the page of the PDF.
//
// The fonts are the condition: a font the layout measured is drawn with the
// SAME file (`load_fonts` makes a FontFace of each one the description names,
// from the bytes the caller hands in). A standard font (Helvetica, Times,
// Courier, which a PDF reader brings along) has no file; it is drawn with
// what the browser has under that name, so its glyphs -- not their places --
// may differ.
//
//   import { load_fonts, draw_page, page_size } from './pages.mjs';
//   const d = JSON.parse(text);
//   const faces = await load_fonts(d, path => bytes_of(path));
//   const images = await load_images(d, path => bytes_of(path));
//   draw_page(canvas, d, 0, { faces, images, scale: 1.5 });

const STANDARD = {
  Helvetica: ['Helvetica, Arial, sans-serif', 'normal', 'normal'],
  'Helvetica-Bold': ['Helvetica, Arial, sans-serif', 'bold', 'normal'],
  'Helvetica-Oblique': ['Helvetica, Arial, sans-serif', 'normal', 'oblique'],
  'Helvetica-BoldOblique': ['Helvetica, Arial, sans-serif', 'bold', 'oblique'],
  'Times-Roman': ['"Times New Roman", Times, serif', 'normal', 'normal'],
  'Times-Bold': ['"Times New Roman", Times, serif', 'bold', 'normal'],
  'Times-Italic': ['"Times New Roman", Times, serif', 'normal', 'italic'],
  'Times-BoldItalic': ['"Times New Roman", Times, serif', 'bold', 'italic'],
  Courier: ['"Courier New", Courier, monospace', 'normal', 'normal'],
  'Courier-Bold': ['"Courier New", Courier, monospace', 'bold', 'normal'],
  'Courier-Oblique': ['"Courier New", Courier, monospace', 'normal', 'oblique'],
  'Courier-BoldOblique': ['"Courier New", Courier, monospace', 'bold', 'oblique'],
};

// A CSS font for each font of the description, by its index: the FontFace
// made of its file, or the standard font's family, weight and style.
// `bytes_of(path)` answers a font file's bytes (a Uint8Array) or null.
export async function load_fonts(description, bytes_of) {
  const faces = [];
  let count = 0;
  for (const [i, font] of description.fonts.entries()) {
    if (font.standard) {
      const [family, weight, style] = STANDARD[font.standard] ?? STANDARD.Helvetica;
      faces[i] = { family, weight, style };
      continue;
    }
    const bytes = bytes_of(font.file);
    if (!bytes) {
      faces[i] = { family: 'sans-serif', weight: 'normal', style: 'normal' };
      continue;
    }
    const name = 'dazzle-font-' + (++load_fonts.serial) + '-' + count++;
    const face = new FontFace(name, bytes);
    await face.load();
    document.fonts.add(face);
    faces[i] = { family: '"' + name + '"', weight: 'normal', style: 'normal' };
  }
  return faces;
}
load_fonts.serial = 0;

// An ImageBitmap for each image of the description, by its index; an image
// given as a PDF is its page's box and content, which draw_form draws.
export async function load_images(description, bytes_of) {
  const images = [];
  for (const [i, image] of description.images.entries()) {
    if (image.form) {
      images[i] = { form: image.form };
      continue;
    }
    const bytes = bytes_of(image.file);
    images[i] = bytes ? await createImageBitmap(new Blob([bytes])) : null;
  }
  return images;
}

// The tokens of a PDF content stream: numbers, names, operators, the
// brackets of an array; a string, a dictionary and a comment are passed over.
function* content_tokens(text) {
  const n = text.length;
  let i = 0;
  const delimiter = c => '()<>[]{}/%'.includes(c);
  const space = c => c === ' ' || c === '\n' || c === '\r' || c === '\t' || c === '\f' || c === '\0';
  while (i < n) {
    const c = text[i];
    if (space(c)) { i++; continue; }
    if (c === '%') { while (i < n && text[i] !== '\n' && text[i] !== '\r') i++; continue; }
    if (c === '(') {
      let depth = 0;
      for (; i < n; i++) {
        if (text[i] === '\\') i++;
        else if (text[i] === '(') depth++;
        else if (text[i] === ')' && --depth === 0) { i++; break; }
      }
      yield { string: true };
      continue;
    }
    if (c === '<') {
      if (text[i + 1] === '<') {
        let depth = 0;
        for (; i < n; i++) {
          if (text[i] === '<' && text[i + 1] === '<') { depth++; i++; }
          else if (text[i] === '>' && text[i + 1] === '>') { i++; if (--depth === 0) { i++; break; } }
        }
      } else {
        while (i < n && text[i] !== '>') i++;
        i++;
      }
      yield { string: true };
      continue;
    }
    if (c === '[' || c === ']') { i++; yield { bracket: c }; continue; }
    let j = i + 1;
    while (j < n && !space(text[j]) && !delimiter(text[j])) j++;
    const word = text.slice(i, j);
    i = j;
    if (c === '/') yield { name: word.slice(1) };
    else if (/^[+-]?(\d+\.?\d*|\.\d+)$/.test(word)) yield { number: parseFloat(word) };
    else yield { op: word };
    // an inline image's data is no tokens: on to its EI
    if (word === 'ID') {
      const end = text.indexOf('EI', i);
      i = end < 0 ? n : end + 2;
    }
  }
}

// Draw the first page of a PDF an image was given as -- its box and content
// from the description -- into the place x, y, width, height (canvas pixels,
// y down): the paths of its content, stroked and filled with their colours,
// line widths, caps, joins and dashes. Text and images within it are not
// drawn, nor what an extended graphics state (gs) would change.
function draw_form(ctx, form, x, y, width, height) {
  const [bx, by, bw, bh] = form.box.map(v => v / 1000);
  if (bw <= 0 || bh <= 0) return;
  ctx.save();
  // from the form's space (points, y going up) onto its place
  const sx = width / bw, sy = height / bh;
  ctx.transform(sx, 0, 0, -sy, x - bx * sx, y + (by + bh) * sy);
  ctx.beginPath();
  ctx.rect(bx, by, bw, bh);
  ctx.clip();
  ctx.beginPath();
  ctx.lineWidth = 1;
  ctx.strokeStyle = ctx.fillStyle = '#000000';
  ctx.lineCap = 'butt';
  ctx.lineJoin = 'miter';
  let args = [], array = null, clip = null, cx = 0, cy = 0, text = 0;
  const gray = g => `rgb(${g * 255}, ${g * 255}, ${g * 255})`;
  const rgb = (r, g, b) => `rgb(${r * 255}, ${g * 255}, ${b * 255})`;
  const cmyk = (c, m, y, k) => rgb((1 - c) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k));
  const end_path = () => {
    if (clip) ctx.clip(clip);
    clip = null;
    ctx.beginPath();
  };
  for (const t of content_tokens(form.content)) {
    if (t.bracket === '[') { array = []; continue; }
    if (t.bracket === ']') { args.push(array ?? []); array = null; continue; }
    if (t.number !== undefined) { (array ?? args).push(t.number); continue; }
    if (t.name !== undefined || t.string) { args.push(t.name ?? ''); continue; }
    const a = args;
    args = [];
    if (t.op === 'BT') { text++; continue; }
    if (t.op === 'ET') { text = Math.max(0, text - 1); continue; }
    if (text > 0) continue;
    switch (t.op) {
      case 'q': ctx.save(); break;
      case 'Q': ctx.restore(); break;
      case 'cm': ctx.transform(a[0], a[1], a[2], a[3], a[4], a[5]); break;
      case 'w': ctx.lineWidth = a[0]; break;
      case 'J': ctx.lineCap = ['butt', 'round', 'square'][a[0]] ?? 'butt'; break;
      case 'j': ctx.lineJoin = ['miter', 'round', 'bevel'][a[0]] ?? 'miter'; break;
      case 'M': ctx.miterLimit = a[0]; break;
      case 'd': ctx.setLineDash(Array.isArray(a[0]) ? a[0] : []); ctx.lineDashOffset = a[1] ?? 0; break;
      case 'm': ctx.moveTo(a[0], a[1]); cx = a[0]; cy = a[1]; break;
      case 'l': ctx.lineTo(a[0], a[1]); cx = a[0]; cy = a[1]; break;
      case 'c': ctx.bezierCurveTo(a[0], a[1], a[2], a[3], a[4], a[5]); cx = a[4]; cy = a[5]; break;
      case 'v': ctx.bezierCurveTo(cx, cy, a[0], a[1], a[2], a[3]); cx = a[2]; cy = a[3]; break;
      case 'y': ctx.bezierCurveTo(a[0], a[1], a[2], a[3], a[2], a[3]); cx = a[2]; cy = a[3]; break;
      case 'h': ctx.closePath(); break;
      case 're': ctx.rect(a[0], a[1], a[2], a[3]); cx = a[0]; cy = a[1]; break;
      case 'S': ctx.stroke(); end_path(); break;
      case 's': ctx.closePath(); ctx.stroke(); end_path(); break;
      case 'f': case 'F': ctx.fill('nonzero'); end_path(); break;
      case 'f*': ctx.fill('evenodd'); end_path(); break;
      case 'B': ctx.fill('nonzero'); ctx.stroke(); end_path(); break;
      case 'B*': ctx.fill('evenodd'); ctx.stroke(); end_path(); break;
      case 'b': ctx.closePath(); ctx.fill('nonzero'); ctx.stroke(); end_path(); break;
      case 'b*': ctx.closePath(); ctx.fill('evenodd'); ctx.stroke(); end_path(); break;
      case 'n': end_path(); break;
      case 'W': clip = 'nonzero'; break;
      case 'W*': clip = 'evenodd'; break;
      case 'g': ctx.fillStyle = gray(a[0]); break;
      case 'G': ctx.strokeStyle = gray(a[0]); break;
      case 'rg': ctx.fillStyle = rgb(a[0], a[1], a[2]); break;
      case 'RG': ctx.strokeStyle = rgb(a[0], a[1], a[2]); break;
      case 'k': ctx.fillStyle = cmyk(a[0], a[1], a[2], a[3]); break;
      case 'K': ctx.strokeStyle = cmyk(a[0], a[1], a[2], a[3]); break;
      // Do, gs, text state and the rest: not drawn
    }
  }
  ctx.restore();
}

// The size of page `index` in CSS pixels at `scale` (1: 96 per inch).
export function page_size(description, index, scale = 1) {
  const page = description.pages[index];
  const k = px_per_unit(scale);
  return { width: page.width * k, height: page.height * k };
}

function px_per_unit(scale) {
  return scale * 96 / 72 / 1000;
}

// Draw page `index` onto `canvas`, which is sized for it (and for the
// device's pixel ratio, so the page is sharp).
export function draw_page(canvas, description, index, { faces, images = [], scale = 1 } = {}) {
  const page = description.pages[index];
  const k = px_per_unit(scale);
  const ratio = globalThis.devicePixelRatio || 1;
  canvas.width = Math.ceil(page.width * k * ratio);
  canvas.height = Math.ceil(page.height * k * ratio);
  canvas.style.width = page.width * k + 'px';
  canvas.style.height = page.height * k + 'px';
  const ctx = canvas.getContext('2d');
  // the device's pixels only: lengths are turned into CSS pixels here, so a
  // font is set at its size in pixels (a size in thousandths of a point under
  // a shrinking transform is one a browser may refuse to raster)
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, page.width * k, page.height * k);
  ctx.textBaseline = 'alphabetic';
  ctx.textAlign = 'left';
  if ('fontKerning' in ctx) ctx.fontKerning = 'none';
  for (const op of page.ops) {
    switch (op[0]) {
      case 'text': {
        const [, x, y, font, size, color, text, advances, spacing = 0] = op;
        const face = faces[font] ?? { family: 'sans-serif', weight: 'normal', style: 'normal' };
        const units = description.fonts[font]?.units ?? 1000;
        ctx.font = `${face.style} ${face.weight} ${size * k}px ${face.family}`;
        ctx.fillStyle = color;
        let at = 0;
        let i = 0;
        for (const ch of text) {
          ctx.fillText(ch, (x + at * size / units + i * spacing) * k, y * k);
          at += advances[i++] ?? 0;
        }
        break;
      }
      case 'line': {
        const [, x1, y1, x2, y2, thickness, color] = op;
        ctx.strokeStyle = color;
        ctx.lineWidth = thickness * k;
        ctx.lineCap = 'butt';
        ctx.beginPath();
        ctx.moveTo(x1 * k, y1 * k);
        ctx.lineTo(x2 * k, y2 * k);
        ctx.stroke();
        break;
      }
      case 'rect': {
        const [, x, y, width, height, color] = op;
        ctx.fillStyle = color;
        ctx.fillRect(x * k, y * k, width * k, height * k);
        break;
      }
      case 'image': {
        const [, x, y, width, height, image] = op;
        if (images[image]?.form) draw_form(ctx, images[image].form, x * k, y * k, width * k, height * k);
        else if (images[image]) ctx.drawImage(images[image], x * k, y * k, width * k, height * k);
        break;
      }
    }
  }
}
