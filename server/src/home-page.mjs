export function renderHomeHTML() {
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>云上心事 - 给这一趟飞行，留下一句话</title>
  <meta name="description" content="云上心事是一款飞行情绪记录 App。写下一句话，生成一张属于这趟飞行的 Cloud Card。">
  <style>
    :root {
      color-scheme: dark;
      --bg: #071426;
      --paper: #f7ebc8;
      --text: #fff3d1;
      --muted: #9badc9;
      --accent: #d2aa61;
      --line: rgba(247, 235, 200, 0.16);
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      min-height: 100vh;
      background:
        radial-gradient(circle at 18% 0%, rgba(49, 91, 141, 0.72) 0, rgba(7, 20, 38, 0.95) 38%, #030813 100%),
        #071426;
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", sans-serif;
    }
    main {
      width: min(1040px, 100%);
      margin: 0 auto;
      padding: 72px 20px 56px;
    }
    .hero {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 360px;
      gap: 48px;
      align-items: center;
    }
    .eyebrow {
      color: var(--accent);
      font-size: 13px;
      letter-spacing: 0.22em;
      text-transform: uppercase;
    }
    h1 {
      margin: 18px 0 0;
      font-family: Georgia, "Times New Roman", serif;
      font-size: clamp(52px, 9vw, 104px);
      line-height: 0.94;
      letter-spacing: -0.05em;
    }
    .tagline {
      margin: 24px 0 0;
      max-width: 620px;
      color: var(--muted);
      font-size: clamp(20px, 4vw, 30px);
      line-height: 1.5;
    }
    .actions {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      margin-top: 34px;
    }
    a {
      color: inherit;
      text-decoration: none;
    }
    .button {
      border: 1px solid rgba(210, 170, 97, 0.42);
      border-radius: 999px;
      padding: 14px 22px;
      background: rgba(210, 170, 97, 0.14);
      color: var(--text);
      font-size: 15px;
    }
    .button.primary {
      background: linear-gradient(135deg, #ecd08a, #bb8d3d);
      color: #081224;
      border-color: transparent;
      font-weight: 700;
    }
    .card {
      border: 1px solid rgba(247, 235, 200, 0.22);
      border-radius: 34px;
      background: rgba(3, 8, 19, 0.42);
      padding: 22px;
      box-shadow: 0 28px 90px rgba(0, 0, 0, 0.36);
    }
    .ticket {
      border-radius: 24px;
      background: linear-gradient(160deg, #fff1c9, #d8b56a);
      color: #18243a;
      padding: 24px;
      min-height: 420px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }
    .route {
      display: flex;
      justify-content: space-between;
      color: rgba(24, 36, 58, 0.7);
      font-size: 13px;
      letter-spacing: 0.18em;
    }
    .quote {
      font-size: 32px;
      line-height: 1.28;
      font-weight: 800;
      letter-spacing: -0.04em;
    }
    .stamp {
      color: rgba(24, 36, 58, 0.52);
      font-size: 12px;
      letter-spacing: 0.2em;
      text-transform: uppercase;
    }
    .features {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 18px;
      margin-top: 54px;
    }
    .feature {
      border: 1px solid var(--line);
      border-radius: 24px;
      background: rgba(16, 33, 58, 0.62);
      padding: 22px;
    }
    .feature h2 {
      margin: 0 0 8px;
      font-size: 18px;
    }
    .feature p {
      margin: 0;
      color: var(--muted);
      line-height: 1.7;
      font-size: 14px;
    }
    footer {
      display: flex;
      gap: 18px;
      margin-top: 44px;
      color: rgba(255, 243, 209, 0.58);
      font-size: 13px;
    }
    @media (max-width: 820px) {
      .hero, .features {
        grid-template-columns: 1fr;
      }
      .card {
        max-width: 420px;
      }
      footer {
        flex-direction: column;
      }
    }
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <div>
        <div class="eyebrow">Head in the Clouds</div>
        <h1>云上心事</h1>
        <p class="tagline">给这一趟飞行，留下一句话。写下此刻的心事，生成一张像明信片一样的 Cloud Card。</p>
        <div class="actions">
          <a class="button primary" href="/privacy">查看隐私政策</a>
          <a class="button" href="/terms">查看用户协议</a>
        </div>
      </div>
      <div class="card" aria-label="Cloud Card preview">
        <div class="ticket">
          <div class="route"><span>SHA</span><span>MU5405</span><span>CTU</span></div>
          <div class="quote">我把没有说出口的话，带过了云层。</div>
          <div class="stamp">private cloud card · no public seat number</div>
        </div>
      </div>
    </section>
    <section class="features">
      <div class="feature"><h2>一句话开始</h2><p>不要求先扫描登机牌。用户可以先写一句，航班信息稍后补。</p></div>
      <div class="feature"><h2>私人卡片</h2><p>生成复古明信片风格 Cloud Card，可保存、分享或作为同班机入口。</p></div>
      <div class="feature"><h2>同班机边界</h2><p>发布、评论和同班机通知需要完成航班验证；公开区域不展示具体座位号。</p></div>
    </section>
    <footer>
      <span>© 2026 云上心事</span>
      <a href="/privacy">隐私政策</a>
      <a href="/terms">用户协议</a>
    </footer>
  </main>
</body>
</html>`;
}
