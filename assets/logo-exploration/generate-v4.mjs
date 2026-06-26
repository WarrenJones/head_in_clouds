import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const variants = [
  {
    slug: "cloud-sentence-icon",
    name: "Cloud Sentence",
    summary: "A sentence held just above the cloud layer.",
    svg: `
      <defs>
        <linearGradient id="bgCloudSentence" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#F8FBF9"/>
          <stop offset="62%" stop-color="#EEF5F2"/>
          <stop offset="100%" stop-color="#F6EFE5"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bgCloudSentence)"/>
      <path d="M172 690C270 574 402 542 520 618C636 692 748 628 852 546V852H172Z" fill="#FFFFFF"/>
      <path d="M244 536H572" fill="none" stroke="#26302E" stroke-width="70" stroke-linecap="round"/>
      <circle cx="640" cy="536" r="43" fill="#D97360"/>
      <path d="M306 676C402 616 508 622 622 686" fill="none" stroke="#AABAB4" stroke-width="36" stroke-linecap="round"/>
    `,
  },
  {
    slug: "above-clouds-icon",
    name: "Above Clouds",
    summary: "The altitude moment without drawing a plane.",
    svg: `
      <defs>
        <linearGradient id="bgAboveClouds" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FBFAF4"/>
          <stop offset="100%" stop-color="#EAF3F2"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bgAboveClouds)"/>
      <path d="M190 612C298 506 436 478 548 548C666 622 760 576 836 498" fill="none" stroke="#26302E" stroke-width="74" stroke-linecap="round"/>
      <path d="M230 674C370 604 506 624 672 714" fill="none" stroke="#CAD8D3" stroke-width="42" stroke-linecap="round"/>
      <circle cx="738" cy="528" r="44" fill="#D97360"/>
      <circle cx="742" cy="528" r="16" fill="#FFF7EF"/>
    `,
  },
  {
    slug: "same-flight-icon",
    name: "Same Flight",
    summary: "Two strangers on the same invisible route.",
    svg: `
      <defs>
        <linearGradient id="bgSameFlight" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#FAF8F0"/>
          <stop offset="100%" stop-color="#EEF5F2"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bgSameFlight)"/>
      <path d="M226 614C344 466 572 446 754 574" fill="none" stroke="#26302E" stroke-width="64" stroke-linecap="round"/>
      <circle cx="294" cy="556" r="42" fill="#D97360"/>
      <circle cx="712" cy="542" r="42" fill="#D97360"/>
      <path d="M298 694H726" fill="none" stroke="#AABAB4" stroke-width="44" stroke-linecap="round"/>
      <path d="M368 754H604" fill="none" stroke="#D9E2DE" stroke-width="36" stroke-linecap="round"/>
    `,
  },
  {
    slug: "sky-note-icon",
    name: "Sky Note",
    summary: "A short note sitting above a soft cloud floor.",
    svg: `
      <defs>
        <linearGradient id="bgSkyNote" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FFFFFF"/>
          <stop offset="100%" stop-color="#F2ECE3"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bgSkyNote)"/>
      <rect x="296" y="332" width="432" height="244" rx="54" fill="#26302E"/>
      <path d="M374 432H568" fill="none" stroke="#F8F2E9" stroke-width="36" stroke-linecap="round"/>
      <path d="M374 496H646" fill="none" stroke="#AABAB4" stroke-width="30" stroke-linecap="round"/>
      <circle cx="668" cy="424" r="36" fill="#D97360"/>
      <path d="M216 702C358 612 516 626 784 724" fill="none" stroke="#CAD8D3" stroke-width="52" stroke-linecap="round"/>
    `,
  },
  {
    slug: "windowless-horizon-icon",
    name: "Windowless Horizon",
    summary: "A cabin view reduced to horizon and sentence.",
    svg: `
      <defs>
        <linearGradient id="bgHorizon" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#F9FBF8"/>
          <stop offset="100%" stop-color="#F3EDE4"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bgHorizon)"/>
      <path d="M234 514C360 458 506 458 640 520C696 546 744 544 794 516" fill="none" stroke="#AABAB4" stroke-width="58" stroke-linecap="round"/>
      <path d="M278 634H616" fill="none" stroke="#26302E" stroke-width="70" stroke-linecap="round"/>
      <circle cx="696" cy="634" r="43" fill="#D97360"/>
      <path d="M384 734H640" fill="none" stroke="#D9E2DE" stroke-width="36" stroke-linecap="round"/>
    `,
  },
  {
    slug: "cloud-seal-icon",
    name: "Cloud Seal",
    summary: "A more iconic stamp for the share card system.",
    svg: `
      <defs>
        <linearGradient id="bgCloudSeal" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FBF9F2"/>
          <stop offset="100%" stop-color="#EAF3F1"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#bgCloudSeal)"/>
      <circle cx="512" cy="512" r="232" fill="none" stroke="#26302E" stroke-width="58"/>
      <path d="M350 570C430 498 538 496 674 580" fill="none" stroke="#26302E" stroke-width="60" stroke-linecap="round"/>
      <path d="M382 638H642" fill="none" stroke="#AABAB4" stroke-width="38" stroke-linecap="round"/>
      <circle cx="656" cy="432" r="38" fill="#D97360"/>
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
          <text x="56" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" letter-spacing="2" fill="#B98370">THEME / 108 / 28 PX CHECK</text>
        </g>
      `;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#F6F1EA"/>
  <text x="${margin}" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="#252B2A">Head in the Clouds · Logo v4</text>
  <text x="${margin}" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#6F7773">Closer to the product theme: cloud layer, altitude, one sentence, same route. Still no aircraft or postcard.</text>
  ${cards}
</svg>
`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v4.svg"), sheetSvg());
for (const variant of variants) {
  fs.writeFileSync(path.join(outDir, `${variant.slug}.svg`), iconSvg(variant));
}
