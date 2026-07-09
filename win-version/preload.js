// 桌面剪贴板 - 预加载脚本（Electron / Windows）
// 向渲染进程暴露 window.electronAPI，对应 index.html 的 NATIVE() 调用。
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  // 读取持久化数据，把结果通过 Promise 直接返回。
  // 重要：contextIsolation 下 preload 运行在「隔离世界」，无法访问主世界的 window.__qbLoad，
  // 所以这里不再由 preload 回调页面函数（那个写法在真实 Electron 里永远不触发，导致重开空白）。
  // 改为返回值，由 index.html 的 ld() 用 .then 自行消费（见下方）。Mac 端走 webkit 桥、无返回值，
  // ld() 的 .then 自然不触发，由原生侧直接回调 __qbLoad，两端互不影响。
  load: (key) => ipcRenderer.invoke('qb-load', key),
  // 注意：index.html 的 NATIVE('save', {k, v}) 把 {k,v} 作为单个对象传入，
  // 这里解包后分别发给主进程（与 Mac 版 Swift 侧按字典解析一致）。
  save: (payload) => ipcRenderer.send('qb-save', payload && payload.k, payload && payload.v),
  copy: (text) => ipcRenderer.invoke('qb-copy', text),
  min: () => ipcRenderer.send('qb-min'),
  max: () => ipcRenderer.send('qb-max'),
  close: () => ipcRenderer.send('qb-close'),
  dragStart: () => ipcRenderer.send('qb-drag-start'),
  dragMove: () => ipcRenderer.send('qb-drag-move'),
  dragEnd: () => ipcRenderer.send('qb-drag-end'),
  export: (json) => ipcRenderer.send('qb-export', json),
});
