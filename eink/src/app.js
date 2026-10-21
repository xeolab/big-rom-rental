'use strict';
// XEO Rom 首次启动与激活 · 墨水屏演示。每次操作只整屏重绘一次（无动画）。
// QR 内容是与 iOS 端的契约，见 docs/tech/01-架构与双端契约.md §2 —— 改这里之前先改那里。
(() => {
  const DEVICE = 'ROM-DEMO-0001';
  const QR_ACTIVATE = 'xeorental://activate?device=' + DEVICE;
  const QR_RENEW = 'xeorental://renew?device=' + DEVICE;
  const STORE = 'xeo-rom-demo-v1';
  const SETUP = ['welcome', 'wifi', 'activate', 'audio', 'pod', 'big']; // 6 步，对应原方案 §3.2 配图
  const WIFI = [{ ssid: 'XEO_Cinema', lock: true }, { ssid: 'Cinema_WiFi', lock: true }, { ssid: 'XEO_Guest', lock: false }, { ssid: '其他网络…', lock: true, other: true }];
  const AUDIO = [
    { id: 'x202', name: 'XEO 202 蓝牙音箱', desc: '蓝牙 5.4 · 支持 LDAC · 一键房间声场校准', icon: 'x202', tag: 'XEO' }, // 规格摘自 xeo.io/202
    { id: 'bt', name: '蓝牙耳机', desc: '搜索并连接蓝牙耳机', icon: 'headphones' },
    { id: 'wired', name: '有线耳机', desc: '通过 3.5mm 或 USB-C 连接', icon: 'earbuds' },
    { id: 'none', name: '暂不使用耳机', desc: '不使用音频（不推荐）', icon: 'speaker' },
  ];

  const load = () => { try { return JSON.parse(localStorage.getItem(STORE)) || {}; } catch (e) { return {}; } };
  const save = v => { try { localStorage.setItem(STORE, JSON.stringify(v)); } catch (e) {} };
  const saved = load();
  const S = {
    step: saved.activated ? 'home' : 'welcome',
    wifi: saved.wifi || null, wifiPick: null, wifiConnected: !!saved.wifi, audio: saved.audio || null,
    sheet: null, // null | 'demo' | 'soon' | 'soonQr' | 'overdue'
  };

  // ---------- helpers ----------
  const $ = s => document.querySelector(s);
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  function dueHome() { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() + 3); return d; } // 首页示意：3 天后 24:00
  function dueSoon() { const d = new Date(); d.setHours(0, 0, 0, 0); return d; } // 即将到期：今天 24:00（剩余 ≤ 1 天才提醒）；fmtDay24 按「当天 24:00」显示
  function hoursLeft() { return Math.max(1, Math.floor((dueSoon().getTime() + 86400000 - Date.now()) / 3600000)); } // 向下取整：剩 23 小时 40 分显示 23
  function fmtDay24(d) { return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日 24:00'; }
  function fmtTime(d) { return (d.getMonth() + 1) + '月' + d.getDate() + '日 ' + pad(d.getHours()) + ':' + pad(d.getMinutes()); }
  const ICON = {
    wifi: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round"><path d="M2 9a15 15 0 0 1 20 0M5.5 12.5a10 10 0 0 1 13 0M9 16a5 5 0 0 1 6 0"/><circle cx="12" cy="19.5" r="1.4" fill="#000"/></svg>',
    x202: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><rect x="6" y="2" width="12" height="20" rx="2"/><circle cx="12" cy="7" r="1.6" fill="#000"/><circle cx="12" cy="15" r="3.6"/></svg>',
    headphones: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="3" y="14" width="4.5" height="7" rx="1" fill="#000"/><rect x="16.5" y="14" width="4.5" height="7" rx="1" fill="#000"/></svg>',
    earbuds: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><circle cx="7" cy="6" r="3" fill="#000"/><circle cx="17" cy="6" r="3" fill="#000"/><path d="M7 9v6a5 5 0 0 0 10 0V9M12 20v3"/></svg>',
    speaker: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><path d="M4 9h4l5-4v14l-5-4H4z" fill="#000"/><path d="M17 9l4 6M21 9l-4 6"/></svg>',
    sound: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><circle cx="12" cy="12" r="2.5" fill="#000"/><path d="M7.5 7.5a6.5 6.5 0 0 0 0 9M16.5 7.5a6.5 6.5 0 0 1 0 9M4.5 4.5a10.5 10.5 0 0 0 0 15M19.5 4.5a10.5 10.5 0 0 1 0 15"/></svg>',
    haptic: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><path d="M9 11V5a1.5 1.5 0 0 1 3 0v5M12 10V4a1.5 1.5 0 0 1 3 0v6M15 10V6a1.5 1.5 0 0 1 3 0v7a7 7 0 0 1-12 5l-3-4a1.5 1.5 0 0 1 2.4-1.8L9 15V11"/></svg>',
    shield: '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2"><path d="M12 2l8 3v6c0 5-3.5 9-8 11-4.5-2-8-6-8-11V5z"/><path d="M8.5 12l2.5 2.5 4.5-5"/></svg>',
    battery: '<svg viewBox="0 0 26 24" fill="none" stroke="#000" stroke-width="2"><rect x="2" y="7" width="19" height="10" rx="1.5"/><rect x="4.5" y="9.5" width="11" height="5" fill="#000" stroke="none"/><path d="M23.5 10.5v3"/></svg>',
  };
  // Line-art illustrations: plain strokes so they stay crisp on e-ink (no gradients / photos).
  const ILLUS = {
    welcome: '<svg viewBox="0 0 320 170" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">' +
      '<path d="M8 150 L70 104 L104 126 L160 82 L214 120 L250 98 L312 150"/><path d="M0 150 H320"/>' +
      '<circle cx="214" cy="62" r="40"/><path d="M182 52 a40 40 0 0 1 60 -18" stroke-width="1.5"/><circle cx="196" cy="74" r="5"/><circle cx="226" cy="48" r="3"/>' +
      '<circle cx="62" cy="34" r="2.5" fill="#000"/><circle cx="118" cy="22" r="1.8" fill="#000"/><circle cx="286" cy="34" r="2" fill="#000"/>' +
      '<path d="M128 150 v-26 a6 6 0 0 1 12 0 v26"/><circle cx="134" cy="112" r="6"/><path d="M128 132 h-6 M140 132 h6"/></svg>',
    big: '<svg viewBox="0 0 320 180" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">' +
      '<path d="M40 40 h150 a22 22 0 0 1 22 22 v8 a22 22 0 0 1 -22 22 h-36 l-12 -14 h-36 l-12 14 h-36 a22 22 0 0 1 -22 -22 v-8 a22 22 0 0 1 22 -22z"/>' +
      '<path d="M18 60 c-12 0 -14 -26 0 -30 M212 60 c12 0 14 -26 0 -30"/><path d="M76 56 h20 M136 56 h20" stroke-width="4"/>' +
      '<path d="M150 92 C150 120 210 110 220 136" stroke-dasharray="6 6"/><rect x="200" y="136" width="96" height="30" rx="4" fill="#fff"/><path d="M214 151 h20" stroke-width="3"/>' +
      '<text x="258" y="156" font-family="sans-serif" font-size="12" font-weight="700" fill="#000" stroke="none">Rom</text><text x="60" y="130" font-family="sans-serif" font-size="12" font-weight="700" fill="#000" stroke="none">USB-C</text></svg>',
    pod: '<svg viewBox="0 0 320 150" fill="none" stroke="#000" stroke-width="2.5" stroke-linejoin="round">' +
      '<path d="M160 14 L222 40 L240 96 L196 138 L124 138 L80 96 L98 40 Z"/><path d="M160 14 L160 60 L222 40 M160 60 L98 40 M160 60 L196 96 L240 96 M196 96 L196 138 M160 60 L124 96 L80 96 M124 96 L124 138 M124 96 L196 96"/>' +
      '<path d="M138 116 h44" stroke-width="2"/></svg>',
  };

  // ---------- QR (kazuhikoarase qrcode-generator, MIT, inlined from vendor/) ----------
  function drawQr(canvas, text, target) {
    const q = qrcode(0, 'M'); q.addData(text); q.make();
    const n = q.getModuleCount(), quiet = 4, total = n + quiet * 2;
    const mod = Math.max(3, Math.floor(target / total)); // integer CSS px per module → no blurry edges
    const dpr = Math.max(1, Math.round(window.devicePixelRatio || 1));
    const px = mod * dpr;
    canvas.width = total * px; canvas.height = total * px;
    canvas.style.width = canvas.style.height = total * mod + 'px';
    const c = canvas.getContext('2d');
    c.imageSmoothingEnabled = false;
    c.fillStyle = '#fff'; c.fillRect(0, 0, canvas.width, canvas.height);
    c.fillStyle = '#000';
    for (let r = 0; r < n; r++) for (let col = 0; col < n; col++) if (q.isDark(r, col)) c.fillRect((col + quiet) * px, (r + quiet) * px, px, px);
    canvas.dataset.payload = text;
  }
  const qrTarget = () => Math.min(400, Math.floor(Math.min(window.innerWidth - 90, window.innerHeight * 0.42)));

  // ---------- templates ----------
  const LOGO = document.getElementById('logo-src').innerHTML;
  function top(stepIdx) {
    const no = stepIdx >= 0 ? '<span class="stepno">' + (stepIdx + 1) + ' / ' + SETUP.length + '</span>' : '';
    return '<div class="top"><span class="logo" aria-label="XEO">' + LOGO + '</span><span class="spacer"></span>' + no +
      '<button class="demo-btn" data-act="demo" aria-label="演示面板">演示</button></div>' +
      (stepIdx >= 0 ? '<div class="dots" aria-hidden="true">' + SETUP.map((_, i) => '<i class="' + (i < stepIdx ? 'done' : i === stepIdx ? 'cur' : '') + '"></i>').join('') + '</div>' : '');
  }
  const foot = '<div class="foot"><span>XEO ROM · Immersive Experience</span><span>演示版 0.1</span></div>';
  const actions = (back, next, nextLabel, nextDisabled) =>
    '<div class="actions">' + (back ? '<button class="btn back" data-act="' + back + '">上一步</button>' : '') +
    '<button class="btn primary" data-act="' + next + '"' + (nextDisabled ? ' disabled' : '') + '>' + nextLabel + '</button></div>';

  const SCREENS = {
    welcome: () => top(0) + '<section class="screen"><p class="kicker">XEO BIG + ROM</p><h1>欢迎开启<br>沉浸式观影之旅</h1>' +
      '<p class="lead">戴上 BIG，进入属于你的巨幕世界。<br>接下来用一分钟完成设置。</p><div class="illus">' + ILLUS.welcome + '</div><div class="grow"></div>' +
      actions(null, 'next', '开始设置') + '</section>',

    wifi: () => {
      const rows = WIFI.map(w => '<button class="opt" role="radio" aria-checked="' + (S.wifiPick === w.ssid || (!S.wifiPick && S.wifi === w.ssid)) + '" data-act="wifi" data-ssid="' + esc(w.ssid) + '">' +
        '<span class="ic">' + ICON.wifi + '</span><span class="tx"><b>' + esc(w.ssid) + '</b>' + (w.other ? '<small>手动输入网络名称</small>' : '') + '</span>' +
        (w.lock ? '<span class="lock">加密</span>' : '') + '<span class="mark"></span></button>').join('');
      const pick = WIFI.find(w => w.ssid === S.wifiPick);
      const pw = pick && !S.wifiConnected ? (pick.other ? '<div class="pw"><input type="text" id="ssid" placeholder="网络名称" autocomplete="off"></div>' : '') +
        '<div class="pw">' + (pick.lock ? '<input type="password" id="pw" placeholder="输入密码（演示，可留空）" autocomplete="off">' : '<span class="grow"></span>') +
        '<button class="btn" data-act="connect">连接</button></div>' : '';
      const status = S.wifiConnected ? '<div class="status" role="status"><span class="ok">✓</span>已连接 ' + esc(S.wifi) + '</div>' : '';
      return top(1) + '<section class="screen"><h1>连接网络</h1><p class="lead">选择可用的 Wi-Fi 网络。</p><div class="list" role="radiogroup">' + rows + '</div>' + pw + status +
        '<p class="note">演示界面：不会真的联网。</p><div class="grow"></div>' + actions('prev', 'next', '下一步', !S.wifiConnected) + '</section>';
    },

    activate: () => top(2) + '<section class="screen"><h1>扫码激活设备</h1><p class="lead">用 XEO 租赁 App 扫码，关联你的租赁账号。</p>' +
      '<div class="qr-box"><div class="qr-frame"><canvas class="qr" data-qr="' + esc(QR_ACTIVATE) + '" role="img" aria-label="设备激活二维码"></canvas></div>' +
      '<div class="qr-cap">设备编号 ' + DEVICE + '</div></div>' +
      '<ol class="how"><li><b>1</b>打开 XEO 租赁 App，点首页「扫一扫」</li><li><b>2</b>扫描上方二维码，在手机上确认激活</li><li><b>3</b>回到这里，点「我已完成激活」</li></ol>' +
      '<div class="grow"></div>' + actions('prev', 'next', '我已完成激活') + '</section>',

    audio: () => top(3) + '<section class="screen"><h1>连接音频设备</h1><p class="lead">选择你要使用的音频设备，获得更好的沉浸体验。</p><div class="list" role="radiogroup">' +
      AUDIO.map(a => '<button class="opt" role="radio" aria-checked="' + (S.audio === a.id) + '" data-act="audio" data-id="' + a.id + '"><span class="ic">' + ICON[a.icon] + '</span>' +
        '<span class="tx"><b>' + a.name + (a.tag ? ' <span class="tag">' + a.tag + '</span>' : '') + '</b><small>' + a.desc + '</small></span><span class="mark"></span></button>').join('') +
      '</div>' + (S.audio === 'bt' || S.audio === 'x202' ? '<p class="note">演示：真机上这里会打开系统蓝牙配对。</p>' : '') + '<div class="grow"></div>' + actions('prev', 'next', '下一步', !S.audio) + '</section>',

    pod: () => top(4) + '<section class="screen"><p class="kicker">可选</p><h1>体验更完整的沉浸感<br>XEO Pod</h1>' +
      '<p class="lead">半封闭 20 面体设计，带来 9.2.4 沉浸式音效与触觉反馈，让虚拟影院更完整。</p><div class="illus">' + ILLUS.pod + '</div>' +
      '<div class="feats"><div class="feat">' + ICON.sound + '9.2.4<br>沉浸声场</div><div class="feat">' + ICON.haptic + '触觉反馈<br>身临其境</div><div class="feat">' + ICON.shield + '私密沉浸<br>专注观影</div></div>' +
      '<p class="note">可选配件，不影响本次租赁设备的使用；规格以正式产品资料为准。</p><div class="grow"></div>' + actions('prev', 'next', '继续') + '</section>',

    big: () => top(5) + '<section class="screen"><h1>连接并佩戴 BIG</h1><p class="lead">最后一步，进入沉浸观影世界。</p><div class="illus">' + ILLUS.big + '</div>' +
      '<ol class="steps"><li><span class="n">1</span><span>用 USB-C 线将 BIG 连接到 Rom</span></li><li><span class="n">2</span><span>戴上 BIG，调整绑带至稳固舒适</span></li>' +
      '<li><span class="n">3</span><span>按眼镜内的提示完成初始化（无需操作 Rom）</span></li></ol><div class="grow"></div>' + actions('prev', 'finish', '完成设置') + '</section>',

    done: () => top(-1) + '<section class="screen"><div class="big-check" aria-hidden="true">✓</div><h1>设置完成</h1><p class="lead">Rom 已激活。戴上 BIG，在 Rom 上选择影片，开始观影。</p>' +
      '<dl class="facts"><div><dt>设备</dt><dd>' + DEVICE + '</dd></div><div><dt>网络</dt><dd>' + esc(S.wifi || '—') + '</dd></div><div><dt>音频</dt><dd>' +
      ((AUDIO.find(a => a.id === S.audio) || {}).name || '—') + '</dd></div></dl><div class="grow"></div>' + actions(null, 'home', '开始观影') + '</section>',

    home: () => top(-1) + '<section class="screen"><div class="sys"><span>' + ICON.wifi + '</span><span>' + esc(S.wifi || '未连接') + '</span><span class="spacer" style="flex:1"></span><span>' + ICON.battery + '</span><span>86%</span></div>' +
      '<div class="home-hero" style="margin-top:14px"><span class="state">已激活 · 已就绪</span><h1>Rom 已就绪</h1><p class="lead" style="margin:0">戴上 BIG，在 Rom 上选择影片，进入虚拟影院。</p></div>' +
      '<dl class="facts"><div><dt>设备</dt><dd>' + DEVICE + '</dd></div><div><dt>租期至</dt><dd>' + fmtDay24(dueHome()) + '（示意）</dd></div><div><dt>音频</dt><dd>' +
      ((AUDIO.find(a => a.id === S.audio) || {}).name || '—') + '</dd></div></dl>' +
      '<p class="note">再次开机直接进入这里，无需重复联网与激活。右上角「演示」可触发到期 / 逾期提醒。</p><div class="grow"></div>' + foot + '</section>',
  };

  const SHEETS = {
    demo: () => '<div class="app"><div class="top"><span class="logo">' + LOGO + '</span><span class="spacer"></span><span class="stepno">演示面板</span></div>' +
      '<section class="screen"><h1>演示面板</h1><p class="lead">给演示者用的快捷入口，正式产品中没有这一页。</p><div class="menu">' +
      '<button class="btn" data-act="soon">触发「租期即将到期」提醒</button><button class="btn" data-act="overdue">触发「已逾期」提醒</button>' +
      '<button class="btn" data-act="fullscreen">全屏显示</button><button class="btn" data-act="reset">重置演示（回到首次启动）</button></div>' +
      '<div class="grow"></div><div class="actions"><button class="btn" data-act="close">关闭</button></div></section></div>',

    soon: () => '<div class="app"><div class="top"><span class="logo">' + LOGO + '</span><span class="spacer"></span><span class="sys">' + ICON.wifi + ICON.battery + '</span></div>' +
      '<section class="screen"><span class="alert">⏰ 租期提醒</span><h1>租期即将到期</h1>' +
      '<p class="due">您的 Rom 设备租期还剩<span class="big-num">' + hoursLeft() + '</span>小时<br>到期时间：<b>今天 24:00</b></p>' +
      '<div class="illus">' + ILLUS.welcome + '</div><p class="lead">继续沉浸，探索更大的世界。<br>可在 XEO 租赁 App 中续租或预约归还。</p><div class="grow"></div>' +
      '<div class="actions"><button class="btn" data-act="close">稍后提醒</button><button class="btn primary" data-act="soonQr">去续租</button></div></section></div>',

    soonQr: () => '<div class="app"><div class="top"><span class="logo">' + LOGO + '</span><span class="spacer"></span><span class="stepno">续租 / 归还</span></div>' +
      '<section class="screen"><h1>扫码续租或归还</h1><p class="lead">用 XEO 租赁 App 扫码续租或归还。</p>' +
      '<div class="qr-box"><div class="qr-frame"><canvas class="qr" data-qr="' + esc(QR_RENEW) + '" role="img" aria-label="续租二维码"></canvas></div><div class="qr-cap">设备编号 ' + DEVICE + '<br>到期 ' + fmtDay24(dueSoon()) + '</div></div>' +
      '<p class="note">续租成功后到期时间自动更新，无需重新激活。</p><div class="grow"></div><div class="actions"><button class="btn" data-act="close">关闭</button></div></section></div>',

    overdue: () => {
      const due = new Date(Date.now() - 5 * 3600 * 1000);
      return '<div class="app"><div class="top"><span class="logo">' + LOGO + '</span><span class="spacer"></span><span class="sys">' + ICON.wifi + ICON.battery + '</span></div>' +
        '<section class="screen"><span class="alert warn">! 已逾期</span><h1>租期已逾期<span class="big-num" style="font-size:1em">5</span>小时</h1>' +
        '<p class="due">到期时间：<b>' + fmtTime(due) + '</b><br>逾期期间按日计费，请尽快续费或安排归还。</p>' +
        '<div class="qr-box"><div class="qr-frame"><canvas class="qr" data-qr="' + esc(QR_RENEW) + '" role="img" aria-label="逾期续费二维码"></canvas></div><div class="qr-cap">用 XEO 租赁 App 扫码续费 · ' + DEVICE + '</div></div>' +
        '<div class="grow"></div><div class="actions"><button class="btn" data-act="close">关闭，继续使用</button></div></section></div>';
    },
  };

  // ---------- render ----------
  // The e-ink browser (Onyx Chromium 85) has no dvh and its 100vh includes the URL bar; use the real visible height.
  function fitHeight() { document.documentElement.style.setProperty('--app-h', window.innerHeight + 'px'); }
  function render() {
    fitHeight();
    const root = $('#root');
    root.innerHTML = '<div class="app">' + SCREENS[S.step]() + '</div>';
    let sheet = $('#sheet');
    if (S.sheet) {
      if (!sheet) { sheet = document.createElement('div'); sheet.id = 'sheet'; sheet.className = 'sheet'; sheet.setAttribute('role', 'dialog'); document.body.append(sheet); }
      sheet.innerHTML = SHEETS[S.sheet]();
      root.setAttribute('aria-hidden', 'true');
    } else { if (sheet) sheet.remove(); root.removeAttribute('aria-hidden'); }
    for (const c of document.querySelectorAll('canvas[data-qr]')) drawQr(c, c.getAttribute('data-qr'), qrTarget());
    window.scrollTo(0, 0);
  }
  function go(step) { S.step = step; render(); }
  function persist() { save({ activated: S.step === 'done' || S.step === 'home' || load().activated, wifi: S.wifi, audio: S.audio }); }

  const ACT = {
    next() { go(SETUP[SETUP.indexOf(S.step) + 1]); },
    prev() { const i = SETUP.indexOf(S.step); go(SETUP[Math.max(0, i - 1)]); },
    wifi(el) { S.wifiPick = el.dataset.ssid; S.wifiConnected = false; S.wifi = null; render(); const f = $('#ssid') || $('#pw'); if (f) f.focus(); },
    connect() {
      const other = WIFI.find(w => w.ssid === S.wifiPick && w.other), typed = other && $('#ssid') ? $('#ssid').value.trim() : '';
      S.wifi = other ? (typed || '自定义网络') : S.wifiPick; S.wifiConnected = true; render();
    },
    audio(el) { S.audio = el.dataset.id; render(); },
    finish() { go('done'); persist(); },
    home() { go('home'); persist(); },
    demo() { S.sheet = 'demo'; render(); },
    soon() { S.sheet = 'soon'; render(); },
    soonQr() { S.sheet = 'soonQr'; render(); },
    overdue() { S.sheet = 'overdue'; render(); },
    close() { S.sheet = null; render(); },
    reset() { try { localStorage.removeItem(STORE); } catch (e) {} Object.assign(S, { step: 'welcome', wifi: null, wifiPick: null, wifiConnected: false, audio: null, sheet: null }); render(); },
    fullscreen() {
      const el = document.documentElement, rq = el.requestFullscreen || el.webkitRequestFullscreen;
      S.sheet = null; render();
      if (rq) try { const p = rq.call(el); if (p && p.catch) p.catch(() => {}); } catch (e) {}
    },
  };
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-act]');
    if (!el || el.disabled) return;
    const fn = ACT[el.dataset.act]; if (fn) fn(el);
  });
  document.addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.id === 'pw') ACT.connect(); });
  let rt = null;
  window.addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(render, 200); });
  render();
  window.__romDemo = { state: S, act: ACT, payloads: { activate: QR_ACTIVATE, renew: QR_RENEW } };
})();
