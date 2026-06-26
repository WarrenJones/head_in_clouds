import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const variants = [
  {
    slug: "yun-glyph-a-icon",
    name: "Yun Glyph A",
    summary: "A custom geometric Yun mark, not a cloud drawing.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F4EC"/>
      <path d="M342 342H620" fill="none" stroke="#27312F" stroke-width="72" stroke-linecap="round"/>
      <path d="M278 512H702" fill="none" stroke="#27312F" stroke-width="72" stroke-linecap="round"/>
      <path d="M396 650C480 592 586 614 648 714" fill="none" stroke="#27312F" stroke-width="72" stroke-linecap="round"/>
      <circle cx="700" cy="708" r="38" fill="#D97360"/>
    `,
  },
  {
    slug: "yun-glyph-b-icon",
    name: "Yun Glyph B",
    summary: "Softer Yun, closer to a breath than a character.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F7F1E8"/>
      <path d="M318 372H654" fill="none" stroke="#27312F" stroke-width="68" stroke-linecap="round"/>
      <path d="M252 564C372 496 526 506 670 594" fill="none" stroke="#27312F" stroke-width="78" stroke-linecap="round"/>
      <path d="M408 684H612" fill="none" stroke="#9BADAA" stroke-width="52" stroke-linecap="round"/>
      <circle cx="678" cy="594" r="36" fill="#D97360"/>
    `,
  },
  {
    slug: "xin-glyph-a-icon",
    name: "Xin Glyph A",
    summary: "A restrained Xin mark, emotional but not romantic.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#FAF6EF"/>
      <path d="M316 606C402 710 540 714 688 548" fill="none" stroke="#27312F" stroke-width="82" stroke-linecap="round"/>
      <circle cx="360" cy="454" r="38" fill="#9BADAA"/>
      <circle cx="520" cy="408" r="34" fill="#D97360"/>
      <circle cx="674" cy="458" r="38" fill="#27312F"/>
    `,
  },
  {
    slug: "xin-glyph-b-icon",
    name: "Xin Glyph B",
    summary: "The hidden-thought version of the Xin character.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F6F1E9"/>
      <path d="M300 572C380 680 512 710 720 508" fill="none" stroke="#27312F" stroke-width="76" stroke-linecap="round"/>
      <path d="M420 454C466 498 520 500 574 452" fill="none" stroke="#9BADAA" stroke-width="56" stroke-linecap="round"/>
      <circle cx="680" cy="422" r="36" fill="#D97360"/>
    `,
  },
  {
    slug: "yun-xin-ligature-icon",
    name: "Yun Xin Ligature",
    summary: "Yun on top, Xin underneath, fused into one mark.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F9F5EE"/>
      <path d="M330 340H612" fill="none" stroke="#27312F" stroke-width="68" stroke-linecap="round"/>
      <path d="M270 500H704" fill="none" stroke="#27312F" stroke-width="68" stroke-linecap="round"/>
      <path d="M326 638C414 724 548 720 684 590" fill="none" stroke="#9BADAA" stroke-width="70" stroke-linecap="round"/>
      <circle cx="690" cy="500" r="36" fill="#D97360"/>
    `,
  },
  {
    slug: "pause-wordmark-icon",
    name: "Pause Wordmark",
    summary: "A brand mark built from one unsaid sentence.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F3EA"/>
      <path d="M260 474H498" fill="none" stroke="#27312F" stroke-width="76" stroke-linecap="round"/>
      <path d="M604 474H764" fill="none" stroke="#27312F" stroke-width="76" stroke-linecap="round" opacity=".28"/>
      <circle cx="548" cy="474" r="42" fill="#D97360"/>
      <path d="M334 626H690" fill="none" stroke="#9BADAA" stroke-width="50" stroke-linecap="round"/>
      <path d="M430 716H594" fill="none" stroke="#D7E1DD" stroke-width="42" stroke-linecap="round"/>
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
  const cardH = 514;
  const gap = 56;
  const margin = 70;
  const width = margin * 2 + cardW * 3 + gap * 2;
  const height = 210 + cardH * 2 + gap + margin;
  const cards = variants
    .map((variant, index) => {
      const col = index % 3;
      const row = Math.floor(index / 3);
      const x = margin + col * (cardW + gap);
      const y = 170 + row * (cardH + gap);
      return `
        <g transform="translate(${x} ${y})">
          <rect width="${cardW}" height="${cardH}" rx="34" fill="#FFFFFF" stroke="#E4DCD2"/>
          ${nestedIcon(variant, 56, 42, 236)}
          ${nestedIcon(variant, 312, 90, 76)}
          ${nestedIcon(variant, 338, 206, 28)}
          <text x="56" y="342" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="28" font-weight="750" fill="#252B2A">${String(index + 1).padStart(2, "0")} ${variant.name}</text>
          <text x="56" y="383" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="17" fill="#68716E">${variant.summary}</text>
          <text x="56" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" letter-spacing="2" fill="#B98370">GLYPH / 108 / 28 PX CHECK</text>
          <text x="56" y="474" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="22" letter-spacing="7" fill="#27312F">云上心事</text>
        </g>
      `;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#F6F1EA"/>
  <text x="${margin}" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="#252B2A">Head in the Clouds · Logo v5</text>
  <text x="${margin}" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#6F7773">Brand glyph reset: custom Yun / Xin / pause marks. No illustration, no route, no cloud layer.</text>
  ${cards}
</svg>
`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v5.svg"), sheetSvg());
for (const variant of variants) {
  fs.writeFileSync(path.join(outDir, `${variant.slug}.svg`), iconSvg(variant));
}
