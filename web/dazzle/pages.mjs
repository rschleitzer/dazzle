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

// An ImageBitmap for each image of the description, by its index.
export async function load_images(description, bytes_of) {
  const images = [];
  for (const [i, image] of description.images.entries()) {
    const bytes = bytes_of(image.file);
    images[i] = bytes ? await createImageBitmap(new Blob([bytes])) : null;
  }
  return images;
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
        const [, x, y, font, size, color, text, advances] = op;
        const face = faces[font] ?? { family: 'sans-serif', weight: 'normal', style: 'normal' };
        const units = description.fonts[font]?.units ?? 1000;
        ctx.font = `${face.style} ${face.weight} ${size * k}px ${face.family}`;
        ctx.fillStyle = color;
        let at = 0;
        let i = 0;
        for (const ch of text) {
          ctx.fillText(ch, (x + at * size / units) * k, y * k);
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
        if (images[image]) ctx.drawImage(images[image], x * k, y * k, width * k, height * k);
        break;
      }
    }
  }
}
