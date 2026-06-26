import fs from "node:fs";
import path from "node:path";

const outDir = new URL(".", import.meta.url).pathname;

const color = {
  airTop: "#FBFDFD",
  airMid: "#F4F8F7",
  airBottom: "#EAF2F1",
  ink: "#202A28",
  mist: "#B5C8C5",
  thought: "#D96F5F",
  paper: "#F4E7CF",
  paperDeep: "#E6D4B6",
  nightTop: "#071018",
  nightBottom: "#122235",
  nightMist: "#8FA8B6",
  line: "#DCE7E5",
  card: "#FFFFFF",
};

function logoMark(x, y, size, bg = true) {
  const scale = size / 1024;
  return `
    <g transform="translate(${x} ${y}) scale(${scale})">
      ${bg ? `
      <defs>
        <linearGradient id="logoBg${x}${y}" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="${color.airTop}"/>
          <stop offset="58%" stop-color="${color.airMid}"/>
          <stop offset="100%" stop-color="${color.airBottom}"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="226" fill="url(#logoBg${x}${y})"/>` : ""}
      <path d="M350 380H620" fill="none" stroke="${color.ink}" stroke-width="72" stroke-linecap="round"/>
      <path d="M318 566C426 512 548 524 668 596" fill="none" stroke="${color.ink}" stroke-width="82" stroke-linecap="round"/>
      <circle cx="676" cy="596" r="38" fill="${color.thought}"/>
      <path d="M440 698H588" fill="none" stroke="${color.mist}" stroke-width="46" stroke-linecap="round"/>
    </g>
  `;
}

function phoneFrame(x, y, title, content) {
  return `
    <g transform="translate(${x} ${y})">
      <rect x="0" y="0" width="284" height="584" rx="48" fill="#101314" opacity=".14"/>
      <rect x="8" y="8" width="268" height="568" rx="42" fill="#FFFFFF"/>
      <rect x="112" y="20" width="52" height="8" rx="4" fill="#D6DFDD"/>
      <text x="0" y="628" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="24" font-weight="750" fill="${color.ink}">${title}</text>
      ${content}
    </g>
  `;
}

function onboardingContent() {
  return `
    <defs>
      <linearGradient id="phoneAir" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="${color.airTop}"/>
        <stop offset="62%" stop-color="${color.airMid}"/>
        <stop offset="100%" stop-color="${color.airBottom}"/>
      </linearGradient>
    </defs>
    <rect x="8" y="8" width="268" height="568" rx="42" fill="url(#phoneAir)"/>
    ${logoMark(98, 82, 88, false)}
    <text x="142" y="220" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="26" font-weight="760" fill="${color.ink}">云上心事</text>
    <text x="142" y="250" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="10" letter-spacing="2.2" fill="#60706D">HEAD IN THE CLOUDS</text>
    <text x="142" y="315" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="13" fill="#5F6F6C">登机前 30 分钟</text>
    <text x="142" y="338" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="13" fill="#5F6F6C">给这趟飞行留一句话</text>
    <rect x="42" y="428" width="200" height="48" rx="24" fill="${color.ink}"/>
    <text x="142" y="458" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF">写下这一趟</text>
    <circle cx="220" cy="392" r="10" fill="${color.thought}"/>
  `;
}

function cloudCardContent() {
  return `
    <defs>
      <linearGradient id="phoneAir2" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="${color.airTop}"/>
        <stop offset="100%" stop-color="${color.airBottom}"/>
      </linearGradient>
      <linearGradient id="paperCard" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#FFF6E4"/>
        <stop offset="100%" stop-color="${color.paper}"/>
      </linearGradient>
    </defs>
    <rect x="8" y="8" width="268" height="568" rx="42" fill="url(#phoneAir2)"/>
    <text x="36" y="88" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="18" font-weight="760" fill="${color.ink}">生成卡片</text>
    <rect x="34" y="124" width="216" height="306" rx="22" fill="url(#paperCard)" stroke="${color.paperDeep}" stroke-width="1"/>
    <text x="54" y="162" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="10" font-weight="700" fill="${color.ink}">MU5301</text>
    <text x="54" y="182" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="8" fill="#68706B">SHA -> CTU</text>
    <path d="M54 210H230" stroke="#CDBD9E" stroke-width="1" opacity=".62"/>
    <text x="54" y="270" font-family="Georgia, serif" font-size="20" font-weight="700" fill="${color.ink}">我把没有说出口的话，</text>
    <text x="54" y="302" font-family="Georgia, serif" font-size="20" font-weight="700" fill="${color.ink}">带过了云层。</text>
    <path d="M64 370C104 342 158 342 210 374" fill="none" stroke="${color.ink}" stroke-width="3" stroke-linecap="round" opacity=".55"/>
    <circle cx="210" cy="374" r="5" fill="${color.thought}"/>
    <text x="54" y="404" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="7" letter-spacing="1.4" fill="#8D8069">HEAD IN THE CLOUDS</text>
    <rect x="42" y="464" width="200" height="48" rx="24" fill="${color.ink}"/>
    <text x="142" y="494" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF">保存 / 分享</text>
  `;
}

