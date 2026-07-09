// 桌面剪贴板 - Windows 外壳（Electron）
// 透明无边框 + 置顶窗口；缩小成 3D 雪人桌面宠物；原生剪贴板与文件存储。
// 功能与 macOS 原生版完全一致（前端 index.html 共用同一套逻辑）。
const { app, BrowserWindow, ipcMain, clipboard, screen } = require('electron');
const path = require('path');
const fs = require('fs');

const FULL = { width: 420, height: 600 };
const PET  = { width: 170, height: 170 };

let win = null;

// ----- 原生持久化（替代不可靠的 localStorage）-----
// 对齐 macOS 版：使用单一、稳定的用户数据目录（对应 Mac 的
// ~/Library/Application Support/QuickBoard），而不是每次调用都重新探测多个候选。
// 关键修复：解析一次后缓存，之后所有读/写都落在同一路径，
// 杜绝「读取解析到 A 路径、写入解析到 B 路径」导致重开读不到数据的问题。
// 仅当用户数据目录不可写（极罕见）时，才回退到程序自身目录，且同样只解析一次。
let _storageDir = null;
function storageDir() {
  if (_storageDir) return _storageDir;
  const candidates = [
    path.join(app.getPath('userData'), 'QuickBoard'),
    path.join(__dirname, 'QuickBoard'),
  ];
  for (const base of candidates) {
    try { fs.mkdirSync(base, { recursive: true }); _storageDir = base; return base; } catch (e) {}
  }
  _storageDir = candidates[0];   // 都失败也先记住，避免反复探测
  return _storageDir;
}
console.log('[QuickBoard] 数据存储于：', storageDir());
function storageFile(key) {
  const f = key === 'sn' ? 'snippets.json' : (key === 'th' ? 'theme.txt' : key + '.dat');
  return path.join(storageDir(), f);
}
function readStorage(key) {
  try { return fs.readFileSync(storageFile(key), 'utf8'); } catch (e) { return null; }
}
function writeStorage(key, val) {
  try {
    const f = storageFile(key);
    fs.mkdirSync(path.dirname(f), { recursive: true });  // 防御：目录被删也能重建，避免静默丢数据
    fs.writeFileSync(f, val, 'utf8');
  } catch (e) {}
}

// 居中缩放，避免漂移（与 macOS 版一致）
function resizeTo(size) {
  if (!win) return;
  const b = win.getBounds();
  const x = Math.round(b.x + b.width / 2 - size.width / 2);
  const y = Math.round(b.y + b.height / 2 - size.height / 2);
  win.setBounds({ x, y, width: size.width, height: size.height }, false);
}

function createWindow() {
  win = new BrowserWindow({
    width: FULL.width,
    height: FULL.height,
    transparent: true,
    frame: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: true,
    roundedCorners: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });
  win.loadFile(path.join(__dirname, 'index.html'));
  try { win.setIcon(path.join(__dirname, 'icon.ico')); } catch (e) {}
  win.on('closed', () => { win = null; });
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => { app.quit(); });

// ===== 来自网页的桥接调用（与 macOS Swift 版一一对应）=====
ipcMain.handle('qb-load', (e, key) => readStorage(key));
ipcMain.on('qb-save', (e, k, v) => writeStorage(k, v));
ipcMain.handle('qb-copy', (e, text) => { clipboard.writeText(text || ''); });
ipcMain.on('qb-min', () => resizeTo(PET));     // 缩小成桌面宠物（雪人）
ipcMain.on('qb-max', () => resizeTo(FULL));    // 恢复完整窗口
ipcMain.on('qb-close', () => app.quit());
ipcMain.on('qb-export', (e, json) => {
  try {
    const dl = app.getPath('downloads');
    const d = new Date();
    const p = (n) => String(n).padStart(2, '0');
    const ts = `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
    fs.writeFileSync(path.join(dl, `snippets-${ts}.json`), json, 'utf8');
  } catch (e) {}
});

// ===== 宠物拖动：由原生按实时光标位置移动窗口 =====
// 对应 index.html Windows 分支的 dragStart/dragMove/dragEnd。
// 用「光标位置 - 抓取偏移」计算窗口新坐标，避免窗口被移动后 clientX 漂移导致的误差；
// Windows 上 setPosition 由 DWM 合成，不会像 macOS 透明窗那样抖动。
let dragOffset = null;
ipcMain.on('qb-drag-start', () => {
  if (!win) return;
  const pos = win.getPosition();
  const c = screen.getCursorScreenPoint();
  dragOffset = { x: c.x - pos[0], y: c.y - pos[1] };
});
ipcMain.on('qb-drag-move', () => {
  if (!win || !dragOffset) return;
  const c = screen.getCursorScreenPoint();
  win.setPosition(Math.round(c.x - dragOffset.x), Math.round(c.y - dragOffset.y));
});
ipcMain.on('qb-drag-end', () => { dragOffset = null; });
