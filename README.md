# 桌面剪贴板 / QuickBoard

一个常驻桌面的轻量「片段管理」小组件：把常用的账号密码、文本、链接、代码片段集中管理，支持实时搜索、分类筛选、一键复制、增删改、深浅主题，还能把整个窗口缩成一只 3D 雪人桌面宠物。

数据**全部存本地、不上传任何服务器**；关闭再打开内容仍在。

## ✨ 为什么用桌面剪贴板

- 🔒 **隐私安全**：所有数据只保存在你自己的电脑上，**不上传任何服务器**，账号密码、证件号等敏感信息完全不用担心泄露。
- ⚡ **点击即用**：Windows 版解压即跑、免安装；常驻桌面角落，随时一键复制，**快速填写各类注册 / 表单资料**，再也不用手忙脚乱翻备忘录。
- 🧩 **轻量无负担**：macOS 原生版仅约 1MB，几乎不占资源；窗口还能缩成一只 3D 雪人宠物，可爱又不挡事。
- 💾 **关了还在**：本地持久化，关闭程序、重启电脑数据都留着。

> 同名跨平台实现：
> - **macOS 版**：原生 WKWebView（Swift）外壳，体积约 1MB，丝滑无抖动。
> - **Windows 版**：Electron（Chromium）外壳，功能 / 交互 / 外观与 Mac 版完全一致，代价是体积较大（约 100MB 运行时）。

## 功能一览

- 🔍 实时搜索（按名称 / 内容过滤），`Ctrl + Shift + V` 聚焦搜索框
- 🗂 分类：全部 / 账号密码 / 文本 / 链接 / 代码
- 📋 一键复制，自动写入系统剪贴板
- ➕ 新建 / ✏️ 编辑 / 🗑 删除（删除有二次确认）
- 🌗 深 / 浅主题，自动记忆
- 📤 导出为 `snippets-时间戳.json`
- ⛄ 缩小成 3D 雪人桌面宠物：悬停俏皮一缩、单击恢复、按住拖动（系统级平滑，不抖动）
- 💾 本地持久化：关闭后数据保留

## 目录结构

```
.
├── win-version/              # Windows 版源码（Electron）
│   ├── main.js               # 主进程：无边框置顶窗口、剪贴板、文件存储、导出
│   ├── preload.js            # 桥接：向网页暴露 window.electronAPI
│   ├── index.html            # 前端 UI + 逻辑 + 3D 雪人（与 Mac 版同一套）
│   ├── three.min.js          # Three.js
│   ├── icon.ico
│   ├── package.json
│   └── README.md
├── native-mac/               # macOS 版源码（Swift + WKWebView）
│   ├── main.swift            # 原生外壳：窗口、桥接、文件存储、拖拽、雪人交互
│   ├── index.html            # 与 Windows 版共用的前端
│   ├── three.min.js
│   ├── Info.plist
│   ├── icon.icns
│   ├── build.sh
│   └── README.md
├── 桌面剪贴板-win.zip        # Windows 发布包（见 Releases，约 100MB）
├── LICENSE
└── README.md
```

## 下载与运行

### Windows（推荐直接下载发布包）
到本仓库 **Releases** 页下载 `QuickBoard-win-v1.0.0.zip`（Windows 发布包），解压后双击 `QuickBoard.exe` 即可。
- 未签名会触发 Windows SmartScreen：点「更多信息 → 仍要运行」即可。
- 数据存放在 `C:\Users\<你>\AppData\Roaming\desktop-clipboard\QuickBoard\snippets.json`，可随时查看 / 备份。

### Windows（自行构建，需 Node.js 18+ 与网络）
```bash
cd win-version
npm install
npm run pack:win     # 产出 dist/QuickBoard-win32-x64/QuickBoard.exe
```

### macOS（推荐直接下载发布包）
到本仓库 **Releases** 页下载 `QuickBoard-mac-v1.0.0.zip`（已签名的原生 `.app`，约 1MB），解压后双击 `桌面剪贴板.app` 即可，**和本地一样双击就能用**。
- 当前为 **Apple Silicon（arm64）** 版本，适用于 M1/M2/M3 等 Mac；Intel Mac 需自行用源码构建（见下）。
- 因未购买 Apple 开发者签名证书，首次打开可能被 Gatekeeper 拦截：右键 `桌面剪贴板.app` → **打开** 即可（只需一次），或终端执行 `xattr -dr com.apple.quarantine 桌面剪贴板.app`。

或从源码自行构建（需 Xcode / 命令行工具）：
```bash
cd native-mac
./build.sh           # 编译生成 桌面剪贴板.app
```
或从源码用 Xcode 打开 `main.swift` + `index.html` 运行。

## 技术说明

| | macOS 版 | Windows 版 |
|---|---|---|
| 外壳 | 原生 WKWebView（Swift / AppKit） | Electron（Chromium） |
| 体积 | ~1 MB | ~100 MB（含运行时） |
| 拖动 | 原生 NSEvent（无抖动） | CSS app-region（系统合成） |
| 数据 | `~/Library/Application Support/QuickBoard` | `%APPDATA%/desktop-clipboard/QuickBoard` |
| 桥接 | `window.webkit.messageHandlers` | `window.electronAPI`（preload） |

> 为何 Windows 用 Electron 而非原生 WebView2？原生 Windows 应用需在 Windows 上用 Visual Studio 编译，
> 当前打包环境为 macOS，无法跨平台编译 Windows 原生二进制。功能 / 交互 / 外观完全一致，唯一代价是体积。

## 💬 反馈与建议

欢迎大家在 [Issues](../../issues) 里提 Bug、吐槽或新功能想法！无论是 macOS 还是 Windows 上的使用体验，任何**意见和建议**都欢迎，一起把这个小工具做得更好用。

## 许可
[MIT](LICENSE)