function flightSpaceContent() {
  return `
    <defs>
      <linearGradient id="nightSpace" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="${color.nightTop}"/>
        <stop offset="100%" stop-color="${color.nightBottom}"/>
      </linearGradient>
    </defs>
    <rect x="8" y="8" width="268" height="568" rx="42" fill="url(#nightSpace)"/>
    <text x="36" y="88" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="17" font-weight="760" fill="#F2F7F6">MU5301</text>
    <text x="36" y="112" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="10" letter-spacing="1.6" fill="${color.nightMist}">同一趟飞行</text>
    <path d="M54 176C104 122 182 122 228 176" fill="none" stroke="${color.nightMist}" stroke-width="2" opacity=".58"/>
    <circle cx="54" cy="176" r="4" fill="${color.thought}"/>
    <circle cx="228" cy="176" r="4" fill="${color.thought}"/>
    <rect x="30" y="238" width="224" height="108" rx="18" fill="#FFFFFF" opacity=".07"/>
    <text x="48" y="276" font-family="Georgia, serif" font-size="15" fill="#F2F7F6">不知道为什么今天特别舍不得。</text>
    <text x="48" y="310" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="10" fill="${color.nightMist}">靠窗的人 · 昨天</text>
    <rect x="30" y="366" width="224" height="108" rx="18" fill="#FFFFFF" opacity=".05"/>
    <text x="48" y="404" font-family="Georgia, serif" font-size="15" fill="#F2F7F6">落地才发现消息。</text>
    <text x="48" y="438" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="10" fill="${color.nightMist}">同机乘客 · 48h</text>
  `;
}

function mismatchContent() {
  return `
    <defs>
      <linearGradient id="oldNight" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#050A14"/>
        <stop offset="100%" stop-color="#0F1F38"/>
      </linearGradient>
    </defs>
    <rect x="8" y="8" width="268" height="568" rx="42" fill="url(#oldNight)"/>
    ${logoMark(98, 70, 88, true)}
    <text x="142" y="214" text-anchor="middle" font-family="Georgia, serif" font-size="28" font-weight="700" font-style="italic" fill="#F2E9D1">Head in the Clouds</text>
    <text x="142" y="246" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="11" letter-spacing="6" fill="#C4A46A">云上心事</text>
    <rect x="42" y="420" width="200" height="48" rx="24" fill="#C4A46A"/>
    <text x="142" y="450" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="14" font-weight="700" fill="#080E18">写下这一趟</text>
    <text x="142" y="514" text-anchor="middle" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="11" fill="#8FA8B6">This is the visual mismatch.</text>
  `;
}

function chip(x, y, label, value, fill) {
  return `
    <g transform="translate(${x} ${y})">
      <rect width="196" height="70" rx="18" fill="#FFFFFF" stroke="${color.line}"/>
      <circle cx="32" cy="35" r="13" fill="${fill}"/>
      <text x="56" y="30" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="12" fill="#71807D">${label}</text>
      <text x="56" y="49" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="13" font-weight="700" fill="${color.ink}">${value}</text>
    </g>
  `;
}

function sheetSvg() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1840" height="1260" viewBox="0 0 1840 1260">
  <rect width="1840" height="1260" fill="#F4F7F6"/>
  <text x="70" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="48" font-weight="800" fill="${color.ink}">Head in the Clouds · v8 Brand Bridge</text>
  <text x="70" y="120" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="20" fill="#64716F">Answering the real question: can High Altitude Mist become the app shell without killing the warm Cloud Card asset?</text>
  <text x="70" y="150" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="16" fill="#87918F">Principle: app shell carries air and distance; Cloud Card carries paper and memory; Flight Space can stay night but loses gold as global brand color.</text>

  ${chip(70, 190, "Shell BG", "High Altitude Mist", color.airBottom)}
  ${chip(286, 190, "Ink", color.ink, color.ink)}
  ${chip(502, 190, "Mist", color.mist, color.mist)}
  ${chip(718, 190, "Thought", color.thought, color.thought)}
  ${chip(934, 190, "Content Paper", color.paper, color.paper)}
  ${chip(1150, 190, "Night Space", color.nightBottom, color.nightBottom)}

  ${phoneFrame(86, 330, "01 App Shell", onboardingContent())}
  ${phoneFrame(468, 330, "02 Cloud Card Asset", cloudCardContent())}
  ${phoneFrame(850, 330, "03 Flight Space", flightSpaceContent())}
  ${phoneFrame(1232, 330, "04 Current Mismatch", mismatchContent())}

  <g transform="translate(86 1040)">
    <rect width="1422" height="120" rx="30" fill="#FFFFFF" stroke="${color.line}"/>
    <text x="34" y="44" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="22" font-weight="760" fill="${color.ink}">Product / UI decision</text>
    <text x="34" y="78" font-family="Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="17" fill="#64716F">Use High Altitude Mist for brand shell and onboarding. Keep warm paper only inside Cloud Card. Keep night only for bounded same-flight spaces. Remove gold from global navigation and CTA.</text>
  </g>
</svg>`;
}

fs.writeFileSync(path.join(outDir, "logo-exploration-v8-brand-bridge.svg"), sheetSvg());
