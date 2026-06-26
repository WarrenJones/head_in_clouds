import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const variants = [
  {
    slug: "v8-warm-air",
    name: "Warm Air",
    summary: "Closest to v7-06, but cleaner and less stationery-like.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FBF6EE"/>
          <stop offset="54%" stop-color="#F6EFE5"/>
          <stop offset="100%" stop-color="#EEF5F2"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#24302D",
    secondary: "#A9B9B4",
    accent: "#D87561",
  },
  {
    slug: "v8-cloud-paper",
    name: "Cloud Paper",
    summary: "Paper memory, but lifted with a cooler cloud edge.",
    bg: `
      <defs>
        <radialGradient id="bg" cx="36%" cy="22%" r="82%">
          <stop offset="0%" stop-color="#FFFFFF"/>
          <stop offset="56%" stop-color="#F8F0E3"/>
          <stop offset="100%" stop-color="#EAF3F1"/>
        </radialGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#24302D",
    secondary: "#AEC0BB",
    accent: "#D87561",
  },
  {
    slug: "v8-dawn-letter",
    name: "Dawn Letter",
    summary: "A more emotional dawn tone without vintage gold.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#FFF4E8"/>
          <stop offset="48%" stop-color="#F9F3EA"/>
          <stop offset="100%" stop-color="#F0F6F4"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#24302D",
    secondary: "#A9B9B4",
    accent: "#D66F5E",
  },
  {
    slug: "v8-postcard-system",
    name: "Postcard System",
    summary: "The strongest bridge to Cloud Card, still icon-simple.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FFF9EF"/>
          <stop offset="100%" stop-color="#F0E3CF"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#24302D",
    secondary: "#A8B7B2",
    accent: "#D87561",
  },
  {
    slug: "v8-quiet-memory",
    name: "Quiet Memory",
    summary: "Warmer, more private, but intentionally lower saturation.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FAF4EB"/>
          <stop offset="100%" stop-color="#F2E8DA"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#26312F",
    secondary: "#A6B5B0",
    accent: "#D87561",
  },
  {
    slug: "v8-ticket-cream",
    name: "Ticket Cream",
    summary: "Most theme-aligned, highest risk of feeling old.",
    bg: `
      <rect width="1024" height="1024" rx="226" fill="#F4E7CF"/>
    `,
    primary: "#25302D",
    secondary: "#A4B6B1",
    accent: "#D87561",
  },
];

function markSvg({ bg, primary, secondary, accent }) {
  return `
${bg}
<path d="M350 380H620" fill="none" stroke="${primary}" stroke-width="72" stroke-linecap="round"/>
<path d="M318 566C426 512 548 524 668 596" fill="none" stroke="${primary}" stroke-width="82" stroke-linecap="round"/>
<circle cx="676" cy="596" r="38" fill="${accent}"/>
<path d="M440 698H588" fill="none" stroke="${secondary}" stroke-width="46" stroke-linecap="round"/>
`;
}

function iconSvg(variant) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
${markSvg(variant)}
</svg>
`;
}

function nestedIcon(variant, x, y, size) {
  return `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 1024 1024">${markSvg(variant)}</svg>`;
}

function sheetSvg() {
  const cardW = 430;
  const cardH = 532;
  const gap = 56;
  const margin = 70;
  const width = margin * 2 + cardW * 3 + gap * 2;
  const height = 222 + cardH * 2 + gap + margin;
  const cards = variants
    .map((variant, index) => {
      const col = index % 3;
      const row = Math.floor(index / 3);
      const x = margin + col * (cardW + gap);
      const y = 182 + row * (cardH + gap);
      return `
        <g transform="translate(${x} ${y})">
          <rect width="${cardW}" height="${cardH}" rx="34" fill="#FFFFFF" stroke="#E4DCD2"/>
          ${nestedIcon(variant, 56, 42, 236)}
          ${nestedIcon(variant, 312, 90, 76)}
          ${nestedIcon(variant, 338, 206, 28)}
          <text x="56" y="342" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="26" font-weight="750" fill="#252B2A">${String(index + 1).padStart(2, "0")} ${variant.name}</text>
          <text x="56" y="383" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="16" fill="#68716E">${variant.summary}</text>
          <text x="56" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" letter-spacing="2" fill="#A17C67">V7-06 BASE / 108 / 28 PX CHECK</text>
          <text x="56" y="478" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="18" fill="#52615F">${variant.primary} · ${variant.secondary} · ${variant.accent}</text>
        </g>
      `;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#F7F1E8"/>
  <text x="${margin}" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="#24302D">Head in the Clouds · Logo v8 Warm Theme</text>
  <text x="${margin}" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#6A746F">Based on v7-06 Warm Control. Goal: keep thematic warmth without falling back to old beige stationery or gold aviation.</text>
  <text x="${margin}" y="150" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="16" fill="#8A8277">The icon stays as the v6-02 glyph. This pass only tunes the warm brand system around it.</text>
  ${cards}
</svg>
`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v8-warm-theme.svg"), sheetSvg());
for (const variant of variants) {
  fs.writeFileSync(path.join(outDir, `${variant.slug}.svg`), iconSvg(variant));
}
