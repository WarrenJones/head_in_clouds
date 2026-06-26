export function renderShareCardLandingHTML(card, { origin = "" } = {}) {
  const title = `${card.headline_quote || "云上心事"} · Head in the Clouds`;
  const route = card.route || "航班待确认";
  const postID = encodeURIComponent(card.post_id);
  const deepLinkURL = `headintheclouds://share/cards/${postID}`;
  const ogImageURL = `${origin}/share/cards/${postID}/og.svg`;

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <meta property="og:title" content="${escapeHTML(title)}">
  <meta property="og:description" content="${escapeHTML(card.text || "")}">
  <meta property="og:image" content="${escapeHTML(ogImageURL)}">
  <meta property="og:type" content="article">
  <title>${escapeHTML(title)}</title>
  <style>
    :root {
      color-scheme: dark;
      --ink: #f5ecd6;
      --muted: #b9a982;
      --paper: #efe0b8;
      --paper-ink: #17213a;
      --night: #050b19;
      --line: rgba(239, 224, 184, .24);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: Georgia, "Songti SC", "STSong", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at 30% 10%, rgba(205, 160, 82, .22), transparent 28rem),
        linear-gradient(160deg, #101a31 0%, #050b19 62%, #02050d 100%);
      display: grid;
      place-items: center;
      padding: 28px 18px;
    }
    main {
      width: min(440px, 100%);
    }
    .label {
      letter-spacing: .24em;
      text-transform: uppercase;
      color: var(--muted);
      font: 700 11px ui-monospace, SFMono-Regular, Menlo, monospace;
      margin: 0 0 18px;
    }
    .card {
      background: linear-gradient(180deg, #f4e7c2, var(--paper));
      color: var(--paper-ink);
      border: 1px solid rgba(255,255,255,.24);
      border-radius: 24px;
      padding: 28px;
      box-shadow: 0 24px 80px rgba(0,0,0,.42);
      position: relative;
      overflow: hidden;
    }
    .card:before {
      content: "";
      position: absolute;
      inset: 18px;
      border: 1px dashed rgba(23,33,58,.2);
      border-radius: 18px;
      pointer-events: none;
    }
    .route {
      font: 700 12px ui-monospace, SFMono-Regular, Menlo, monospace;
      letter-spacing: .16em;
      color: rgba(23,33,58,.66);
      margin-bottom: 54px;
      position: relative;
      z-index: 1;
    }
    h1 {
      margin: 0;
      font-size: clamp(30px, 7vw, 44px);
      line-height: 1.08;
      letter-spacing: -.04em;
      position: relative;
      z-index: 1;
    }
    .text {
      margin: 28px 0 0;
      color: rgba(23,33,58,.72);
      font-size: 15px;
      line-height: 1.8;
      position: relative;
      z-index: 1;
    }
    .actions {
      display: grid;
      gap: 12px;
      margin-top: 22px;
    }
    a {
      color: inherit;
      text-decoration: none;
    }
    .primary, .secondary {
      border-radius: 999px;
      padding: 14px 18px;
      text-align: center;
      font: 700 15px -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
    }
    .primary {
      background: linear-gradient(180deg, #e4bd67, #b88b38);
      color: #09101f;
      box-shadow: 0 12px 36px rgba(184,139,56,.36);
    }
    .secondary {
      border: 1px solid var(--line);
      color: var(--ink);
      background: rgba(255,255,255,.05);
    }
    .note {
      color: rgba(245,236,214,.62);
      font: 13px/1.7 -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
      margin: 18px 2px 0;
    }
    .brand {
      margin-top: 28px;
      color: rgba(245,236,214,.52);
      font: 11px ui-monospace, SFMono-Regular, Menlo, monospace;
      letter-spacing: .18em;
      text-align: center;
    }
  </style>
</head>
<body>
  <main>
    <p class="label">Shared Cloud Card</p>
    <article class="card" aria-label="Cloud Card">
      <div class="route">${escapeHTML(route)}</div>
      <h1>${escapeHTML(card.headline_quote || "有人在云上留下了一句话。")}</h1>
      <p class="text">${escapeHTML(card.text || "打开这张卡，看看这趟飞行里被留下的片刻。")}</p>
    </article>
    <section class="actions" aria-label="下一步">
      <a class="primary" href="${escapeHTML(deepLinkURL)}">看同班机笔记</a>
      <a class="secondary" href="/share/cards/${postID}?format=json">查看卡片数据</a>
    </section>
    <p class="note">如果还没安装 App，也可以先读完这张卡；航班验证只在发布到同班机或评论时需要。</p>
    <div class="brand">HEAD IN THE CLOUDS</div>
  </main>
</body>
</html>`;
}

export function renderShareCardOGSVG(card) {
  const route = card.route || "航班待确认";
  const quoteLines = wrapText(card.headline_quote || "有人在云上留下了一句话。", 16, 3);
  const textLines = wrapText(card.text || "打开这张卡，看看这趟飞行里被留下的片刻。", 24, 2);

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-label="Head in the Clouds share card">
  <defs>
    <linearGradient id="night" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0%" stop-color="#101a31"/>
      <stop offset="58%" stop-color="#050b19"/>
      <stop offset="100%" stop-color="#02050d"/>
    </linearGradient>
    <radialGradient id="glow" cx="28%" cy="12%" r="68%">
      <stop offset="0%" stop-color="#d6a858" stop-opacity=".42"/>
      <stop offset="48%" stop-color="#d6a858" stop-opacity=".08"/>
      <stop offset="100%" stop-color="#d6a858" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="paper" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0%" stop-color="#f4e7c2"/>
      <stop offset="100%" stop-color="#ead7a7"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="28" stdDeviation="28" flood-color="#000814" flood-opacity=".45"/>
    </filter>
  </defs>
  <rect width="1200" height="630" fill="url(#night)"/>
  <rect width="1200" height="630" fill="url(#glow)"/>
  <circle cx="988" cy="92" r="2" fill="#efe0b8" opacity=".68"/>
  <circle cx="1078" cy="174" r="1.6" fill="#efe0b8" opacity=".45"/>
  <circle cx="102" cy="132" r="1.5" fill="#efe0b8" opacity=".5"/>
  <g filter="url(#shadow)">
    <rect x="160" y="88" width="880" height="454" rx="38" fill="url(#paper)"/>
    <rect x="194" y="122" width="812" height="386" rx="24" fill="none" stroke="#17213a" stroke-opacity=".18" stroke-width="2" stroke-dasharray="8 10"/>
    <text x="232" y="172" fill="#17213a" fill-opacity=".58" font-family="Menlo, Monaco, monospace" font-size="24" font-weight="700" letter-spacing="4">${escapeHTML(route)}</text>
    <path d="M232 218 H968" stroke="#17213a" stroke-opacity=".12" stroke-width="2"/>
    ${quoteLines.map((line, index) => `<text x="232" y="${286 + index * 64}" fill="#17213a" font-family="Georgia, Songti SC, STSong, serif" font-size="50" font-weight="700">${escapeHTML(line)}</text>`).join("\n    ")}
    ${textLines.map((line, index) => `<text x="232" y="${472 + index * 34}" fill="#17213a" fill-opacity=".62" font-family="-apple-system, BlinkMacSystemFont, PingFang SC, sans-serif" font-size="24">${escapeHTML(line)}</text>`).join("\n    ")}
  </g>
  <text x="600" y="586" text-anchor="middle" fill="#f5ecd6" fill-opacity=".54" font-family="Menlo, Monaco, monospace" font-size="18" letter-spacing="5">HEAD IN THE CLOUDS</text>
</svg>`;
}

function wrapText(value, maxChars, maxLines) {
  const text = String(value ?? "").trim();
  if (!text) {
    return [];
  }

  const lines = [];
  for (let index = 0; index < text.length && lines.length < maxLines; index += maxChars) {
    let line = text.slice(index, index + maxChars);
    if (index + maxChars < text.length && lines.length === maxLines - 1) {
      line = `${line.slice(0, Math.max(0, maxChars - 1))}…`;
    }
    lines.push(line);
  }
  return lines;
}

function escapeHTML(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
