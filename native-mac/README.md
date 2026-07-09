# 快捷信息板 · 原生 macOS 版（WKWebView，超轻量）

不是 Electron，而是直接用系统自带的 **WebKit** 做的原生 App。
体积只有 **~1MB**（对比 Electron 版的 225MB，轻约 500 倍），不内嵌 Chromium，占用极小。

## 原理
- `main.swift`：`AppKit + WKWebView` 原生外壳，加载 `Resources/` 里的 `index.html` / `three.min.js`。
- 通过 `WKScriptMessageHandler` 提供网页调用的桥接：
  `copy`（写系统剪贴板）、`min`/`max`（缩小成雪人宠物 / 恢复窗口）、
  `close`（退出）、`dragStart`/`dragMove`/`dragEnd`（拖拽窗口）、`export`（导出 JSON 到下载夹）。
- 窗口：无边框、透明、置顶（`level = .floating`）、不显示 Dock 图标（`LSUIElement`）。
- 拖拽用 **AppKit 原生 `setFrameOrigin`** 移动窗口，由系统合成，不再抖动
  （Electron 版是用 `setPosition` 逐鼠标事件重定位 + 取整，才会抖）。

## 构建（在你自己的 Mac 上，需装 Command Line Tools：`xcode-select --install`）
```bash
cd native-mac
bash build.sh
# 产出 QuickBoard.app
```

## 运行未签名 App（重要）
未签名会被 Gatekeeper 拦截，解压后执行一次：
```bash
xattr -cr "/你的路径/QuickBoard.app"
# 之后双击打开
```
或右键「打开」、或在 系统设置→隐私与安全性 里点「仍要打开」。

## 目录
```
native-mac/
├── main.swift     # 原生外壳（已修拖拽抖动）
├── index.html     # 前端 UI + 逻辑 + 3D 雪人（与原版一致）
├── three.min.js   # Three.js
├── icon.icns      # 图标
├── Info.plist     # LSUIElement 等
└── build.sh       # 一键编译打包
```

> 注：数据存于 WKWebView 本地存储（app:// 源）。如重启后数据丢失，告诉我，
> 我可再加一个原生存储桥接（UserDefaults）做兜底。
