# 桌面剪贴板 · Windows 版

一个常驻桌面的轻量「片段管理」小组件：搜索、分类、一键复制、新建/编辑/删除、深浅主题、导出 JSON，
还能点右上「—」把整个窗口缩成一只 **3D 雪人桌面宠物**（悬停俏皮一缩、单击恢复、按住拖动）。

**功能与 macOS 版完全一致**（同一套前端逻辑），区别仅在于外壳技术：

| | macOS 版 | Windows 版 |
|---|---|---|
| 外壳 | 原生 WKWebView（Swift） | Electron（Chromium） |
| 体积 | ~1 MB | ~150 MB（含运行时） |
| 拖动 | 原生 `NSEvent` | CSS `app-region`（系统合成） |
| 数据 | `~/Library/Application Support/QuickBoard` | 程序目录 `resources/app/QuickBoard`（便携，跟随程序走） |
| 导出 | 下载文件夹（带时间戳） | 下载文件夹（带时间戳） |

> 为什么 Windows 用 Electron 而不是原生 WebView2？
> 原生 Windows 应用需要在 Windows 上用 Visual Studio / Windows SDK 编译，
> 当前打包环境是 macOS，无法跨平台编译 Windows 原生二进制。
> 因此 Windows 版通过 Electron 实现，**功能、交互、外观与 Mac 版一模一样**，
> 唯一代价是体积更大（Chromium 运行时）。如果你有自己的 Windows 编译环境，
> 我也可以另提供 WebView2 原生源码版本。

## 系统要求
- Windows 10 / 11（64 位）
- 无需安装运行库（Electron 运行时已内置在包里）

## 运行（重要）
1. 解压 `桌面剪贴板-win.zip`，得到 `QuickBoard-win32-x64` 文件夹。
2. 双击里面的 **`QuickBoard.exe`** 即可。

### 关于 Windows SmartScreen（未签名提示）
本应用未做代码签名，首次运行时 Windows 可能弹出「Windows 已保护你的电脑」SmartScreen 拦截：
- 点击 **「更多信息」→「仍要运行」** 即可打开；
- 或者右键 `桌面剪贴板.exe` → 属性 → 底部「解除锁定」→ 确定，之后再双击就不会再拦。
（企业环境若被组策略禁止，请用管理员确认或自行签名。）

## 使用方法
- **搜索**：顶部输入框实时按「名称 / 内容」过滤；`Ctrl + Shift + V` 聚焦搜索框。
- **分类**：全部 / 账号密码 / 文本 / 链接 / 代码，可与搜索组合筛选。
- **复制**：点条目右侧的复制按钮，自动写入系统剪贴板并提示。
- **新建 / 编辑 / 删除**：右下「+ 新建」；条目悬停出现编辑/删除；删除有页内二次确认。
- **主题**：右下太阳/月亮图标切换深/浅色，自动记忆。
- **导出**：右下导出按钮，把全部片段导出为 `snippets-时间戳.json` 到「下载」文件夹（不覆盖旧文件）。
- **缩小成宠物**：点右上「—」，窗口缩成 170×170 的 3D 雪人；
  - 悬停：雪人俏皮一缩；
  - **单击**：恢复成完整窗口；
  - **按住拖动**：把雪人拖到屏幕任意位置（系统级平滑，不抖动）。
- **关闭**：右上「×」退出程序（数据已全部存本地，重启不丢）。
- **移动窗口**：在标题栏空白处按住拖动（完整窗口态）。

## 数据说明（便携存储，跟随程序走）
- 所有数据**仅存本地**，不上传任何服务器；默认写在程序自身目录：
  `QuickBoard-win32-x64\resources\app\QuickBoard\snippets.json`
  （若程序目录不可写，则自动回退到 `C:\Users\<你>\AppData\Roaming\桌面剪贴板\QuickBoard\`）
- 因为数据就在程序旁边，可直接打开 `snippets.json` 查看/备份；把整个程序文件夹拷到别的电脑，数据也会一起带走。
- 首次启动会自动写入 5 条示例数据；清空后也会保留空列表。
- 敏感信息（如账号密码）只保存在本机文件中，请注意本机安全。

## 目录（源码，供自行构建 / 修改）
```
win-version/
├── main.js        # Electron 主进程：透明无边框置顶窗口、min/max/close、剪贴板、文件存储、导出
├── preload.js     # 桥接：向网页暴露 window.electronAPI（copy/min/max/close/load/save/export）
├── index.html     # 前端 UI + 逻辑 + 3D 雪人（与 macOS 版同一套）
├── three.min.js   # Three.js
├── icon.ico       # 图标
├── package.json   # 依赖与打包脚本
└── README.md      # 本说明
```

## 自行构建（需要 Node.js 18+ 与网络）
```bash
cd win-version
npm install                # 安装 electron / electron-packager
npm run pack:win           # 产出 dist/QuickBoard-win32-x64/QuickBoard.exe
```

## 已知限制
- 未签名：会触发 SmartScreen（见上）。如需无感分发，需自行购买代码签名证书签名。
- 体积较大：Electron 运行时约 150MB（Chromium 内核），非原生轻量实现。
- 仅 64 位：当前只打包了 `win32-x64`，老 32 位机需另行构建 `ia32`。
