export function renderAdminEventsDashboardHTML({
  summary,
  recentEvents = [],
  filters = {}
} = {}) {
  const eventsByName = Object.entries(summary?.events_by_name ?? {});
  const missingEventNames = summary?.missing_event_names ?? [];
  const expectedEventNames = summary?.expected_event_names ?? [];

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Head in the Clouds - Event Dashboard</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #07111f;
      --panel: #0f1d31;
      --panel-soft: #13243b;
      --line: rgba(213, 181, 111, 0.22);
      --text: #f5ead3;
      --muted: #9fb0c8;
      --gold: #d6b66e;
      --danger: #ff9f8a;
      --ok: #82d8b4;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 12% 10%, rgba(214, 182, 110, 0.16), transparent 28rem),
        linear-gradient(135deg, #050a13 0%, var(--bg) 54%, #0b1830 100%);
      color: var(--text);
      min-height: 100vh;
    }
    main {
      width: min(1180px, calc(100vw - 32px));
      margin: 0 auto;
      padding: 40px 0 56px;
    }
    header {
      display: flex;
      justify-content: space-between;
      gap: 24px;
      align-items: flex-end;
      margin-bottom: 28px;
    }
    h1 {
      margin: 0 0 8px;
      font-size: clamp(30px, 4vw, 52px);
      line-height: 1;
      letter-spacing: -0.04em;
      font-family: Georgia, "Times New Roman", serif;
    }
    h2 {
      margin: 0 0 16px;
      font-size: 15px;
      color: var(--gold);
      text-transform: uppercase;
      letter-spacing: 0.16em;
    }
    p { margin: 0; color: var(--muted); }
    .grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
      margin-bottom: 18px;
    }
    .card {
      background: linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.025));
      border: 1px solid var(--line);
      border-radius: 22px;
      padding: 18px;
      box-shadow: 0 18px 60px rgba(0, 0, 0, 0.24);
    }
    .metric {
      font-size: 32px;
      font-weight: 700;
      letter-spacing: -0.03em;
    }
    .label {
      margin-top: 6px;
      color: var(--muted);
      font-size: 13px;
    }
    .section {
      background: rgba(15, 29, 49, 0.72);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 22px;
      margin-top: 18px;
      backdrop-filter: blur(10px);
    }
    .chips {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .chip {
      border: 1px solid rgba(214, 182, 110, 0.28);
      border-radius: 999px;
      padding: 7px 10px;
      background: var(--panel-soft);
      color: var(--text);
      font: 12px/1.2 ui-monospace, SFMono-Regular, Menlo, monospace;
    }
    .missing {
      border-color: rgba(255, 159, 138, 0.45);
      color: var(--danger);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      overflow: hidden;
    }
    th, td {
      padding: 12px 10px;
      text-align: left;
      border-bottom: 1px solid rgba(213, 181, 111, 0.14);
      vertical-align: top;
      font-size: 13px;
    }
    th {
      color: var(--gold);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }
    code {
      color: #f8d992;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12px;
      word-break: break-word;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      color: var(--muted);
      font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
      max-width: 520px;
    }
    .status-ok { color: var(--ok); }
    .status-danger { color: var(--danger); }
    @media (max-width: 860px) {
      header, .grid { display: block; }
      .card { margin-bottom: 12px; }
      main { width: min(100vw - 20px, 1180px); padding-top: 24px; }
      table { display: block; overflow-x: auto; }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>Event Dashboard</h1>
        <p>First-party staging evidence for Head in the Clouds.</p>
      </div>
      <p><code>${escapeHTML(filters.smoke_run_id || "all smoke runs")}</code></p>
    </header>

    <section class="grid" aria-label="summary metrics">
      ${metricCard(summary?.total_events ?? 0, "Total events")}
      ${metricCard(eventsByName.length, "Event names seen")}
      ${metricCard(missingEventNames.length, "Missing expected events", missingEventNames.length === 0 ? "status-ok" : "status-danger")}
      ${metricCard(recentEvents.length, "Recent rows")}
    </section>

    <section class="section">
      <h2>Expected Coverage</h2>
      <div class="chips">
        ${expectedEventNames.length > 0
          ? expectedEventNames.map((eventName) => `<span class="chip${missingEventNames.includes(eventName) ? " missing" : ""}">${escapeHTML(eventName)}</span>`).join("")
          : `<span class="chip">No expected events filter supplied</span>`}
      </div>
    </section>

    <section class="section">
      <h2>Counts By Event</h2>
      <div class="chips">
        ${eventsByName.length > 0
          ? eventsByName.map(([eventName, count]) => `<span class="chip">${escapeHTML(eventName)}: ${Number(count)}</span>`).join("")
          : `<span class="chip">No events found</span>`}
      </div>
    </section>

    <section class="section">
      <h2>Recent Events</h2>
      <table>
        <thead>
          <tr>
            <th>Received</th>
            <th>Event</th>
            <th>Platform</th>
            <th>Properties</th>
          </tr>
        </thead>
        <tbody>
          ${recentEvents.length > 0 ? recentEvents.map(renderEventRow).join("") : `<tr><td colspan="4">No recent events.</td></tr>`}
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>`;
}

function metricCard(value, label, valueClass = "") {
  return `<div class="card"><div class="metric ${valueClass}">${escapeHTML(String(value))}</div><div class="label">${escapeHTML(label)}</div></div>`;
}

function renderEventRow(event) {
  return `<tr>
    <td><code>${escapeHTML(event.received_at ?? "")}</code></td>
    <td><code>${escapeHTML(event.event_name ?? "")}</code></td>
    <td>${escapeHTML(event.platform ?? "")}</td>
    <td><pre>${escapeHTML(JSON.stringify(event.properties ?? {}, null, 2))}</pre></td>
  </tr>`;
}

function escapeHTML(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
