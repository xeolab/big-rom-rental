// Minimal headless-Chrome driver over CDP (Node 22 built-in WebSocket, no deps).
// Usage: node games/test/cdp.mjs <url> <steps.json> <outDir> [WxH]   (needs Google Chrome installed at the macOS default path)
// E2E: node games/test/cdp.mjs "file://$PWD/games/dist/XEO-Game-Rom.html" games/test/e2e-gamepad.json /tmp/xeo-shots
// steps: [{eval:"js"}, {wait:ms}, {shot:"name"}, {pad:{buttons:[0], axes:[0,0]}, hold:ms}]
// A fake gamepad is injected before page scripts run: window.__pad = {buttons:[], axes:[0,0,0,0]}.
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';

const [url, stepsFile, outDir, size = '412x915'] = process.argv.slice(2);
const steps = JSON.parse(readFileSync(stepsFile, 'utf8'));
mkdirSync(outDir, { recursive: true });
const [W, H] = size.split('x').map(Number);
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9300 + Math.floor(Math.random() * 500);
const proc = spawn(CH, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${port}`,
  `--user-data-dir=/tmp/cdp-prof-${port}`, '--allow-file-access-from-files', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let target;
for (let i = 0; i < 50 && !target; i++) {
  await sleep(200);
  try { target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find(t => t.type === 'page'); } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pending = new Map(); const logs = [];
ws.addEventListener('message', ev => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  if (m.method === 'Runtime.consoleAPICalled') logs.push(m.params.type + ': ' + m.params.args.map(a => a.value ?? a.description).join(' '));
  if (m.method === 'Runtime.exceptionThrown') logs.push('EXCEPTION: ' + JSON.stringify(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text));
});
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Runtime.enable'); await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 2, mobile: true });
await send('Page.addScriptToEvaluateOnNewDocument', { source: `
  window.__pad={buttons:[],axes:[0,0,0,0]};
  navigator.getGamepads=()=>[{id:'Sim Pad',index:0,connected:true,mapping:'standard',axes:window.__pad.axes.slice(),
    buttons:Array.from({length:17},(_,i)=>({pressed:window.__pad.buttons.includes(i),value:window.__pad.buttons.includes(i)?1:0}))}];` });
await send('Page.navigate', { url });
await sleep(800);
const results = [];
for (const s of steps) {
  if (s.eval) { const r = await send('Runtime.evaluate', { expression: s.eval, returnByValue: true, awaitPromise: true }); results.push(r.result?.result?.value ?? r.result?.exceptionDetails?.exception?.description); }
  if (s.key) { for (const type of ['keyDown', 'keyUp']) await send('Input.dispatchKeyEvent', { type, key: s.key, code: s.code || s.key, windowsVirtualKeyCode: s.vk || 0 }); }
  if (s.pad) { await send('Runtime.evaluate', { expression: `window.__pad=${JSON.stringify(s.pad)}` }); await sleep(s.hold ?? 120);
    await send('Runtime.evaluate', { expression: `window.__pad={buttons:[],axes:[0,0,0,0]}` }); await sleep(120); }
  if (s.wait) await sleep(s.wait);
  if (s.shot) { const r = await send('Page.captureScreenshot', { format: 'png' }); writeFileSync(`${outDir}/${s.shot}.png`, Buffer.from(r.result.data, 'base64')); }
}
console.log(JSON.stringify({ results, logs }, null, 1));
ws.close(); proc.kill();
