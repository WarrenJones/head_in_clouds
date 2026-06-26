const DEFAULT_CONTACT_EMAIL = "support@headintheclouds.app";

export function renderPrivacyHTML({ contactEmail = process.env.HIC_LEGAL_CONTACT_EMAIL || DEFAULT_CONTACT_EMAIL } = {}) {
  return renderLegalPage({
    title: "隐私政策",
    updatedAt: "2026-05-25",
    contactEmail,
    sections: [
      {
        heading: "我们收集什么",
        body: "云上心事会收集你主动输入的一句话、卡片模板选择、航班上下文的脱敏信息、账号登录方式、设备推送令牌以及必要的事件日志。票证原图默认不保存；用于验证后仅保留必要的哈希或脱敏结果。"
      },
      {
        heading: "我们不收集什么",
        body: "公开内容、分享卡片和埋点事件不得包含姓名、证件号、票号、完整座位号、手机号明文、邮箱明文或支付卡信息。服务端会对事件属性做脱敏过滤。"
      },
      {
        heading: "数据如何使用",
        body: "数据用于保存你的飞行卡片、验证同班机可见性、发送登机提醒或同班机新笔记通知、处理举报和屏蔽、完成购买校验、排查服务可用性。"
      },
      {
        heading: "数据存储与跨境",
        body: "面向中国市场的主链路部署在中国区一方服务。生产环境不会要求 iOS 客户端直接连接海外 Supabase 或 PostHog Cloud 作为主数据链路。"
      },
      {
        heading: "账号删除",
        body: "你可以在应用设置中发起删除账号。删除后账号进入恢复期，恢复期结束后我们会按产品规则删除或匿名化相关数据。"
      },
      {
        heading: "联系我们",
        body: `如需查询、更正或删除数据，请联系 ${contactEmail}。`
      }
    ]
  });
}

export function renderTermsHTML({ contactEmail = process.env.HIC_LEGAL_CONTACT_EMAIL || DEFAULT_CONTACT_EMAIL } = {}) {
  return renderLegalPage({
    title: "用户协议",
    updatedAt: "2026-05-25",
    contactEmail,
    sections: [
      {
        heading: "服务内容",
        body: "云上心事提供飞行途中一句话记录、Cloud Card 生成、私人分享、同班机空间、登机提醒和同班机新笔记通知等功能。"
      },
      {
        heading: "用户内容",
        body: "你对自己发布的文字、评论和卡片负责。不得发布违法、侵权、骚扰、仇恨、广告、隐私泄露或其他不适合公开传播的内容。"
      },
      {
        heading: "同班机边界",
        body: "同班机空间依赖航班上下文和验证状态。未验证用户可查看受限内容，但不能在同班机内评论或发布。"
      },
      {
        heading: "举报与处置",
        body: "用户可举报、隐藏、屏蔽或删除自己的内容。我们会根据举报类型和风险程度进行处理。"
      },
      {
        heading: "付费服务",
        body: "如你购买卡片模板、导出、会员或其他增值服务，具体价格、有效期和退款规则以应用内展示和 App Store 规则为准。"
      },
      {
        heading: "联系我们",
        body: `如需反馈协议问题，请联系 ${contactEmail}。`
      }
    ]
  });
}

function renderLegalPage({ title, updatedAt, sections }) {
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHTML(title)} - 云上心事</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #071426;
      --card: #10213a;
      --text: #f4ecd8;
      --muted: #9badc9;
      --line: rgba(244, 236, 216, 0.16);
      --accent: #d2aa61;
    }
    body {
      margin: 0;
      background: radial-gradient(circle at 18% 0%, #18325a 0, #071426 42%, #030813 100%);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", sans-serif;
      line-height: 1.72;
    }
    main {
      box-sizing: border-box;
      width: min(760px, 100%);
      margin: 0 auto;
      padding: 48px 20px 72px;
    }
    article {
      border: 1px solid var(--line);
      border-radius: 28px;
      background: rgba(16, 33, 58, 0.78);
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.35);
      padding: clamp(24px, 5vw, 48px);
    }
    h1 {
      margin: 0 0 8px;
      font-family: Georgia, "Times New Roman", serif;
      font-size: clamp(32px, 8vw, 56px);
      line-height: 1;
    }
    .meta {
      color: var(--accent);
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-size: 12px;
    }
    section {
      border-top: 1px solid var(--line);
      margin-top: 28px;
      padding-top: 24px;
    }
    h2 {
      margin: 0 0 8px;
      font-size: 18px;
    }
    p {
      margin: 0;
      color: var(--muted);
      font-size: 15px;
    }
  </style>
</head>
<body>
  <main>
    <article>
      <h1>${escapeHTML(title)}</h1>
      <div class="meta">Head in the Clouds · Updated ${escapeHTML(updatedAt)}</div>
      ${sections.map((section) => `<section><h2>${escapeHTML(section.heading)}</h2><p>${escapeHTML(section.body)}</p></section>`).join("")}
    </article>
  </main>
</body>
</html>`;
}

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
