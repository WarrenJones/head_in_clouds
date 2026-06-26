import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const variants = [
  {
    slug: "yun-breath-refined-icon",
    name: "Yun Breath Refined",
    summary: "The v5 Yun direction with better balance and less literal character logic.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F3EA"/>
      <path d="M344 346H628" fill="none" stroke="#25302D" stroke-width="62" stroke-linecap="round"/>
      <path d="M286 540C406 480 548 496 684 584" fill="none" stroke="#25302D" stroke-width="72" stroke-linecap="round"/>
      <path d="M426 672H614" fill="none" stroke="#A4B6B1" stroke-width="42" stroke-linecap="round"/>
      <circle cx="704" cy="584" r="32" fill="#D87561"/>
    `,
  },
  {
    slug: "yun-breath-compact-icon",
    name: "Yun Breath Compact",
    summary: "A more launcher-ready Yun mark with stronger 28px readability.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F3EA"/>
      <path d="M350 380H620" fill="none" stroke="#25302D" stroke-width="72" stroke-linecap="round"/>
      <path d="M318 566C426 512 548 524 668 596" fill="none" stroke="#25302D" stroke-width="82" stroke-linecap="round"/>
      <circle cx="676" cy="596" r="38" fill="#D87561"/>
      <path d="M440 698H588" fill="none" stroke="#A4B6B1" stroke-width="46" stroke-linecap="round"/>
    `,
  },
  {
    slug: "yun-xin-refined-icon",
    name: "Yun Xin Refined",
    summary: "Yun and Xin fused, but not a smiley face.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F7F2EA"/>
      <path d="M330 344H626" fill="none" stroke="#25302D" stroke-width="62" stroke-linecap="round"/>
      <path d="M300 506H666" fill="none" stroke="#25302D" stroke-width="68" stroke-linecap="round"/>
      <path d="M344 654C440 724 560 710 682 602" fill="none" stroke="#A4B6B1" stroke-width="62" stroke-linecap="round"/>
      <circle cx="684" cy="506" r="34" fill="#D87561"/>
    `,
  },
  {
    slug: "yun-xin-quiet-icon",
    name: "Yun Xin Quiet",
    summary: "A calmer, more premium mark for App Store and WeChat surfaces.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F9F5EE"/>
      <path d="M348 358H604" fill="none" stroke="#25302D" stroke-width="60" stroke-linecap="round"/>
      <path d="M286 522H704" fill="none" stroke="#25302D" stroke-width="70" stroke-linecap="round"/>
      <path d="M402 660C486 706 588 688 660 616" fill="none" stroke="#A4B6B1" stroke-width="58" stroke-linecap="round"/>
      <circle cx="708" cy="522" r="30" fill="#D87561"/>
    `,
  },
  {
    slug: "thought-stroke-icon",
    name: "Thought Stroke",
    summary: "A less character-like option: one held thought, one soft afterimage.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F4EC"/>
      <path d="M282 490C408 416 568 434 734 546" fill="none" stroke="#25302D" stroke-width="76" stroke-linecap="round"/>
      <path d="M340 620C446 568 562 580 686 656" fill="none" stroke="#A4B6B1" stroke-width="54" stroke-linecap="round"/>
      <circle cx="714" cy="536" r="34" fill="#D87561"/>
    `,
  },
  {
    slug: "wordmark-seed-icon",
    name: "Wordmark Seed",
    summary: "The icon extracted from a future custom Chinese wordmark.",
    svg: `
      <rect width="1024" height="1024" rx="226" fill="#F8F3EA"/>
      <path d="M304 398H552" fill="none" stroke="#25302D" stroke-width="62" stroke-linecap="round"/>
      <path d="M632 398H704" fill="none" stroke="#25302D" stroke-width="62" stroke-linecap="round" opacity=".34"/>
      <circle cx="586" cy="398" r="32" fill="#D87561"/>
      <path d="M294 562H710" fill="none" stroke="#25302D" stroke-width="70" stroke-linecap="round"/>
      <path d="M396 690C476 730 576 714 648 650" fill="none" stroke="#A4B6B1" stroke-width="56" stroke-linecap="round"/>
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
          <text x="56" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" letter-spacing="2" fill="#B98370">REFINED / 108 / 28 PX CHECK</text>
          <text x="56" y="478" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="22" letter-spacing="7" fill="#25302D">云上心事</text>
        </g>
      `;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#F6F1EA"/>
  <text x="${margin}" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="#252B2A">Head in the Clouds · Logo v6</text>
  <text x="${margin}" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#6F7773">Senior refinement pass: less literal, better small-size silhouette, more brand-owned Yun/Xin glyph logic.</text>
  <text x="${margin}" y="150" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="16" fill="#8A8277">Decision axis: choose between character-owned recognition and quieter abstract premium feel.</text>
  ${cards}
</svg>
`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v6.svg"), sheetSvg());
for (const variant of variants) {
  fs.writeFileSync(path.join(outDir, `${variant.slug}.svg`), iconSvg(variant));
}
