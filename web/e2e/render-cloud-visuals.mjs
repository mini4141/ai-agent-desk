// Renders AWS-side proof images from CLI output (there is no console login): CloudWatch widget PNGs + alarm table,
// and an X-Ray trace summary built from get-trace-summaries / batch-get-traces JSON.
// Inputs live in .local/ (written by scripts/capture-cloud-extras.sh); outputs go to proof/phase2-cloud/screenshots/.
import { chromium } from "@playwright/test";
import { readFileSync, writeFileSync } from "node:fs";

const root = process.argv[2];
const shots = `${root}/proof/phase2-cloud/screenshots`;
const b64 = (f) => readFileSync(`${root}/.local/${f}`).toString("base64");
const esc = (s) => String(s).replace(/[<&>]/g, (c) => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;" })[c]);
const redact = (s) => s.replace(/\b\d{12}\b/g, "<ACCOUNT_ID>");
const css = "body{font-family:system-ui,sans-serif;margin:24px;background:#fff;color:#1b1f2a}h1{font-size:20px}table{border-collapse:collapse}td,th{border:1px solid #ccd;padding:6px 12px;font-size:13px;text-align:left}img{display:block;margin:8px 0;border:1px solid #ddd}.ok{color:#1a7f37;font-weight:700}.mono{font-family:ui-monospace,monospace;font-size:12px}";

const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 980, height: 800 } })).newPage();
const snap = async (html, name) => {
  await page.setContent(`<style>${css}</style>${html}`);
  await page.screenshot({ path: `${shots}/${name}.png`, fullPage: true });
};

// 06: CloudWatch alarms + metric graphs rendered with get-metric-widget-image
const alarms = JSON.parse(readFileSync(`${root}/.local/alarms.json`, "utf8"));
await snap(
  `<h1>CloudWatch: alarms and metrics (rendered from the CLI)</h1>
   <table><tr><th>Alarm</th><th>State</th><th>Metric</th><th>Threshold</th></tr>
   ${alarms.map((a) => `<tr><td>${esc(a.AlarmName)}</td><td class="${a.StateValue === "OK" ? "ok" : ""}">${esc(a.StateValue)}</td><td>${esc(a.Namespace)} / ${esc(a.MetricName)}</td><td>${esc(a.Threshold)}</td></tr>`).join("")}</table>
   ${["w1", "w2", "w3"].map((w) => `<img src="data:image/png;base64,${b64(`${w}.png`)}">`).join("")}`,
  "06-cloudwatch-alarms",
);

// 07: X-Ray trace summary (Rails -> RDS / ElastiCache / Bedrock subsegments)
const sums = JSON.parse(readFileSync(`${root}/.local/xray-summaries.json`, "utf8")).sort((a, b) => b.Duration - a.Duration).slice(0, 8);
const trace = JSON.parse(readFileSync(`${root}/.local/xray-trace.json`, "utf8")).Traces[0];
const rows = [];
const walk = (s, depth) => {
  rows.push({ depth, name: s.name, ms: Math.round((s.end_time - s.start_time) * 1000), ns: s.namespace ?? "" });
  (s.subsegments ?? []).forEach((x) => walk(x, depth + 1));
};
trace.Segments.map((s) => JSON.parse(s.Document)).forEach((s) => walk(s, 0));
const interesting = rows.filter((r) => r.depth <= 1 || /bedrock|polly|converse|retrieval|llm|tool|agent/i.test(r.name)).slice(0, 40);
await snap(
  `<h1>AWS X-Ray: trace summary (ADOT sidecar → X-Ray)</h1>
   <p>Slowest recent traces (last 3 h):</p>
   <table><tr><th>Trace id</th><th>Duration (s)</th><th>URL</th></tr>${sums.map((t) => `<tr><td class="mono">${esc(t.Id)}</td><td>${t.Duration.toFixed(3)}</td><td class="mono">${esc((t.Http?.HttpURL ?? "").replace(/^https?:\/\/[^/]+/, ""))}</td></tr>`).join("")}</table>
   <p>Segments of <span class="mono">${esc(trace.Id)}</span> (${rows.length} spans; first ${interesting.length} shown):</p>
   <table>${interesting.map((r) => `<tr><td class="mono">${"&nbsp;&nbsp;".repeat(r.depth)}${esc(redact(r.name))}</td><td>${r.ms} ms</td></tr>`).join("")}</table>`,
  "07-xray-trace-summary",
);
await browser.close();
writeFileSync(`${root}/proof/phase2-cloud/logs/xray-trace-summary.txt`, redact(`${trace.Id}\n${rows.map((r) => `${"  ".repeat(r.depth)}${r.name} ${r.ms}ms`).join("\n")}\n`));
console.log("rendered 06 and 07");
