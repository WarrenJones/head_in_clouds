import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const variants = [
  {
    slug: "v7-high-altitude-mist",
    name: "High Altitude Mist",
    summary: "Cool off-white. Air first, emotion second.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FBFDFD"/>
          <stop offset="58%" stop-color="#F4F8F7"/>
          <stop offset="100%" stop-color="#EAF2F1"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#202A28",
    secondary: "#B5C8C5",
    accent: "#D96F5F",
  },
  {
    slug: "v7-cloud-white",
    name: "Cloud White",
    summary: "Almost white, relying on symbol shape not color mood.",
    bg: `
      <rect width="1024" height="1024" rx="226" fill="#FBFCFA"/>
    `,
    primary: "#1F2927",
    secondary: "#C5D2D0",
    accent: "#D86D5F",
  },
  {
    slug: "v7-cabin-dawn",
    name: "Cabin Dawn",
    summary: "A subtle warm top light without returning to beige stationery.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#FFF9F3"/>
          <stop offset="42%" stop-color="#F7FAF9"/>
          <stop offset="100%" stop-color="#EDF4F2"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#202A28",
    secondary: "#B2C6C2",
    accent: "#D97462",
  },
  {
    slug: "v7-sky-silver",
    name: "Sky Silver",
    summary: "More premium and less stationery-like.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#F8FAFA"/>
          <stop offset="100%" stop-color="#E8ECEC"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#1F2827",
    secondary: "#AEBDBA",
    accent: "#D66B5C",
  },
  {
    slug: "v7-quiet-blue",
    name: "Quiet Blue",
    summary: "Cooler app-store presence, but not dark aviation blue.",
    bg: `
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#F8FBFF"/>
          <stop offset="100%" stop-color="#E8F0F7"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bg)"/>
    `,
    primary: "#1F2A2D",
    secondary: "#B6C7CE",
    accent: "#D96F5F",
  },
  {
    slug: "v7-field-control",
    name: "Warm Control",
    summary: "The old warm direction, kept only as a comparison baseline.",
    bg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F3EA"/>
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
          <rect width="${cardW}" height="${cardH}" rx="34" fill="#FFFFFF" stroke="#E1E7E6"/>
          ${nestedIcon(variant, 56, 42, 236)}
          ${nestedIcon(variant, 312, 90, 76)}
          ${nestedIcon(variant, 338, 206, 28)}
          <text x="56" y="342" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="26" font-weight="750" fill="#252B2A">${String(index + 1).padStart(2, "0")} ${variant.name}</text>
          <text x="56" y="383" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="16" fill="#68716E">${variant.summary}</text>
          <text x="56" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" letter-spacing="2" fill="#7D8C8A">COLOR / 108 / 28 PX CHECK</text>
          <text x="56" y="478" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="18" fill="#52615F">bg · ${variant.primary} · ${variant.secondary} · ${variant.accent}</text>
        </g>
      `;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#F4F7F6"/>
  <text x="${margin}" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="#202A28">Head in the Clouds · Logo v7 Color</text>
  <text x="${margin}" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#64716F">Same v6-02 mark, color system only. Testing air, cloud, dawn, silver, quiet blue, and old warm baseline.</text>
  <text x="${margin}" y="150" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="16" fill="#87918F">Background should carry altitude/air; accent dot should carry the human thought.</text>
  ${cards}
</svg>
`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v7-color.svg"), sheetSvg());
for (const variant of variants) {
  fs.writeFileSync(path.join(outDir, `${variant.slug}.svg`), iconSvg(variant));
}
