import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const variants = [
  {
    slug: "yun-stroke-icon",
    name: "Yun Stroke",
    summary: "A modern abstraction of the Chinese character Yun.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#FBF7EF"/>
      <path d="M332 350H612" fill="none" stroke="#26302E" stroke-width="72" stroke-linecap="round"/>
      <path d="M286 548C402 482 540 478 664 530C710 550 746 548 778 512" fill="none" stroke="#26302E" stroke-width="84" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="706" cy="405" r="34" fill="#D9715E"/>
    `,
  },
  {
    slug: "unsaid-line-icon",
    name: "Unsaid Line",
    summary: "One sentence, interrupted before it becomes a post.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F7F3EA"/>
      <path d="M266 438H510" fill="none" stroke="#252C2A" stroke-width="74" stroke-linecap="round"/>
      <path d="M568 438H758" fill="none" stroke="#252C2A" stroke-width="74" stroke-linecap="round" opacity=".26"/>
      <circle cx="530" cy="438" r="38" fill="#D9715E"/>
      <path d="M318 588H700" fill="none" stroke="#879C95" stroke-width="44" stroke-linecap="round" opacity=".76"/>
    `,
  },
  {
    slug: "soft-y-icon",
    name: "Soft Y",
    summary: "A quiet monogram that avoids travel cliches.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F4EEE5"/>
      <path d="M368 312C438 426 501 493 590 526" fill="none" stroke="#2C3734" stroke-width="82" stroke-linecap="round"/>
      <path d="M702 306C635 430 572 545 514 710" fill="none" stroke="#2C3734" stroke-width="82" stroke-linecap="round"/>
      <circle cx="628" cy="540" r="36" fill="#E0826E"/>
    `,
  },
  {
    slug: "quiet-window-icon",
    name: "Quiet Window",
    summary: "A private space without literal aircraft language.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F5EE"/>
      <rect x="324" y="252" width="376" height="520" rx="188" fill="none" stroke="#283330" stroke-width="64"/>
      <path d="M368 582C452 538 556 548 656 608" fill="none" stroke="#9EB2AB" stroke-width="48" stroke-linecap="round"/>
      <circle cx="636" cy="386" r="34" fill="#D9715E"/>
    `,
  },
  {
    slug: "fold-mark-icon",
    name: "Fold Mark",
    summary: "A sentence folded into a compact mark.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F6F0E6"/>
      <path d="M260 570L410 456L512 542L652 436L760 510" fill="none" stroke="#283330" stroke-width="78" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M410 456L512 542L410 588Z" fill="#9AAEA7" opacity=".82"/>
      <circle cx="759" cy="510" r="32" fill="#D9715E"/>
    `,
  },
  {
    slug: "breath-dot-icon",
    name: "Breath Dot",
    summary: "Ultra-minimal, built for tiny launcher size.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#FAF6EF"/>
      <circle cx="512" cy="512" r="196" fill="#2F3B38"/>
      <circle cx="448" cy="442" r="54" fill="#FAF6EF"/>
      <circle cx="632" cy="602" r="38" fill="#D9715E"/>
    `,
  },
];

function iconSvg(variant) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
${variant.svg}
</svg>
`;
}

function nestedIcon(variant, x, y, size) {
  return `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 1024 1024">${variant.svg}</svg>`;
}

function sheetSvg() {
  const cardW = 430;
  const cardH = 500;
  const gap = 56;
  const margin = 70;
  const width = margin * 2 + cardW * 3 + gap * 2;
  const height = 200 + cardH * 2 + gap + margin;
  const cards = variants
    .map((variant, index) => {
      const col = index % 3;
      const row = Math.floor(index / 3);
      const x = margin + col * (cardW + gap);
      const y = 160 + row * (cardH + gap);
      return `
        <g transform="translate(${x} ${y})">
          <rect width="${cardW}" height="${cardH}" rx="34" fill="#FFFFFF" stroke="#E4DCD2"/>
          ${nestedIcon(variant, 56, 42, 236)}
          ${nestedIcon(variant, 312, 90, 76)}
          ${nestedIcon(variant, 338, 206, 28)}
          <text x="56" y="340" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="28" font-weight="750" fill="#252B2A">${String(index + 1).padStart(2, "0")} ${variant.name}</text>
          <text x="56" y="381" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="17" fill="#68716E">${variant.summary}</text>
          <text x="56" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" letter-spacing="2" fill="#B98370">FLAT / 108 / 28 PX CHECK</text>
        </g>
      `;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#F6F1EA"/>
  <text x="${margin}" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="#252B2A">Head in the Clouds · Logo v3</text>
  <text x="${margin}" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#6F7773">Flat, warm, contemporary. No blue-gold, no aircraft, no literal cloud, no postcard.</text>
  ${cards}
</svg>
`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v3.svg"), sheetSvg());
for (const variant of variants) {
  fs.writeFileSync(path.join(outDir, `${variant.slug}.svg`), iconSvg(variant));
}
